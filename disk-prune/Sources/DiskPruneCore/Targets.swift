import Foundation

public struct Measurement {
    public let bytes: Int64?
    public let detail: String?

    public init(bytes: Int64?, detail: String? = nil) {
        self.bytes = bytes
        self.detail = detail
    }
}

public struct PruneOutcome {
    public let freedBytes: Int64?
    public let note: String?

    public init(freedBytes: Int64?, note: String? = nil) {
        self.freedBytes = freedBytes
        self.note = note
    }
}

public protocol PruneTarget {
    var id: String { get }
    var label: String { get }
    /// Targets that never delete, whatever the config says.
    var reportOnly: Bool { get }
    func measure() -> Measurement
    func prune() -> PruneOutcome
}

extension PruneTarget {
    public var reportOnly: Bool { false }
}

/// Generic target: one or more cache directories whose contents are safe to
/// delete outright because the owning app regenerates them (Brave, Codex).
struct CacheDirsTarget: PruneTarget {
    let id: String
    let label: String
    let paths: [String]

    func measure() -> Measurement {
        let sizes = Disk.sizesInBytes(paths)
        guard !sizes.isEmpty else { return Measurement(bytes: nil, detail: "not present") }
        return Measurement(bytes: sizes.values.reduce(0, +))
    }

    func prune() -> PruneOutcome {
        let before = measure().bytes ?? 0
        var failures = 0
        for path in paths {
            do {
                let result = try Disk.clearContents(of: path)
                failures += result.failed
            } catch {
                return PruneOutcome(freedBytes: nil, note: String(describing: error))
            }
        }
        let after = measure().bytes ?? 0
        let note = failures > 0 ? "\(failures) in-use item(s) left behind" : nil
        return PruneOutcome(freedBytes: max(0, before - after), note: note)
    }
}

/// Report-only variant for directories worth watching that sit *outside* the
/// deletion allowlist (e.g. under Application Support). Surfaces regrowth in
/// reports and the menu bar without the tool ever deleting there - and even
/// if it tried, Disk.clearContents would refuse the path.
struct ReportDirsTarget: PruneTarget {
    let id: String
    let label: String
    let paths: [String]
    let reportOnly = true

    func measure() -> Measurement {
        let sizes = Disk.sizesInBytes(paths)
        guard !sizes.isEmpty else { return Measurement(bytes: nil, detail: "not present") }
        return Measurement(bytes: sizes.values.reduce(0, +))
    }

    func prune() -> PruneOutcome {
        PruneOutcome(freedBytes: nil, note: "report-only")
    }
}

struct BrewTarget: PruneTarget {
    let id = "brew"
    let label = "Homebrew cache"
    private let cachePath = NSHomeDirectory() + "/Library/Caches/Homebrew"

    func measure() -> Measurement {
        guard let bytes = Disk.sizeInBytes(cachePath) else {
            return Measurement(bytes: nil, detail: "not present")
        }
        return Measurement(bytes: bytes)
    }

    func prune() -> PruneOutcome {
        guard let brew = Shell.which("brew") else {
            return PruneOutcome(freedBytes: nil, note: "brew not found")
        }
        let before = measure().bytes ?? 0
        let result = Shell.run(brew, ["cleanup", "--prune=all", "-s"])
        let after = measure().bytes ?? 0
        let note = result.succeeded ? nil : "brew cleanup exited \(result.status)"
        return PruneOutcome(freedBytes: max(0, before - after), note: note)
    }
}

struct NpmTarget: PruneTarget {
    let id = "npm"
    let label = "npm cache"
    private let npmDir = NSHomeDirectory() + "/.npm"

    func measure() -> Measurement {
        guard let bytes = Disk.sizeInBytes(npmDir) else {
            return Measurement(bytes: nil, detail: "not present")
        }
        return Measurement(bytes: bytes)
    }

    func prune() -> PruneOutcome {
        let before = measure().bytes ?? 0
        if let npm = Shell.which("npm") {
            let result = Shell.run(npm, ["cache", "clean", "--force"])
            let after = measure().bytes ?? 0
            let note = result.succeeded ? nil : "npm cache clean exited \(result.status)"
            return PruneOutcome(freedBytes: max(0, before - after), note: note)
        }
        // No npm on PATH (nvm not loaded under launchd, say) - the cache
        // content itself lives in _cacache and is safe to clear directly.
        do {
            try Disk.clearContents(of: npmDir + "/_cacache")
            let after = measure().bytes ?? 0
            return PruneOutcome(freedBytes: max(0, before - after), note: "npm not found; cleared _cacache directly")
        } catch {
            return PruneOutcome(freedBytes: nil, note: String(describing: error))
        }
    }
}

struct DockerTarget: PruneTarget {
    let id = "docker"
    let label = "Docker (images, containers)"

    func measure() -> Measurement {
        guard let docker = Shell.which("docker") else {
            return Measurement(bytes: nil, detail: "docker not found")
        }
        let result = Shell.run(docker, ["system", "df", "--format", "{{.Type}}\t{{.Reclaimable}}"])
        guard result.succeeded else {
            return Measurement(bytes: nil, detail: "docker daemon not reachable")
        }
        var total: Int64 = 0
        for line in result.stdout.split(separator: "\n") {
            let fields = line.split(separator: "\t")
            guard fields.count == 2,
                  let bytes = DockerTarget.parseSize(String(fields[1]))
            else { continue }
            total += bytes
        }
        return Measurement(bytes: total)
    }

