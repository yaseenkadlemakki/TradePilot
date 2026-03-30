import SwiftUI

/// Colored pill label for a StrategyType.
struct StrategyBadge: View {
    let strategy: StrategyType

    var body: some View {
        Text(strategy.displayName)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(strategy.color.opacity(0.15))
            .foregroundStyle(strategy.color)
            .clipShape(Capsule())
            .accessibilityLabel("\(strategy.displayName) strategy")
    }
}
