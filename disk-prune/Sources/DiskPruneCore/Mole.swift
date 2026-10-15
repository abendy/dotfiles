import Foundation

/// Thin client around the mole CLI (https://mole.fit, brew formula `mole`,
/// in the Brewfile) - the cleaning engine. disk-prune owns no deletion logic
/// of its own: it schedules mole, layers on logging and notifications, and
/// reports on watch-only paths mole doesn't track. Policy lives in mole's
/// whitelist (~/.config/mole/whitelist, installed from
/// config/mole-whitelist.template), which is how the Trash stays protected.
public enum Mole {
    public struct DryRun {
        public let potentialBytes: Int64?
        public let items: Int?
        /// mole's own (colored) preview output, for terminal display.
        public let output: String
    }

    public struct Clean {
        public let freedBytes: Int64?
        public let items: Int?
        public let output: String
        public let succeeded: Bool
    }

    public static func binary() -> String? {
        Shell.which("mo")
    }

    /// `mo clean --dry-run` - measures without deleting. ~30s. nil when mole
    /// is not installed.
    public static func dryRun() -> DryRun? {
        guard let mo = binary() else { return nil }
        let result = Shell.run(mo, ["clean", "--dry-run"])
        // Summary line: "Potential space: 6.94GB | Items: 577 | Categories: 7"
        let plain = Text.stripANSI(result.stdout)
        return DryRun(
            potentialBytes: Text.capture(#"Potential space: ([0-9.]+[kKMGT]?i?B)"#, in: plain)
                .flatMap(Disk.parseHumanSize),
            items: Text.capture(#"Items: ([0-9]+)"#, in: plain).flatMap { Int($0) },
            output: result.stdout
        )
    }

    /// `mo clean` - the real thing. Runs without prompting (verified against
    /// the 1.48.x source: the clean path has no confirmation reads), so it is
    /// safe under launchd. nil when mole is not installed.
    public static func clean() -> Clean? {
        guard let mo = binary() else { return nil }
        let started = Date()
        let result = Shell.run(mo, ["clean"])
        // Freed totals come from `mo history --json` - a stable interface -
        // rather than scraping colored output. Only a session that started
        // with this invocation counts: a failed or aborted run must not
        // report an older run's total as its own.
        let session = cleanSession(mo, startedAfter: started.addingTimeInterval(-2))
        return Clean(
            freedBytes: session?.sizeBytes,
            items: session?.items,
            output: result.stdout,
            succeeded: result.succeeded
        )
    }

    struct Session {
        let items: Int?
        let sizeBytes: Int64?
    }

    static func cleanSession(_ mo: String, startedAfter threshold: Date) -> Session? {
        let result = Shell.run(mo, ["history", "--json"])
        guard result.succeeded, let data = result.stdout.data(using: .utf8) else { return nil }

        struct History: Decodable {
            struct Entry: Decodable {
                let command: String
                let started_at: String?
                let items: Int?
                let size: String?
            }
            let sessions: [Entry]
        }

        // mole stamps sessions in local time: "2026-10-01 13:50:12"
        let stamp = DateFormatter()
        stamp.dateFormat = "yyyy-MM-dd HH:mm:ss"
        stamp.locale = Locale(identifier: "en_US_POSIX")
        stamp.timeZone = .current

        guard let history = try? JSONDecoder().decode(History.self, from: data) else { return nil }
        let session = history.sessions.first { entry in
            guard entry.command == "clean",
                  let raw = entry.started_at,
                  let startedAt = stamp.date(from: raw)
            else { return false }
            return startedAt >= threshold
        }
        guard let session else { return nil }
        return Session(items: session.items, sizeBytes: session.size.flatMap(Disk.parseHumanSize))
    }
}
