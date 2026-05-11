import Cocoa

struct ScreenManager {
    static func orderedScreens() -> [NSScreen] {
        NSScreen.screens.sorted { $0.frame.origin.x < $1.frame.origin.x }
    }

    static func screenContaining(point: CGPoint) -> NSScreen? {
        let nsPoint = CGPoint(x: point.x, y: primaryScreenHeight() - point.y)
        return NSScreen.screens.first { NSPointInRect(nsPoint, $0.frame) }
    }

    static func nextScreen(from current: NSScreen) -> NSScreen? {
        let screens = orderedScreens()
        guard screens.count > 1,
              let idx = screens.firstIndex(of: current) else { return nil }
        return screens[(idx + 1) % screens.count]
    }

    static func prevScreen(from current: NSScreen) -> NSScreen? {
        let screens = orderedScreens()
        guard screens.count > 1,
              let idx = screens.firstIndex(of: current) else { return nil }
        return screens[(idx - 1 + screens.count) % screens.count]
    }

    static func visibleFrame(for screen: NSScreen) -> CGRect {
        let nsFrame = screen.visibleFrame
        let y = primaryScreenHeight() - nsFrame.origin.y - nsFrame.height
        return CGRect(x: nsFrame.origin.x, y: y, width: nsFrame.width, height: nsFrame.height)
    }

    static func primaryScreenHeight() -> CGFloat {
        NSScreen.screens.first?.frame.height ?? 0
    }

    // MARK: - Target frames in CG coordinates (top-left origin)

    static func leftHalf(on screen: NSScreen) -> CGRect {
        let f = visibleFrame(for: screen)
        return CGRect(x: f.origin.x, y: f.origin.y, width: f.width / 2, height: f.height)
    }

    static func rightHalf(on screen: NSScreen) -> CGRect {
        let f = visibleFrame(for: screen)
        return CGRect(x: f.origin.x + f.width / 2, y: f.origin.y, width: f.width / 2, height: f.height)
    }

    static func topHalf(on screen: NSScreen) -> CGRect {
        let f = visibleFrame(for: screen)
        return CGRect(x: f.origin.x, y: f.origin.y, width: f.width, height: f.height / 2)
    }

    static func bottomHalf(on screen: NSScreen) -> CGRect {
        let f = visibleFrame(for: screen)
        return CGRect(x: f.origin.x, y: f.origin.y + f.height / 2, width: f.width, height: f.height / 2)
    }

    static func upperLeft(on screen: NSScreen) -> CGRect {
        let f = visibleFrame(for: screen)
        return CGRect(x: f.origin.x, y: f.origin.y, width: f.width / 2, height: f.height / 2)
    }

    static func upperRight(on screen: NSScreen) -> CGRect {
        let f = visibleFrame(for: screen)
        return CGRect(x: f.origin.x + f.width / 2, y: f.origin.y, width: f.width / 2, height: f.height / 2)
    }

    static func lowerLeft(on screen: NSScreen) -> CGRect {
        let f = visibleFrame(for: screen)
        return CGRect(x: f.origin.x, y: f.origin.y + f.height / 2, width: f.width / 2, height: f.height / 2)
    }

    static func lowerRight(on screen: NSScreen) -> CGRect {
        let f = visibleFrame(for: screen)
        return CGRect(x: f.origin.x + f.width / 2, y: f.origin.y + f.height / 2, width: f.width / 2, height: f.height / 2)
    }

    static func fullScreen(on screen: NSScreen) -> CGRect {
        visibleFrame(for: screen)
    }

    static func centered(on screen: NSScreen, windowSize: CGSize) -> CGRect {
        let f = visibleFrame(for: screen)
        let x = f.origin.x + (f.width - windowSize.width) / 2
        let y = f.origin.y + (f.height - windowSize.height) / 2
        return CGRect(x: x, y: y, width: windowSize.width, height: windowSize.height)
    }
}