    func prune() -> PruneOutcome {
        guard let docker = Shell.which("docker") else {
            return PruneOutcome(freedBytes: nil, note: "docker not found")
        }
        let result = Shell.run(docker, ["system", "prune", "-af"])
        guard result.succeeded else {
            return PruneOutcome(freedBytes: nil, note: "docker system prune exited \(result.status)")
        }
        // Last line reads "Total reclaimed space: 2.5GB"
        let freed = result.stdout
            .split(separator: "\n")
            .last { $0.contains("Total reclaimed space:") }
            .flatMap { line -> Int64? in
                let value = line.replacingOccurrences(of: "Total reclaimed space:", with: "")
                return DockerTarget.parseSize(value)
            }
        return PruneOutcome(freedBytes: freed)
    }

    /// Parse docker's human sizes: "3.1GB (80%)", "350.5MB", "0B".
    static func parseSize(_ raw: String) -> Int64? {
        let token = raw.trimmingCharacters(in: .whitespaces)
            .split(separator: " ").first.map(String.init) ?? ""
        let multipliers: [(String, Double)] = [
            ("TiB", 1_099_511_627_776), ("GiB", 1_073_741_824), ("MiB", 1_048_576), ("KiB", 1024),
            ("TB", 1e12), ("GB", 1e9), ("MB", 1e6), ("kB", 1e3), ("KB", 1e3), ("B", 1),
        ]
        for (suffix, multiplier) in multipliers where token.hasSuffix(suffix) {
            let number = String(token.dropLast(suffix.count))
            guard let value = Double(number) else { return nil }
            return Int64(value * multiplier)
        }
        return nil
    }
}

/// Report-only by design: the Trash is user data. Finder's own "Remove items
/// after 30 days" setting does the emptying (see the osx script); this target
/// just keeps the size visible in reports.
struct TrashTarget: PruneTarget {
    let id = "trash"
    let label = "Trash"
    let reportOnly = true
    private let trashPath = NSHomeDirectory() + "/.Trash"

    func measure() -> Measurement {
        guard let bytes = Disk.sizeInBytes(trashPath) else {
            return Measurement(bytes: nil, detail: "unreadable (Full Disk Access needed?)")
        }
        return Measurement(bytes: bytes, detail: "Finder auto-empties after 30 days")
    }

    func prune() -> PruneOutcome {
        PruneOutcome(freedBytes: nil, note: "report-only")
    }
}

/// Report-only: node_modules belongs to whatever project it sits in, and
/// deleting it forces a reinstall the next time that project is touched.
struct NodeModulesTarget: PruneTarget {
    let id = "node_modules"
    let label = "node_modules in ~/projects"
    let reportOnly = true
    private let projectsDir = NSHomeDirectory() + "/projects"

    func measure() -> Measurement {
        guard FileManager.default.fileExists(atPath: projectsDir) else {
            return Measurement(bytes: nil, detail: "not present")
        }
        let found = Shell.run("/usr/bin/find", [
            projectsDir, "-type", "d", "-name", "node_modules", "-prune", "-print",
        ])
        let dirs = found.stdout.split(separator: "\n").map(String.init)
        guard !dirs.isEmpty else { return Measurement(bytes: 0, detail: "none found") }
        let total = Disk.sizesInBytes(dirs).values.reduce(0, +)
        return Measurement(bytes: total, detail: "\(dirs.count) director\(dirs.count == 1 ? "y" : "ies")")
    }

    func prune() -> PruneOutcome {
        PruneOutcome(freedBytes: nil, note: "report-only")
    }
}

public enum Targets {
    /// Display order for reports.
    public static let all: [PruneTarget] = [
        BrewTarget(),
        NpmTarget(),
        CacheDirsTarget(
            id: "brave",
            label: "Brave browser cache",
            paths: [
                NSHomeDirectory() + "/Library/Caches/com.brave.Browser",
                NSHomeDirectory() + "/Library/Caches/BraveSoftware",
            ]
        ),
        CacheDirsTarget(
            id: "codex",
            label: "OpenAI Codex caches",
            paths: [
                NSHomeDirectory() + "/Library/Caches/com.openai.codex",
                NSHomeDirectory() + "/.cache/codex-runtimes",
            ]
        ),
        DockerTarget(),
        // Chrome's on-device AI models held 4 GB on the 2026-07-31 audit
        // (cleared by hand that day; Chrome may re-download them). Report-only:
        // the paths live under Application Support, outside the prune roots.
        ReportDirsTarget(
            id: "chrome_ai",
            label: "Chrome on-device AI models",
            paths: [
                NSHomeDirectory() + "/Library/Application Support/Google/Chrome/OptGuideOnDeviceModel",
                NSHomeDirectory() + "/Library/Application Support/Google/Chrome/optimization_guide_model_store",
            ]
        ),
        TrashTarget(),
        NodeModulesTarget(),
    ]
}
