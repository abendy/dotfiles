import AppKit
import DiskPruneCore

/// Menu-bar frontend for mole, sharing DiskPruneCore with the disk-prune
/// CLI, so what it displays and what the scheduled run frees always agree.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private var summary: DryRunSummary?
    private var refreshing = false
    private var pruning = false
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "internaldrive",
                                   accessibilityDescription: "disk-prune")
        }
        statusItem.menu = menu

        rebuildMenu(status: "Measuring…")
        refresh()

        // A refresh runs `mo clean --dry-run` (~30s) plus a few du calls;
        // every 6 hours plus a manual Refresh item is plenty for a monthly
        // cleaner.
        timer = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    private func refresh() {
        guard !refreshing else { return }
        refreshing = true
        DispatchQueue.global(qos: .utility).async {
            let summary = Runner.dryRun(config: Config.load())
            DispatchQueue.main.async {
                self.summary = summary
                self.refreshing = false
                self.rebuildMenu(status: nil)
            }
        }
    }

    private func rebuildMenu(status: String?) {
        menu.removeAllItems()

        let headline: String
        if let status {
            headline = status
        } else if let summary {
            if summary.mole == nil {
                headline = "mole not installed"
            } else {
                headline = "Prunable: \(Disk.format(summary.prunableBytes))"
            }
        } else {
            headline = "No measurement"
        }
        menu.addItem(disabled(headline))
        statusItem.button?.toolTip = "disk-prune - \(headline)"

        if status == nil, let summary {
            menu.addItem(.separator())

            if let mole = summary.mole {
                let items = mole.items.map { " · \($0) items" } ?? ""
                menu.addItem(disabled("mole: \(mole.potentialBytes.map(Disk.format) ?? "-")\(items)"))
            } else {
                menu.addItem(disabled("mole: not found (brew install mole)"))
            }

            let dockerSize = summary.dockerBytes.map(Disk.format) ?? summary.dockerDetail ?? "-"
            let dockerSuffix = summary.dockerMode == .off ? "  (off until #37)" : ""
            menu.addItem(disabled("Docker: \(dockerSize)\(dockerSuffix)"))

            menu.addItem(.separator())
            menu.addItem(disabled("Watched, never pruned:"))
            for watch in summary.watches {
                menu.addItem(disabled("\(watch.label): \(watch.bytes.map(Disk.format) ?? "-")"))
            }
        }

        menu.addItem(.separator())

        let prune = NSMenuItem(title: pruning ? "Pruning…" : "Prune Now",
                               action: #selector(pruneNow), keyEquivalent: "")
        prune.target = self
        prune.isEnabled = !pruning && !refreshing && summary?.mole != nil
        menu.addItem(prune)

        let refresh = NSMenuItem(title: "Refresh", action: #selector(refreshClicked), keyEquivalent: "r")
        refresh.target = self
        refresh.isEnabled = !refreshing
        menu.addItem(refresh)

        menu.addItem(.separator())
        menu.addItem(actionItem("Open Log", #selector(openLog)))
        menu.addItem(actionItem("Open Config", #selector(openConfig)))
        menu.addItem(actionItem("Open mole Whitelist", #selector(openWhitelist)))
        menu.addItem(.separator())
        menu.addItem(actionItem("Quit disk-prune", #selector(quit), key: "q"))

        // Explicit isEnabled above instead of autoenabling, which would grey
        // out items whose actions live on this delegate rather than a responder.
        menu.autoenablesItems = false
    }

    private func disabled(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func actionItem(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func refreshClicked() {
        refresh()
    }

    @objc private func pruneNow() {
        guard !pruning else { return }
        pruning = true
        rebuildMenu(status: "Pruning…")
        DispatchQueue.global(qos: .userInitiated).async {
            _ = Runner.run(config: Config.load())
            DispatchQueue.main.async {
                self.pruning = false
                self.refresh()
            }
        }
    }

    @objc private func openLog() {
        if !FileManager.default.fileExists(atPath: Log.path) {
            Log.append("log created from menu bar app")
        }
        NSWorkspace.shared.open(URL(fileURLWithPath: Log.path))
    }

    @objc private func openConfig() {
        NSWorkspace.shared.open(URL(fileURLWithPath: Config.defaultPath))
    }

    @objc private func openWhitelist() {
        NSWorkspace.shared.open(URL(fileURLWithPath: NSHomeDirectory() + "/.config/mole/whitelist"))
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
