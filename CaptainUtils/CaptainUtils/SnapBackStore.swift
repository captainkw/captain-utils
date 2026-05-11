import Foundation
import ApplicationServices

struct WindowKey: Hashable {
    let pid: pid_t
    let title: String
}

class SnapBackStore {
    static let shared = SnapBackStore()
    private var frames: [WindowKey: CGRect] = [:]

    func save(window: AXUIElement, frame: CGRect) {
        let key = makeKey(for: window)
        frames[key] = frame
    }

    func restore(window: AXUIElement) -> CGRect? {
        let key = makeKey(for: window)
        return frames.removeValue(forKey: key)
    }

    private func makeKey(for window: AXUIElement) -> WindowKey {
        var pid: pid_t = 0
        AXUIElementGetPid(window, &pid)

        var titleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef)
        let title = (titleRef as? String) ?? ""

        return WindowKey(pid: pid, title: title)
    }
}
