import Foundation

/// mole owns the cleaning policy (its whitelist protects paths from
/// `mo clean`), so this config is down to the two knobs mole doesn't have.
public struct Config: Codable {
    /// Post a macOS notification with the freed total after each run.
    public var notify: Bool

    /// The one prune decision mole doesn't cover: mole only *reports* Docker
    /// storage. "prune" runs `docker system prune -af` after mole; "off"
    /// (the default) skips it until dotfiles issue #37 (Docker Desktop vs
    /// colima) picks the surviving runtime.
    public var docker: DockerMode

    public enum DockerMode: String, Codable {
        case off
        case prune
    }

    public static let defaultPath = NSHomeDirectory() + "/.config/disk-prune/config.json"

    public static let defaults = Config(notify: true, docker: .off)

    public static func load(from path: String = defaultPath) -> Config {
        guard let data = FileManager.default.contents(atPath: path) else {
            return defaults
        }
        do {
            return try JSONDecoder().decode(Config.self, from: data)
        } catch {
            // Covers both a malformed file and the pre-mole per-target
            // schema; a bad config must not turn into a run with surprise
            // settings. install.sh migrates old files on the next install.
            Log.append("config: failed to parse \(path) (\(error.localizedDescription)); using defaults")
            return defaults
        }
    }
}
