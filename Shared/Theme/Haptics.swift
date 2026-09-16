import SwiftUI

#if !WIDGET_EXTENSION
import UIKit

@MainActor
enum Haptics {
    static var enabled: Bool {
        HapticPolicy.isEnabled(storedValue: UserDefaults.standard.object(forKey: HapticPolicy.enabledKey) as? Bool)
    }

    private static var light: UIImpactFeedbackGenerator?
    private static var soft: UIImpactFeedbackGenerator?
    private static var selection: UISelectionFeedbackGenerator?
    private static var notification: UINotificationFeedbackGenerator?

    static func play(_ event: HapticEvent) {
        guard UIApplication.shared.applicationState == .active,
              let feedback = HapticPolicy.feedback(for: event, enabled: enabled) else { return }
        switch feedback {
        case .lightImpact:
            if light == nil { light = UIImpactFeedbackGenerator(style: .light) }
            light?.prepare()
            light?.impactOccurred()
        case .softImpact(let intensity):
            if soft == nil { soft = UIImpactFeedbackGenerator(style: .soft) }
            soft?.prepare()
            soft?.impactOccurred(intensity: intensity)
        case .selection:
            if selection == nil { selection = UISelectionFeedbackGenerator() }
            selection?.prepare()
            selection?.selectionChanged()
        case .notification(let kind):
            if notification == nil { notification = UINotificationFeedbackGenerator() }
            notification?.prepare()
            switch kind {
            case .success: notification?.notificationOccurred(.success)
            case .warning: notification?.notificationOccurred(.warning)
            case .error: notification?.notificationOccurred(.error)
            }
        case .start, .stop:
            // Oturum sinyalleri SwiftUI uzerinden oynatilir.
            break
        }
    }

    static func sensory(_ event: HapticEvent, enabled: Bool) -> SensoryFeedback? {
        guard let feedback = HapticPolicy.feedback(for: event, enabled: enabled) else { return nil }
        switch feedback {
        case .lightImpact: return .impact(weight: .light)
        case .softImpact(let intensity): return .impact(flexibility: .soft, intensity: intensity)
        case .selection: return .selection
        case .start: return .start
        case .stop: return .stop
        case .notification(.success): return .success
        case .notification(.warning): return .warning
        case .notification(.error): return .error
        }
    }
}

private struct HapticModifier<Value: Equatable>: ViewModifier {
    @AppStorage(HapticPolicy.enabledKey) private var enabled = true
    @Environment(\.scenePhase) private var scenePhase
    let trigger: Value
    let event: (Value, Value) -> HapticEvent?

    func body(content: Content) -> some View {
        content.sensoryFeedback(trigger: trigger) { old, new in
            guard scenePhase == .active, let event = event(old, new) else { return nil }
            return Haptics.sensory(event, enabled: enabled && Haptics.enabled)
        }
    }
}

extension View {
    func hapticFeedback<Value: Equatable>(_ event: HapticEvent, trigger: Value,
                                         condition: @escaping (Value, Value) -> Bool = { _, _ in true }) -> some View {
        modifier(HapticModifier(trigger: trigger, event: { condition($0, $1) ? event : nil }))
    }

    func hapticFeedback(_ signal: HapticSignal) -> some View {
        modifier(HapticModifier(trigger: signal, event: { _, new in new.event }))
    }
}

extension Binding where Value: Equatable {
    // Yalnizca kontrolun yazmasi titresir; disaridan gelen tercihler sessizdir.
    @MainActor
    func hapticSelection(_ signal: Binding<HapticSignal>) -> Binding<Value> {
        Binding(get: { wrappedValue }, set: { newValue in
            let changed = newValue != wrappedValue
            wrappedValue = newValue
            if changed { signal.wrappedValue.send(.selection) }
        })
    }
}
#endif

private struct ButtonPressHapticKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var buttonPressHapticEnabled: Bool {
        get { self[ButtonPressHapticKey.self] }
        set { self[ButtonPressHapticKey.self] = newValue }
    }
}

private struct PressHapticModifier: ViewModifier {
    @Environment(\.buttonPressHapticEnabled) private var allowed
    @Environment(\.isEnabled) private var isEnabled
    let isPressed: Bool

    func body(content: Content) -> some View {
        #if WIDGET_EXTENSION
        content
        #else
        content.onChange(of: isPressed) { old, new in
            if HapticPolicy.pressBegan(wasPressed: old, isPressed: new,
                                      enabled: allowed && isEnabled && Haptics.enabled) != nil {
                Haptics.play(.buttonPress)
            }
        }
        #endif
    }
}

extension View {
    func pressHaptic(isPressed: Bool) -> some View {
        modifier(PressHapticModifier(isPressed: isPressed))
    }

    func buttonPressHaptic(_ enabled: Bool) -> some View {
        environment(\.buttonPressHapticEnabled, enabled)
    }
}
