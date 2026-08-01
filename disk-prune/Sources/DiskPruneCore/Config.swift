import Foundation

public enum TargetMode: String, Codable {
    /// Measure and delete.
    case prune
    /// Measure and report, delete nothing.
    case report
    /// Skip entirely.
    case off
}

public struct Config: Codable {
    public var notify: Bool
    public var targets: [String: TargetMode]

    public static let defaultPath = NSHomeDirectory() + "/.config/disk-prune/config.json"

    /// Shipped defaults. docker stays off until dotfiles issue #37 (Docker
    /// Desktop vs colima) picks a surviving runtime; trash and node_modules
    /// are report-only by design - the Trash is user data (Finder's own
    /// 30-day auto-empty handles it) and node_modules removal would force
    /// reinstalls in active projects.
    public static let defaults = Config(
        notify: true,
        targets: [
            "brew": .prune,
            "npm": .prune,
            "brave": .prune,
            "codex": .prune,
            "docker": .off,
            "chrome_ai": .report,
            "trash": .report,
            "node_modules": .report,
        ]
    )

    public static func load(from path: String = defaultPath) -> Config {
        guard let data = FileManager.default.contents(atPath: path) else {
            return defaults
        }
        do {
            var config = try JSONDecoder().decode(Config.self, from: data)
            // A target absent from the file keeps its shipped default, so a
            // hand-trimmed config doesn't silently drop targets.
            for (id, mode) in defaults.targets where config.targets[id] == nil {
                config.targets[id] = mode
            }
            return config
        } catch {
            // A malformed config must not turn into a prune with surprise
            // settings; fall back to defaults and say so in the log.
            Log.append("config: failed to parse \(path) (\(error.localizedDescription)); using defaults")
            return defaults
        }
    }

    public func mode(for id: String) -> TargetMode {
        targets[id] ?? Config.defaults.targets[id] ?? .off
    }
}
