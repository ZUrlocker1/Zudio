import SwiftUI

// MARK: - onChange backward compatibility (iOS 16 / iOS 17+)
// iOS 17 introduced a two-argument onChange closure; iOS 16 only has the one-argument form.
// Using onChangeCompat avoids deprecation warnings on iOS 17 while still compiling on iOS 16.
extension View {
    // Single-value variant: action receives only the new value.
    @ViewBuilder
    func onChangeCompat<V: Equatable>(of value: V, action: @escaping (V) -> Void) -> some View {
        if #available(iOS 17, *) {
            self.onChange(of: value) { _, newValue in action(newValue) }
        } else {
            self.onChange(of: value, perform: action)
        }
    }

    // Two-value variant: action receives (oldValue, newValue).
    // On iOS 16 oldValue == newValue (the old API doesn't surface it); comparisons against old
    // will simply never detect a transition, which is acceptable for visual-polish features.
    @ViewBuilder
    func onChangeCompat<V: Equatable>(of value: V, action: @escaping (V, V) -> Void) -> some View {
        if #available(iOS 17, *) {
            self.onChange(of: value) { old, new in action(old, new) }
        } else {
            self.onChange(of: value) { new in action(new, new) }
        }
    }

    // presentationContentInteraction(.scrolls) requires iOS 16.4; silently omitted on 16.0–16.3.
    @ViewBuilder
    func presentationScrollsCompat() -> some View {
        if #available(iOS 16.4, *) {
            self.presentationContentInteraction(.scrolls)
        } else {
            self
        }
    }
}

// MARK: - Haptic feedback (iOS 17+ only; silent no-op on iOS 16)
// sensoryFeedback is iOS 17+. On iOS 16 the modifier applies nothing.
#if os(iOS)
struct ZudioHapticsModifier: ViewModifier {
    var impactMedium: Bool
    var impactLight:  Bool
    var impactHeavy:  Bool
    var impactSoft:   Bool
    var impactRigid:  Bool
    var selection:    Bool
    var success:      Bool
    var warning:      Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 17, *) {
            content
                .sensoryFeedback(.impact(weight: .medium),                    trigger: impactMedium)
                .sensoryFeedback(.impact(weight: .light),                     trigger: impactLight)
                .sensoryFeedback(.impact(weight: .heavy),                     trigger: impactHeavy)
                .sensoryFeedback(.impact(flexibility: .soft,  intensity: 0.8), trigger: impactSoft)
                .sensoryFeedback(.impact(flexibility: .rigid, intensity: 1.0), trigger: impactRigid)
                .sensoryFeedback(.selection,                                   trigger: selection)
                .sensoryFeedback(.success,                                     trigger: success)
                .sensoryFeedback(.warning,                                     trigger: warning)
        } else {
            content
        }
    }
}
#endif
