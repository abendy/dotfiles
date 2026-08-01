import Foundation

public enum Shell {
    public struct Result {
        public let status: Int32
        public let stdout: String
        public let stderr: String
        public var succeeded: Bool { status == 0 }
    }

    /// Run a binary directly (no shell) with a PATH padded out to the usual
    /// Homebrew locations, since launchd agents start with a minimal one.
    /// No shell also means no aliases - the interactive `du` alias
    /// (dotfiles issue #38) can never leak in here.
    @discardableResult
    public static func run(_ executable: String, _ arguments: [String]) -> Result {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        var environment = ProcessInfo.processInfo.environment
        let extraPaths = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            NSHomeDirectory() + "/bin",
            NSHomeDirectory() + "/.local/bin",
        ]
        let path = environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        environment["PATH"] = (extraPaths + [path]).joined(separator: ":")
        process.environment = environment

        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err

        do {
            try process.run()
        } catch {
            return Result(status: 127, stdout: "", stderr: String(describing: error))
        }

        // Drain the pipes before waiting, or a chatty child fills the pipe
        // buffer and both processes deadlock.
        let outData = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        return Result(
            status: process.terminationStatus,
            stdout: String(data: outData, encoding: .utf8) ?? "",
            stderr: String(data: errData, encoding: .utf8) ?? ""
        )
    }

    /// Locate a binary by checking well-known directories before PATH, so
    /// resolution works identically from a login shell and from launchd.
    public static func which(_ name: String) -> String? {
        var candidates = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            NSHomeDirectory() + "/bin",
            NSHomeDirectory() + "/.local/bin",
        ]
        if let path = ProcessInfo.processInfo.environment["PATH"] {
            candidates += path.split(separator: ":").map(String.init)
        }
        for dir in candidates {
            let full = dir + "/" + name
            if FileManager.default.isExecutableFile(atPath: full) {
                return full
            }
        }
        return nil
    }
}

public enum Disk {
    public enum SafetyError: Error, CustomStringConvertible {
        case outsideAllowlist(String)
        public var description: String {
            switch self {
            case .outsideAllowlist(let path):
                return "refusing to delete inside \(path): not under an allowlisted cache root"
            }
        }
    }

    /// The only roots this tool is ever allowed to delete inside. Everything
    /// else - Documents, Messages, Photos, project sources - is refused at
    /// this layer no matter what a target or the config asks for. The roots
    /// themselves are never deleted, only entries inside them.
    public static let allowedRoots = [
        NSHomeDirectory() + "/Library/Caches/",
        NSHomeDirectory() + "/.cache/",
        NSHomeDirectory() + "/.npm/",
    ]

    /// Size of a path in bytes via /usr/bin/du (absolute path: issue #38).
    /// Returns nil when the path is missing or unreadable. du can exit
    /// non-zero on permission errors while still printing a usable total,
    /// so the exit status is deliberately ignored when output parses.
    public static func sizeInBytes(_ path: String) -> Int64? {
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        let result = Shell.run("/usr/bin/du", ["-sk", path])
        guard let line = result.stdout.split(separator: "\n").first,
              let field = line.split(separator: "\t").first,
              let kilobytes = Int64(field.trimmingCharacters(in: .whitespaces))
        else { return nil }
        return kilobytes * 1024
    }

    /// Sizes for several paths in one du invocation. Missing paths are
    /// skipped. Returns path -> bytes.
    public static func sizesInBytes(_ paths: [String]) -> [String: Int64] {
        let existing = paths.filter { FileManager.default.fileExists(atPath: $0) }
        guard !existing.isEmpty else { return [:] }
        let result = Shell.run("/usr/bin/du", ["-sk"] + existing)
        var sizes: [String: Int64] = [:]
        for line in result.stdout.split(separator: "\n") {
            let fields = line.split(separator: "\t", maxSplits: 1)
            guard fields.count == 2,
                  let kilobytes = Int64(fields[0].trimmingCharacters(in: .whitespaces))
            else { continue }
            sizes[String(fields[1])] = kilobytes * 1024
        }
        return sizes
    }

    public static func format(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    /// Delete the *contents* of a directory, never the directory itself, and
    /// only when the (symlink-resolved) directory sits under an allowlisted
    /// cache root. Files held open by a running app fail to delete; that is
    /// counted, not fatal - caches are pruned best-effort.
    @discardableResult
    public static func clearContents(of path: String) throws -> (removed: Int, failed: Int) {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return (0, 0)
        }

        let resolved = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
        guard allowedRoots.contains(where: { resolved.hasPrefix($0) }) else {
            throw SafetyError.outsideAllowlist(resolved)
        }

        var removed = 0
        var failed = 0
        for entry in (try? fm.contentsOfDirectory(atPath: resolved)) ?? [] {
            do {
                try fm.removeItem(atPath: resolved + "/" + entry)
                removed += 1
            } catch {
                failed += 1
            }
        }
        return (removed, failed)
    }
}

public enum Log {
    public static let path = NSHomeDirectory() + "/Library/Logs/disk-prune.log"

    private static let stamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    public static func append(_ message: String) {
        let line = "\(stamp.string(from: Date())) | \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        let fm = FileManager.default
        if !fm.fileExists(atPath: path) {
            fm.createFile(atPath: path, contents: nil)
        }
        guard let handle = FileHandle(forWritingAtPath: path) else { return }
        defer { try? handle.close() }
        handle.seekToEndOfFile()
        handle.write(data)
    }
}

public enum Notifier {
    public static func notify(title: String, message: String) {
        func escape(_ s: String) -> String {
            s.replacingOccurrences(of: "\\", with: "\\\\")
             .replacingOccurrences(of: "\"", with: "\\\"")
        }
        Shell.run("/usr/bin/osascript", [
            "-e",
            "display notification \"\(escape(message))\" with title \"\(escape(title))\"",
        ])
    }
}
