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

    /// Parse the human sizes mole and docker print: "6.94GB", "37.69MB",
    /// "496KB", "0B" (decimal units), plus the binary "GiB" family.
    public static func parseHumanSize(_ raw: String) -> Int64? {
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

public enum Text {
    /// Remove ANSI color/style sequences from CLI output before parsing it.
    public static func stripANSI(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{1B}\\[[0-9;]*m", with: "", options: .regularExpression)
    }

    /// First capture group of `pattern` in `text`, or nil.
    public static func capture(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[captureRange])
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
