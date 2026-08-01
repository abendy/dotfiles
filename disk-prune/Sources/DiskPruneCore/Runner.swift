import Foundation

public struct TargetReport {
    public let id: String
    public let label: String
    public let mode: TargetMode
    public let reportOnly: Bool
    public let bytes: Int64?
    public let detail: String?

    /// Effective behavior once report-only targets are accounted for.
    public var effectiveMode: TargetMode {
        reportOnly && mode == .prune ? .report : mode
    }
}

public struct RunResult {
    public let id: String
    public let label: String
    public let mode: TargetMode
    public let freedBytes: Int64?
    public let reclaimableBytes: Int64?
    public let note: String?
}

public struct RunSummary {
    public let results: [RunResult]
    public let totalFreed: Int64
    public let started: Date
    public let finished: Date
}

public enum Runner {
    /// Measure every non-off target. Deletes nothing.
    public static func dryRun(config: Config) -> [TargetReport] {
        Targets.all.compactMap { target in
            let mode = config.mode(for: target.id)
            guard mode != .off else {
                return TargetReport(id: target.id, label: target.label, mode: mode,
                                    reportOnly: target.reportOnly, bytes: nil, detail: "off")
            }
            let measurement = target.measure()
            return TargetReport(id: target.id, label: target.label, mode: mode,
                                reportOnly: target.reportOnly,
                                bytes: measurement.bytes, detail: measurement.detail)
        }
    }

    /// Prune enabled targets, log the outcome, notify if configured.
    public static func run(config: Config) -> RunSummary {
        let started = Date()
        Log.append("run | start")

        var results: [RunResult] = []
        for target in Targets.all {
            let mode = config.mode(for: target.id)
            switch mode {
            case .off:
                continue
            case .report:
                results.append(report(target, mode: mode))
            case .prune:
                if target.reportOnly {
                    results.append(report(target, mode: .report))
                } else {
                    let outcome = target.prune()
                    results.append(RunResult(id: target.id, label: target.label, mode: mode,
                                             freedBytes: outcome.freedBytes,
                                             reclaimableBytes: nil, note: outcome.note))
                }
            }
        }

        let totalFreed = results.compactMap(\.freedBytes).reduce(0, +)
        for result in results {
            var line = "run | \(result.id): "
            if let freed = result.freedBytes {
                line += "freed \(Disk.format(freed))"
            } else if let reclaimable = result.reclaimableBytes {
                line += "report-only, \(Disk.format(reclaimable)) reclaimable"
            } else {
                line += "no measurement"
            }
            if let note = result.note {
                line += " (\(note))"
            }
            Log.append(line)
        }
        Log.append("run | done: total freed \(Disk.format(totalFreed))")

        if config.notify {
            Notifier.notify(title: "disk-prune",
                            message: "Freed \(Disk.format(totalFreed))")
        }

        return RunSummary(results: results, totalFreed: totalFreed,
                          started: started, finished: Date())
    }

    private static func report(_ target: PruneTarget, mode: TargetMode) -> RunResult {
        let measurement = target.measure()
        return RunResult(id: target.id, label: target.label, mode: mode,
                         freedBytes: nil, reclaimableBytes: measurement.bytes,
                         note: measurement.detail ?? "report-only")
    }
}
