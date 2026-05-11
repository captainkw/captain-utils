import Carbon.HIToolbox
import Cocoa

class HotkeyManager {
    private var hotkeyRefs: [EventHotKeyRef] = []
    private var eventHandlerRef: EventHandlerRef?

    private static var actions: [UInt32: WindowAction] = [:]

    func registerAll() {
        installHandler()

        let ctrl = UInt32(controlKey)
        let opt = UInt32(optionKey)
        let cmd = UInt32(cmdKey)
        let shift = UInt32(shiftKey)

        // Halves: ⌃⌥⌘ + arrow
        register(id: 1,  key: kVK_LeftArrow,  mods: ctrl|opt|cmd, action: .leftHalf)
        register(id: 2,  key: kVK_RightArrow, mods: ctrl|opt|cmd, action: .rightHalf)
        register(id: 3,  key: kVK_UpArrow,    mods: ctrl|opt|cmd, action: .topHalf)
        register(id: 4,  key: kVK_DownArrow,  mods: ctrl|opt|cmd, action: .bottomHalf)

        // Quarters: ⌃⌥⇧ + arrow
        register(id: 5,  key: kVK_LeftArrow,  mods: ctrl|opt|shift, action: .upperLeft)
        register(id: 6,  key: kVK_UpArrow,    mods: ctrl|opt|shift, action: .upperRight)
        register(id: 7,  key: kVK_DownArrow,  mods: ctrl|opt|shift, action: .lowerLeft)
        register(id: 8,  key: kVK_RightArrow, mods: ctrl|opt|shift, action: .lowerRight)

        // Multi-monitor: ⌃⌥ + arrow
        register(id: 9,  key: kVK_LeftArrow,  mods: ctrl|opt, action: .prevMonitor)
        register(id: 10, key: kVK_RightArrow, mods: ctrl|opt, action: .nextMonitor)

        // Fullscreen, center, snapback: ⌃⌥⌘ + key
        register(id: 11, key: kVK_ANSI_M,     mods: ctrl|opt|cmd, action: .fullScreen)
        register(id: 12, key: kVK_ANSI_C,     mods: ctrl|opt|cmd, action: .center)
        register(id: 13, key: kVK_ANSI_Slash, mods: ctrl|opt|cmd, action: .snapBack)
    }

    private func installHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let handler: EventHandlerUPP = { _, event, _ -> OSStatus in
            var hotkeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hotkeyID)

            if let action = HotkeyManager.actions[hotkeyID.id] {
                DispatchQueue.main.async {
                    WindowManager.perform(action)
                }
            }
            return noErr
        }

        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, &eventHandlerRef)
    }

    private func register(id: UInt32, key: Int, mods: UInt32, action: WindowAction) {
        let hotkeyID = EventHotKeyID(signature: fourCharCode("CPTL"), id: id)
        var hotkeyRef: EventHotKeyRef?

        let status = RegisterEventHotKey(UInt32(key), mods, hotkeyID,
                                         GetApplicationEventTarget(), 0, &hotkeyRef)

        if status == noErr, let ref = hotkeyRef {
            hotkeyRefs.append(ref)
            HotkeyManager.actions[id] = action
            log("registered hotkey id=\(id) ok")
        } else {
            log("FAILED to register hotkey id=\(id) status=\(status)")
        }
    }

    deinit {
        for ref in hotkeyRefs {
            UnregisterEventHotKey(ref)
        }
    }
}

private func fourCharCode(_ string: String) -> OSType {
    var result: OSType = 0
    for char in string.utf8.prefix(4) {
        result = (result << 8) | OSType(char)
    }
    return result
}
