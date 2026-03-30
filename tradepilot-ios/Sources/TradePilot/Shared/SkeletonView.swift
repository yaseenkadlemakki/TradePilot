import SwiftUI

/// Animated shimmer loading placeholder.
struct SkeletonView: View {
    let width: CGFloat?
    let height: CGFloat
    let cornerRadius: CGFloat

    init(width: CGFloat? = nil, height: CGFloat = 16, cornerRadius: CGFloat = 4) {
        self.width        = width
        self.height       = height
        self.cornerRadius = cornerRadius
    }

    @State private var phase: CGFloat = 0

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(shimmerGradient)
            .frame(width: width, height: height)
            .accessibilityHidden(true)
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }

    private var shimmerGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.gray.opacity(0.12),
                Color.gray.opacity(0.24),
                Color.gray.opacity(0.12)
            ]),
            startPoint: UnitPoint(x: phase - 1, y: 0.5),
            endPoint: UnitPoint(x: phase, y: 0.5)
        )
    }
}

/// Stack of skeleton rows that mimic a TradeCardView.
struct TradeCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SkeletonView(width: 60, height: 20, cornerRadius: 4)
                Spacer()
                SkeletonView(width: 70, height: 18, cornerRadius: 9)
            }
            SkeletonView(height: 14)
            SkeletonView(width: 120, height: 14)
        }
        .padding()
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
