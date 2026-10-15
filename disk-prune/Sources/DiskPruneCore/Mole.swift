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
        let result = Shell.run(mo, ["clean"])
        // The freed total is read from this invocation's own output. mole's
        // history (`mo history --json`) was tried first, but its sessions
        // carry nothing that ties one to a given process, and a concurrent
        // `--dry-run` (the menu bar's refresh) writes `clean` sessions too -
        // so any history lookup can hand back another run's total. A
        // failed or aborted run prints no summary and reports nothing.
        let summary = parseCleanSummary(result.stdout)
        return Clean(
            freedBytes: summary.bytes,
            items: summary.items,
            output: result.stdout,
            succeeded: result.succeeded
        )
    }

    /// Summary line of a real run (bin/clean.sh, perform_cleanup):
    /// "Tracked cleanup: 4.26GB | Items cleaned: 271 | Categories: 12".
    /// The items segment is omitted when nothing was cleaned.
    static func parseCleanSummary(_ output: String) -> (bytes: Int64?, items: Int?) {
        let plain = Text.stripANSI(output)
        let bytes = Text.capture(#"Tracked cleanup: ([0-9.]+[kKMGT]?i?B)"#, in: plain)
            .flatMap(Disk.parseHumanSize)
        let items = Text.capture(#"Items cleaned: ([0-9]+)"#, in: plain).flatMap { Int($0) }
        return (bytes, items)
    }
}
