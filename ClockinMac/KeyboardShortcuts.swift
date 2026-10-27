import AppKit
import Carbon
import Combine

/// Carbon delivers only the four registered keys, without an event-tap permission.
@MainActor
final class KeyboardShortcutController: ObservableObject {
    static let shared = KeyboardShortcutController()
    static let enabledKey = "Clockin.GlobalShortcutsEnabled"
    @Published private(set) var isEnabled = UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    @Published private(set) var registrationFailed = false
    private var handler: EventHandlerRef?
    private var hotKeys: [EventHotKeyRef] = []
    private var store: ClockStore?
    private static let signature: OSType = 0x434C4B4E // CLKN

    func start(store: ClockStore) {
        self.store = store
        guard isEnabled, handler == nil else { return }
        registrationFailed = false
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let result = InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            guard let event else { return OSStatus(eventNotHandledErr) }
            var key = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                          EventParamType(typeEventHotKeyID), nil,
                                          MemoryLayout<EventHotKeyID>.size, nil, &key)
            guard status == noErr, key.signature == 0x434C4B4E else { return OSStatus(eventNotHandledErr) }
            let id = key.id
            Task { @MainActor in KeyboardShortcutController.shared.perform(id) }
            return noErr
        }, 1, &event, nil, &handler)
        guard result == noErr else { registrationFailed = true; return }
        for (index, code) in [kVK_ANSI_I, kVK_ANSI_P, kVK_ANSI_O, kVK_ANSI_E].enumerated() {
            var reference: EventHotKeyRef?
            let id = EventHotKeyID(signature: Self.signature, id: UInt32(index + 1))
            let status = RegisterEventHotKey(UInt32(code), UInt32(cmdKey | optionKey), id,
                                            GetApplicationEventTarget(), 0, &reference)
            if status == noErr, let reference { hotKeys.append(reference) }
            else { registrationFailed = true }
        }
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.enabledKey)
        if enabled {
            if let store { start(store: store) }
        } else {
            unregister()
        }
    }

    func stop() {
        unregister()
        store = nil
    }

    private func unregister() {
        hotKeys.forEach { UnregisterEventHotKey($0) }
        hotKeys.removeAll()
        if let handler { RemoveEventHandler(handler) }
        handler = nil
        registrationFailed = false
    }

    private func perform(_ id: UInt32) {
        guard isEnabled, let store else { return }
        switch id {
        case 1:
            if store.running == nil { store.clockIn(origin: .shortcut) }
            else if store.running?.isPaused == true { store.resume(origin: .shortcut) }
        case 2:
            if store.running?.isPaused == true { store.resume(origin: .shortcut) } else { store.pause() }
        case 3: _ = store.clockOut(origin: .shortcut)
        case 4: MacNavigation.shared.open()
        default: break
        }
    }
}
