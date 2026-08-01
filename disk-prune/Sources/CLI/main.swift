import DiskPruneCore
import Foundation

let version = "0.1.0"

func die(_ message: String) -> Never {
    FileHandle.standardError.write(Data(("disk-prune: " + message + "\n").utf8))
    exit(2)
}

func printUsage() {
    print("""
    disk-prune \(version) - scheduled cache pruning for this Mac

    usage: disk-prune [command] [options]

    commands:
      dry-run     measure each enabled target and report what a run would
                  free, deleting nothing (default)
      run         prune enabled targets, log to \(Log.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")),
                  and post a notification
      version     print the version
      help        this text

    options:
      --config PATH   config file (default ~/.config/disk-prune/config.json)
      --notify        force the run-complete notification on
      --no-notify     force it off
    """)
}

var command = "dry-run"
var configPath = Config.defaultPath
var notifyOverride: Bool?

var arguments = Array(CommandLine.arguments.dropFirst())
var index = 0
while index < arguments.count {
    let argument = arguments[index]
    switch argument {
    case "dry-run", "run":
        command = argument
    case "version", "--version":
        command = "version"
    case "help", "--help", "-h":
        command = "help"
    case "--config":
        index += 1
        guard index < arguments.count else { die("--config needs a path") }
        configPath = arguments[index]
    case "--notify":
        notifyOverride = true
    case "--no-notify":
        notifyOverride = false
    default:
        die("unknown argument '\(argument)' (try disk-prune help)")
    }
    index += 1
}

var config = Config.load(from: configPath)
if let notifyOverride {
    config.notify = notifyOverride
}

func tabulate(rows: [(String, String, String, String)]) {
    let widths = (0 ..< 3).map { column in
        rows.map { row in
            [row.0, row.1, row.2, row.3][column].count
        }.max() ?? 0
    }
    for row in rows {
        let cells = [row.0, row.1, row.2, row.3]
        let padded = (0 ..< 3).map { cells[$0].padding(toLength: widths[$0] + 2, withPad: " ", startingAt: 0) }
        print("  " + padded.joined() + cells[3])
    }
}

switch command {
case "help":
    printUsage()

case "version":
    print("disk-prune \(version)")

case "dry-run":
    print("disk-prune \(version) - dry run, nothing will be deleted\n")
    let reports = Runner.dryRun(config: config)

    var rows: [(String, String, String, String)] = [("TARGET", "MODE", "RECLAIMABLE", "NOTES")]
    var pruneTotal: Int64 = 0
    var reportTotal: Int64 = 0
    for report in reports {
        let size = report.bytes.map(Disk.format) ?? "-"
        rows.append((report.id, report.effectiveMode.rawValue, size, report.detail ?? ""))
        if let bytes = report.bytes {
            if report.effectiveMode == .prune {
                pruneTotal += bytes
            } else if report.effectiveMode == .report {
                reportTotal += bytes
            }
        }
    }
    tabulate(rows: rows)

    print("\nA run now would free about \(Disk.format(pruneTotal)).")
    if reportTotal > 0 {
        print("Report-only targets hold another \(Disk.format(reportTotal)) (not touched by runs).")
    }

case "run":
    print("disk-prune \(version) - pruning\n")
    let summary = Runner.run(config: config)

    var rows: [(String, String, String, String)] = [("TARGET", "MODE", "FREED", "NOTES")]
    for result in summary.results {
        let freed: String
        if let bytes = result.freedBytes {
            freed = Disk.format(bytes)
        } else if let reclaimable = result.reclaimableBytes {
            freed = "(\(Disk.format(reclaimable)) held)"
        } else {
            freed = "-"
        }
        rows.append((result.id, result.mode.rawValue, freed, result.note ?? ""))
    }
    tabulate(rows: rows)

    let seconds = Int(summary.finished.timeIntervalSince(summary.started).rounded())
    print("\nFreed \(Disk.format(summary.totalFreed)) in \(seconds)s. Log: \(Log.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))")

default:
    die("unreachable")
}
