import DiskPruneCore
import Foundation

let version = "0.2.0"

func die(_ message: String) -> Never {
    FileHandle.standardError.write(Data(("disk-prune: " + message + "\n").utf8))
    exit(2)
}

func printUsage() {
    print("""
    disk-prune \(version) - scheduled cleaning for this Mac, engine by mole

    disk-prune schedules mole (https://mole.fit) and layers on a run log,
    a notification, the docker gate, and watch-only path reports. Cleaning
    policy lives in mole's whitelist (~/.config/mole/whitelist).

    usage: disk-prune [command] [options]

    commands:
      dry-run     mole's cleanup preview plus the watch list; deletes
                  nothing (default)
      run         mo clean (and docker, if enabled), log to
                  ~/Library/Logs/disk-prune.log, notify
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

func printExtras(dockerMode: Config.DockerMode, dockerBytes: Int64?, dockerDetail: String?, watches: [WatchReport]) {
    let dockerSize = dockerBytes.map(Disk.format) ?? dockerDetail ?? "-"
    switch dockerMode {
    case .off:
        print("  docker: off until issue #37 - \(dockerSize) reclaimable")
    case .prune:
        print("  docker: prune - \(dockerSize) reclaimable")
    }
    for watch in watches {
        let size = watch.bytes.map(Disk.format) ?? "-"
        let detail = watch.detail.map { "  (\($0))" } ?? ""
        print("  \(watch.label): \(size)\(detail)")
    }
}

switch command {
case "help":
    printUsage()

case "version":
    print("disk-prune \(version)")

case "dry-run":
    let summary = Runner.dryRun(config: config)

    if let mole = summary.mole {
        print(mole.output)
    } else {
        print("disk-prune: mo not found - install the engine with `brew install mole` (it's in the Brewfile)\n")
    }

    print("disk-prune watch list (never pruned):")
    printExtras(dockerMode: summary.dockerMode, dockerBytes: summary.dockerBytes,
                dockerDetail: summary.dockerDetail, watches: summary.watches)
    print("\nA run now would free about \(Disk.format(summary.prunableBytes)).")

case "run":
    let summary = Runner.run(config: config)

    if let mole = summary.mole {
        print(mole.output)
        if !mole.succeeded {
            print("disk-prune: mo clean failed - see ~/Library/Logs/mole/")
        }
    } else {
        print("disk-prune: mo not found - nothing cleaned. Install with `brew install mole`.")
    }

    if config.docker == .prune {
        let docker = summary.dockerFreed.map(Disk.format) ?? summary.dockerNote ?? "no result"
        print("docker: \(docker)")
    }

    let seconds = Int(summary.finished.timeIntervalSince(summary.started).rounded())
    print("\nFreed \(Disk.format(summary.totalFreed)) in \(seconds)s. Log: \(Log.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))")
    if summary.mole == nil {
        exit(1)
    }

default:
    die("unreachable")
}
