import Cocoa
import ApplicationServices

enum WindowAction {
    case leftHalf, rightHalf, topHalf, bottomHalf
    case upperLeft, upperRight, lowerLeft, lowerRight
    case fullScreen, center
    case nextMonitor, prevMonitor
    case snapBack
}

struct WindowManager {
    // Quarter-chord: pressing two perpendicular halves on the same modifier within
    // this window (e.g. ⌃⌥⌘→ then ⌃⌥⌘↑) upgrades the result to the matching corner.
    private static let chordWindow: TimeInterval = 0.5
    private static var lastHalf: WindowAction?
    private static var lastHalfTime: TimeInterval = 0

    static func perform(_ action: WindowAction) {
        guard let window = focusedWindow() else { return }
        guard let currentFrame = getFrame(of: window) else { return }
        let windowCenter = CGPoint(x: currentFrame.midX, y: currentFrame.midY)
        guard let screen = ScreenManager.screenContaining(point: windowCenter)
                ?? NSScreen.main else { return }

        switch action {
        case .snapBack:
            lastHalf = nil
            if let restored = SnapBackStore.shared.restore(window: window) {
                setFrame(of: window, to: restored)
            }
            return

        case .nextMonitor:
            lastHalf = nil
            guard let target = ScreenManager.nextScreen(from: screen) else { return }
            SnapBackStore.shared.save(window: window, frame: currentFrame)
            let targetVisible = ScreenManager.visibleFrame(for: target)
            let centered = CGRect(
                x: targetVisible.origin.x + (targetVisible.width - currentFrame.width) / 2,
                y: targetVisible.origin.y + (targetVisible.height - currentFrame.height) / 2,
                width: currentFrame.width,
                height: currentFrame.height
            )
            setFrame(of: window, to: centered)
            return

        case .prevMonitor:
            lastHalf = nil
            guard let target = ScreenManager.prevScreen(from: screen) else { return }
            SnapBackStore.shared.save(window: window, frame: currentFrame)
            let targetVisible = ScreenManager.visibleFrame(for: target)
            let centered = CGRect(
                x: targetVisible.origin.x + (targetVisible.width - currentFrame.width) / 2,
                y: targetVisible.origin.y + (targetVisible.height - currentFrame.height) / 2,
                width: currentFrame.width,
                height: currentFrame.height
            )
            setFrame(of: window, to: centered)
            return

        case .leftHalf, .rightHalf, .topHalf, .bottomHalf:
            handleHalf(action, window: window, currentFrame: currentFrame, screen: screen)
            return

        default:
            break
        }

        // Explicit quarter / fullscreen / center: reset any pending chord.
        lastHalf = nil
        SnapBackStore.shared.save(window: window, frame: currentFrame)
        setFrame(of: window, to: frame(for: action, on: screen, windowSize: currentFrame.size))
    }

    private static func handleHalf(_ half: WindowAction, window: AXUIElement, currentFrame: CGRect, screen: NSScreen) {
        let now = ProcessInfo.processInfo.systemUptime

        // Second perpendicular half within the window → upgrade to a corner.
        // Keep the SnapBack frame saved by the first half (the original frame).
        if let prev = lastHalf, now - lastHalfTime <= chordWindow, let corner = quarter(from: prev, and: half) {
            lastHalf = nil
            setFrame(of: window, to: frame(for: corner, on: screen, windowSize: currentFrame.size))
            return
        }

        SnapBackStore.shared.save(window: window, frame: currentFrame)
        lastHalf = half
        lastHalfTime = now
        setFrame(of: window, to: frame(for: half, on: screen, windowSize: currentFrame.size))
    }

    private static func quarter(from a: WindowAction, and b: WindowAction) -> WindowAction? {
        let pair = Set([a, b])
        if pair == [.rightHalf, .topHalf]    { return .upperRight }
        if pair == [.rightHalf, .bottomHalf] { return .lowerRight }
        if pair == [.leftHalf, .topHalf]     { return .upperLeft }
        if pair == [.leftHalf, .bottomHalf]  { return .lowerLeft }
        return nil  // same axis (e.g. left+right) is not a corner
    }

    private static func frame(for action: WindowAction, on screen: NSScreen, windowSize: CGSize) -> CGRect {
        switch action {
        case .leftHalf:    return ScreenManager.leftHalf(on: screen)
        case .rightHalf:   return ScreenManager.rightHalf(on: screen)
        case .topHalf:     return ScreenManager.topHalf(on: screen)
        case .bottomHalf:  return ScreenManager.bottomHalf(on: screen)
        case .upperLeft:   return ScreenManager.upperLeft(on: screen)
        case .upperRight:  return ScreenManager.upperRight(on: screen)
        case .lowerLeft:   return ScreenManager.lowerLeft(on: screen)
        case .lowerRight:  return ScreenManager.lowerRight(on: screen)
        case .fullScreen:  return ScreenManager.fullScreen(on: screen)
        case .center:      return ScreenManager.centered(on: screen, windowSize: windowSize)
        default:           return .zero
        }
    }

    private static func focusedWindow() -> AXUIElement? {
        // Resolve the frontmost app via NSWorkspace rather than the system-wide
        // AX focused-application attribute. Chrome (and some other apps) return
        // kAXErrorNoValue (-25212) for kAXFocusedApplicationAttribute on the
        // system-wide element, so that path silently fails for them.
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }
        let pid = frontApp.processIdentifier
        let app = AXUIElementCreateApplication(pid)

        var windowRef: CFTypeRef?
        var err = AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &windowRef)

        // Chromium/Electron apps may not expose their accessibility tree until
        // AXManualAccessibility is set. Set it and retry.
        if err != .success {
            AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
            err = AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &windowRef)
        }

        // Some apps expose a main window but no "focused" window. Fall back.
        if err != .success {
            err = AXUIElementCopyAttributeValue(app, kAXMainWindowAttribute as CFString, &windowRef)
        }

        guard err == .success, let ref = windowRef else { return nil }
        return (ref as! AXUIElement)
    }

    private static func getFrame(of window: AXUIElement) -> CGRect? {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success else { return nil }

        var pos = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(posRef as! AXValue, .cgPoint, &pos)
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)

        return CGRect(origin: pos, size: size)
    }

    private static func setFrame(of window: AXUIElement, to frame: CGRect) {
        var pos = frame.origin
        var size = frame.size

        if let posValue = AXValueCreate(.cgPoint, &pos) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)
        }
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        }
    }
}
