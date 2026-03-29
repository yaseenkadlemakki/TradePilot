import SwiftUI

// MARK: - VoiceOver label modifier

/// Applies a VoiceOver accessibility label and optional hint to any view.
struct AccessibilityLabelModifier: ViewModifier {
    let label: String
    let hint: String?

    func body(content: Content) -> some View {
        content
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
    }
}

// MARK: - Dynamic Type scaling modifier

/// Caps Dynamic Type scaling so layouts don't break at the largest accessibility sizes.
struct DynamicTypeModifier: ViewModifier {
    let maximumSize: DynamicTypeSize

    func body(content: Content) -> some View {
        content
            .dynamicTypeSize(...maximumSize)
    }
}

// MARK: - Trait modifier

/// Marks a view with a semantic accessibility trait (e.g. `.isButton`, `.isHeader`).
struct AccessibilityTraitModifier: ViewModifier {
    let trait: AccessibilityTraits

    func body(content: Content) -> some View {
        content.accessibilityAddTraits(trait)
    }
}

// MARK: - View extensions

extension View {
    /// Adds a VoiceOver label and optional hint.
    func voiceOverLabel(_ label: String, hint: String? = nil) -> some View {
        modifier(AccessibilityLabelModifier(label: label, hint: hint))
    }

    /// Caps Dynamic Type scaling at `maximumSize` (default `.xxxLarge`).
    func cappedDynamicType(_ maximumSize: DynamicTypeSize = .xxxLarge) -> some View {
        modifier(DynamicTypeModifier(maximumSize: maximumSize))
    }

    /// Marks the view with the given accessibility trait.
    func accessibilityTrait(_ trait: AccessibilityTraits) -> some View {
        modifier(AccessibilityTraitModifier(trait: trait))
    }
}
