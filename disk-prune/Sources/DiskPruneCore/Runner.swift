import Foundation

public struct DryRunSummary {
    public let mole: Mole.DryRun?
    public let dockerMode: Config.DockerMode
    public let dockerBytes: Int64?
    public let dockerDetail: String?
    public let watches: [WatchReport]

    /// What a run right now would actually free.
    public var prunableBytes: Int64 {
        var total = mole?.potentialBytes ?? 0
        if dockerMode == .prune {
            total += dockerBytes ?? 0
        }
        return total
    }
}

public struct RunSummary {
    public let mole: Mole.Clean?
    public let dockerFreed: Int64?
    public let dockerNote: String?
    public let totalFreed: Int64
    public let started: Date
    public let finished: Date

    public var succeeded: Bool { mole?.succeeded ?? false }
}

public enum Runner {
    /// Measure everything a run would touch, plus the watch list. Deletes
    /// nothing (mole runs with --dry-run).
    public static func dryRun(config: Config) -> DryRunSummary {
        let docker = Docker.measure()
        return DryRunSummary(
            mole: Mole.dryRun(),
            dockerMode: config.docker,
            dockerBytes: docker.bytes,
            dockerDetail: docker.detail,
            watches: Watch.reports()
        )
    }

    /// Run mole (and docker, if enabled), log the outcome, notify if
    /// configured.
    public static func run(config: Config) -> RunSummary {
        let started = Date()
        Log.append("run | start (mole\(config.docker == .prune ? " + docker" : ""))")

        let clean = Mole.clean()
        if let clean {
            if clean.succeeded {
                let freed = clean.freedBytes.map(Disk.format) ?? "unknown"
                let items = clean.items.map { " (\($0) items)" } ?? ""
                Log.append("run | mole: freed \(freed)\(items); details in ~/Library/Logs/mole/")
            } else {
                Log.append("run | mole: mo clean failed; see ~/Library/Logs/mole/")
            }
        } else {
            Log.append("run | mole: mo not found - nothing cleaned (brew install mole)")
        }

        var dockerFreed: Int64?
        var dockerNote: String?
        if config.docker == .prune {
            let result = Docker.prune()
            dockerFreed = result.freed
            dockerNote = result.note
            Log.append("run | docker: \(result.freed.map { "freed \(Disk.format($0))" } ?? result.note ?? "no result")")
        }

        let totalFreed = (clean?.freedBytes ?? 0) + (dockerFreed ?? 0)
        Log.append("run | done: total freed \(Disk.format(totalFreed))")

        if config.notify {
            let message = clean == nil
                ? "mole not found - nothing cleaned"
                : "Freed \(Disk.format(totalFreed))"
            Notifier.notify(title: "disk-prune", message: message)
        }

        return RunSummary(
            mole: clean,
            dockerFreed: dockerFreed,
            dockerNote: dockerNote,
            totalFreed: totalFreed,
            started: started,
            finished: Date()
        )
    }
}
