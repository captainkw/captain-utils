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
    static func perform(_ action: WindowAction) {
        guard let window = focusedWindow() else { return }
        guard let currentFrame = getFrame(of: window) else { return }
        let windowCenter = CGPoint(x: currentFrame.midX, y: currentFrame.midY)
        guard let screen = ScreenManager.screenContaining(point: windowCenter)
                ?? NSScreen.main else { return }

        switch action {
        case .snapBack:
            if let restored = SnapBackStore.shared.restore(window: window) {
                setFrame(of: window, to: restored)
            }
            return

        case .nextMonitor:
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

        default:
            break
        }

        SnapBackStore.shared.save(window: window, frame: currentFrame)

        let targetFrame: CGRect
        switch action {
        case .leftHalf:    targetFrame = ScreenManager.leftHalf(on: screen)
        case .rightHalf:   targetFrame = ScreenManager.rightHalf(on: screen)
        case .topHalf:     targetFrame = ScreenManager.topHalf(on: screen)
        case .bottomHalf:  targetFrame = ScreenManager.bottomHalf(on: screen)
        case .upperLeft:   targetFrame = ScreenManager.upperLeft(on: screen)
        case .upperRight:  targetFrame = ScreenManager.upperRight(on: screen)
        case .lowerLeft:   targetFrame = ScreenManager.lowerLeft(on: screen)
        case .lowerRight:  targetFrame = ScreenManager.lowerRight(on: screen)
        case .fullScreen:  targetFrame = ScreenManager.fullScreen(on: screen)
        case .center:      targetFrame = ScreenManager.centered(on: screen, windowSize: currentFrame.size)
        default: return
        }

        setFrame(of: window, to: targetFrame)
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
