import Cocoa
import ApplicationServices
import SwiftUI

func log(_ msg: String) {
    fputs("[CaptainUtils] \(msg)\n", stderr)
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var hotkeyManager: HotkeyManager!
    private var accessibilityTimer: Timer?
    private var accessibilityMenuItem: NSMenuItem!
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        log("launched")
        CenterWindowSettings.registerDefaults()
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
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ","))

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

    @objc private func showSettings() {
        if settingsWindow == nil {
            let content = NSHostingController(rootView: CenterWindowSettingsView())
            let window = NSWindow(contentViewController: content)
            window.title = "CaptainUtils Settings"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.standardWindowButton(.miniaturizeButton)?.isEnabled = false
            window.standardWindowButton(.zoomButton)?.isEnabled = false
            window.contentMinSize = NSSize(width: 400, height: 280)
            window.contentMaxSize = NSSize(width: 400, height: 280)
            window.setContentSize(NSSize(width: 400, height: 280))
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }

        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
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

enum CenterResizeMode: String {
    case relative
    case absolute
}

enum CenterWindowSettings {
    static let enabledKey = "center.resize.enabled"
    static let modeKey = "center.resize.mode"
    static let absoluteWidthKey = "center.resize.absoluteWidth"
    static let absoluteHeightKey = "center.resize.absoluteHeight"
    static let relativeWidthKey = "center.resize.relativeWidth"
    static let relativeHeightKey = "center.resize.relativeHeight"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            enabledKey: false,
            modeKey: CenterResizeMode.relative.rawValue,
            absoluteWidthKey: 800.0,
            absoluteHeightKey: 600.0,
            relativeWidthKey: 95.0,
            relativeHeightKey: 95.0,
        ])
    }

    static var isResizeEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    static func targetSize(in visibleFrame: CGRect) -> CGSize {
        let defaults = UserDefaults.standard
        let mode = CenterResizeMode(rawValue: defaults.string(forKey: modeKey) ?? "") ?? .relative

        switch mode {
        case .relative:
            let width = bounded(defaults.double(forKey: relativeWidthKey), fallback: 95, maximum: 100)
            let height = bounded(defaults.double(forKey: relativeHeightKey), fallback: 95, maximum: 100)
            return CGSize(width: visibleFrame.width * width / 100,
                          height: visibleFrame.height * height / 100)
        case .absolute:
            let width = bounded(defaults.double(forKey: absoluteWidthKey), fallback: 800, maximum: visibleFrame.width)
            let height = bounded(defaults.double(forKey: absoluteHeightKey), fallback: 600, maximum: visibleFrame.height)
            return CGSize(width: width, height: height)
        }
    }

    private static func bounded(_ value: Double, fallback: Double, maximum: CGFloat) -> CGFloat {
        let finiteValue = value.isFinite ? value : fallback
        return min(max(CGFloat(finiteValue), 1), maximum)
    }
}

private struct CenterWindowSettingsView: View {
    @AppStorage(CenterWindowSettings.enabledKey) private var resizeEnabled = false
    @AppStorage(CenterWindowSettings.modeKey) private var modeValue = CenterResizeMode.relative.rawValue
    @AppStorage(CenterWindowSettings.absoluteWidthKey) private var absoluteWidth = 800.0
    @AppStorage(CenterWindowSettings.absoluteHeightKey) private var absoluteHeight = 600.0
    @AppStorage(CenterWindowSettings.relativeWidthKey) private var relativeWidth = 95.0
    @AppStorage(CenterWindowSettings.relativeHeightKey) private var relativeHeight = 95.0

    private var mode: CenterResizeMode {
        CenterResizeMode(rawValue: modeValue) ?? .relative
    }

    private var modeBinding: Binding<CenterResizeMode> {
        Binding(
            get: { mode },
            set: { modeValue = $0.rawValue }
        )
    }

    private var widthBinding: Binding<Double> {
        switch mode {
        case .relative:
            return Binding(get: { relativeWidth }, set: { relativeWidth = min(max($0, 1), 100) })
        case .absolute:
            return Binding(get: { absoluteWidth }, set: { absoluteWidth = max($0, 1) })
        }
    }

    private var heightBinding: Binding<Double> {
        switch mode {
        case .relative:
            return Binding(get: { relativeHeight }, set: { relativeHeight = min(max($0, 1), 100) })
        case .absolute:
            return Binding(get: { absoluteHeight }, set: { absoluteHeight = max($0, 1) })
        }
    }

    var body: some View {
        Form {
            Section("Center Window") {
                Toggle("Resize when centering", isOn: $resizeEnabled)
                    .toggleStyle(.switch)

                Group {
                    Picker("Resize to", selection: modeBinding) {
                        Text("Percentage of usable screen").tag(CenterResizeMode.relative)
                        Text("Absolute size").tag(CenterResizeMode.absolute)
                    }
                    .pickerStyle(.radioGroup)

                    LabeledContent("Width") {
                        sizeField(value: widthBinding, label: "Width")
                    }
                    LabeledContent("Height") {
                        sizeField(value: heightBinding, label: "Height")
                    }
                }
                .disabled(!resizeEnabled)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 280)
    }

    private func sizeField(value: Binding<Double>, label: String) -> some View {
        HStack(spacing: 6) {
            TextField(label, value: value, format: .number.precision(.fractionLength(0)))
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
                .accessibilityLabel("\(label) \(mode == .relative ? "percentage" : "in points")")
            Text(mode == .relative ? "%" : "pt")
                .foregroundStyle(.secondary)
                .frame(width: 20, alignment: .leading)
        }
    }
}
