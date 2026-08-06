import Foundation

public struct WatchReport {
    public let id: String
    public let label: String
    public let bytes: Int64?
    public let detail: String?
}

/// Paths disk-prune keeps an eye on but never touches - user data, project-
/// owned, or outside what we're willing to automate. mole doesn't track
/// these specifically, so the reporting lives here.
public enum Watch {
    public static func reports() -> [WatchReport] {
        var reports: [WatchReport] = []

        // Chrome's on-device AI models held 4 GB on the 2026-07-31 audit
        // (cleared by hand that day); surface a re-download without ever
        // deleting under Application Support.
        let chromeDirs = [
            NSHomeDirectory() + "/Library/Application Support/Google/Chrome/OptGuideOnDeviceModel",
            NSHomeDirectory() + "/Library/Application Support/Google/Chrome/optimization_guide_model_store",
        ]
        let chromeSizes = Disk.sizesInBytes(chromeDirs)
        reports.append(WatchReport(
            id: "chrome_ai",
            label: "Chrome on-device AI models",
            bytes: chromeSizes.isEmpty ? nil : chromeSizes.values.reduce(0, +),
            detail: chromeSizes.isEmpty ? "not present" : "clear by hand if unwanted"
        ))

        // The Trash is user data: whitelisted away from mole, emptied by
        // Finder's own 30-day setting (enabled in the osx script).
        reports.append(WatchReport(
            id: "trash",
            label: "Trash",
            bytes: Disk.sizeInBytes(NSHomeDirectory() + "/.Trash"),
            detail: "Finder auto-empties after 30 days"
        ))

        // node_modules belongs to whatever project it sits in; genuinely
        // abandoned artifacts are `mo purge` territory.
        let projectsDir = NSHomeDirectory() + "/projects"
        if FileManager.default.fileExists(atPath: projectsDir) {
            let found = Shell.run("/usr/bin/find", [
                projectsDir, "-type", "d", "-name", "node_modules", "-prune", "-print",
            ])
            let dirs = found.stdout.split(separator: "\n").map(String.init)
            let total = Disk.sizesInBytes(dirs).values.reduce(0, +)
            reports.append(WatchReport(
                id: "node_modules",
                label: "node_modules in ~/projects",
                bytes: dirs.isEmpty ? 0 : total,
                detail: "\(dirs.count) director\(dirs.count == 1 ? "y" : "ies"), see `mo purge`"
            ))
        }

        return reports
    }
}

/// Docker storage - the one thing this tool may still prune itself, because
/// mole only reports it. Gated to "off" until dotfiles issue #37 picks the
/// surviving runtime; talks to plain `docker`, so it follows whichever
/// daemon answers.
public enum Docker {
    public static func measure() -> (bytes: Int64?, detail: String?) {
        guard let docker = Shell.which("docker") else {
            return (nil, "docker not found")
        }
        let result = Shell.run(docker, ["system", "df", "--format", "{{.Type}}\t{{.Reclaimable}}"])
        guard result.succeeded else {
            return (nil, "docker daemon not reachable")
        }
        var total: Int64 = 0
        for line in result.stdout.split(separator: "\n") {
            let fields = line.split(separator: "\t")
            guard fields.count == 2,
                  let bytes = Disk.parseHumanSize(String(fields[1]))
            else { continue }
            total += bytes
        }
        return (total, nil)
    }

    public static func prune() -> (freed: Int64?, note: String?) {
        guard let docker = Shell.which("docker") else {
            return (nil, "docker not found")
        }
        let result = Shell.run(docker, ["system", "prune", "-af"])
        guard result.succeeded else {
            return (nil, "docker system prune exited \(result.status)")
        }
        // Last line reads "Total reclaimed space: 2.5GB"
        let freed = result.stdout
            .split(separator: "\n")
            .last { $0.contains("Total reclaimed space:") }
            .flatMap { line -> Int64? in
                let value = line.replacingOccurrences(of: "Total reclaimed space:", with: "")
                return Disk.parseHumanSize(value)
            }
        return (freed, nil)
    }
}
