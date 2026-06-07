import Cocoa
import ApplicationServices

func log(_ msg: String) {
    fputs("[CaptainUtils] \(msg)\n", stderr)
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var hotkeyManager: HotkeyManager!
    private var accessibilityTimer: Timer?
    private var accessibilityMenuItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        log("launched")
        setupMenuBar()
        checkAccessibilityAndStart()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "rectangle.split.2x2", accessibilityDescription: "CaptainUtils")
        }

        let menu = NSMenu()
        let titleItem = NSMenuItem(title: "CaptainUtils", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "About CaptainUtils", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Shortcuts", action: #selector(showShortcuts), keyEquivalent: ""))

        accessibilityMenuItem = NSMenuItem(title: accessibilityMenuTitle(), action: #selector(openAccessibilitySettings), keyEquivalent: "")
        menu.addItem(accessibilityMenuItem)

        let loginItem = NSMenuItem(title: "Start at Login", action: #selector(toggleLoginItem), keyEquivalent: "")
        loginItem.state = isLoginItemEnabled() ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func accessibilityMenuTitle() -> String {
        AXIsProcessTrusted() ? "Accessibility: Granted ✓" : "Open Accessibility Settings…"
    }

    @objc private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        startPollingForAccessibility()
    }

    private static let launchAgentPlistPath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Library/LaunchAgents/com.captainutils.app.plist"
    }()

    private func isLoginItemEnabled() -> Bool {
        FileManager.default.fileExists(atPath: Self.launchAgentPlistPath)
    }

    @objc private func toggleLoginItem(_ sender: NSMenuItem) {
        do {
            if isLoginItemEnabled() {
                try FileManager.default.removeItem(atPath: Self.launchAgentPlistPath)
                sender.state = .off
                log("login item unregistered")
            } else {
                let appPath = Bundle.main.bundlePath
                let plist = """
                <?xml version="1.0" encoding="UTF-8"?>
                <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
                <plist version="1.0">
                <dict>
                    <key>Label</key>
                    <string>com.captainutils.app</string>
                    <key>ProgramArguments</key>
                    <array>
                        <string>\(appPath)/Contents/MacOS/CaptainUtils</string>
                    </array>
                    <key>RunAtLoad</key>
                    <true/>
                </dict>
                </plist>
                """
                try plist.write(toFile: Self.launchAgentPlistPath, atomically: true, encoding: .utf8)
                sender.state = .on
                log("login item registered")
            }
        } catch {
            log("login item error: \(error)")
            let alert = NSAlert()
            alert.messageText = "Could not change Start at Login"
            alert.informativeText = "\(error.localizedDescription)"
            alert.runModal()
        }
    }

    private func checkAccessibilityAndStart() {
        let trusted = AXIsProcessTrusted()
        log("accessibility trusted = \(trusted)")

        if trusted {
            startHotkeyManager()
        } else {
            startPollingForAccessibility()
        }
    }

    private func startPollingForAccessibility() {
        if accessibilityTimer != nil || hotkeyManager != nil { return }
        accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            if AXIsProcessTrusted() {
                log("accessibility granted, registering hotkeys")
                timer.invalidate()
                self.accessibilityTimer = nil
                self.startHotkeyManager()
                self.accessibilityMenuItem.title = self.accessibilityMenuTitle()
            }
        }
    }

    private func startHotkeyManager() {
        log("registering hotkeys")
        hotkeyManager = HotkeyManager()
        hotkeyManager.registerAll()
        log("hotkeys registered")
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "CaptainUtils"
        alert.informativeText = "Window manager for macOS.\nA native Apple Silicon replacement for SizeUp.\n\nVersion 1.0"
        alert.alertStyle = .informational
        alert.runModal()
    }

    @objc private func showShortcuts() {
        let shortcuts = """
        Halves
            ⌃⌥⌘←     Left half
            ⌃⌥⌘→     Right half
            ⌃⌥⌘↑     Top half
            ⌃⌥⌘↓     Bottom half

        Quarters
            ⌃⌥⇧←     Upper-left
            ⌃⌥⇧↑     Upper-right
            ⌃⌥⇧↓     Lower-left
            ⌃⌥⇧→     Lower-right

        Multi-Monitor
            ⌃⌥←       Previous monitor
            ⌃⌥→       Next monitor

        Other
            ⌃⌥⌘M     Fullscreen (maximize)
            ⌃⌥⌘C     Center window
            ⌃⌥⌘/      SnapBack (restore previous position)
        """
        let alert = NSAlert()
        alert.messageText = "CaptainUtils Shortcuts"
        alert.informativeText = shortcuts
        alert.alertStyle = .informational
        alert.runModal()
    }
}
