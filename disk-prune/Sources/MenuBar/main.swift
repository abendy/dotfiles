import AppKit
import DiskPruneCore

/// Menu-bar companion to the disk-prune CLI. Links the same DiskPruneCore,
/// so what it displays and what the scheduled run frees always agree.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private var reports: [TargetReport] = []
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

        // Measuring is cheap (a few du calls), but not free - every 6 hours
        // plus a manual Refresh item is plenty for a monthly pruner.
        timer = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    private func refresh() {
        guard !refreshing else { return }
        refreshing = true
        DispatchQueue.global(qos: .utility).async {
            let reports = Runner.dryRun(config: Config.load())
            DispatchQueue.main.async {
                self.reports = reports
                self.refreshing = false
                self.rebuildMenu(status: nil)
            }
        }
    }

    private func rebuildMenu(status: String?) {
        menu.removeAllItems()

        var pruneTotal: Int64 = 0
        var reportTotal: Int64 = 0
        for report in reports where report.bytes != nil {
            if report.effectiveMode == .prune {
                pruneTotal += report.bytes ?? 0
            } else if report.effectiveMode == .report {
                reportTotal += report.bytes ?? 0
            }
        }

        let headline: String
        if let status {
            headline = status
        } else {
            headline = "Prunable: \(Disk.format(pruneTotal))"
        }
        menu.addItem(disabled(headline))
        statusItem.button?.toolTip = "disk-prune - \(headline)"

        if status == nil {
            menu.addItem(.separator())
            for report in reports {
                var title = "\(report.label): \(report.bytes.map(Disk.format) ?? "-")"
                switch report.effectiveMode {
                case .report: title += "  (report-only)"
                case .off: title = "\(report.label): off"
                case .prune: break
                }
                menu.addItem(disabled(title))
            }
            if reportTotal > 0 {
                menu.addItem(disabled("Report-only total: \(Disk.format(reportTotal))"))
            }
        }

        menu.addItem(.separator())

        let prune = NSMenuItem(title: pruning ? "Pruning…" : "Prune Now",
                               action: #selector(pruneNow), keyEquivalent: "")
        prune.target = self
        prune.isEnabled = !pruning && !refreshing
        menu.addItem(prune)

        let refresh = NSMenuItem(title: "Refresh", action: #selector(refreshClicked), keyEquivalent: "r")
        refresh.target = self
        refresh.isEnabled = !refreshing
        menu.addItem(refresh)

        menu.addItem(.separator())
        menu.addItem(actionItem("Open Log", #selector(openLog)))
        menu.addItem(actionItem("Open Config", #selector(openConfig)))
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

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
