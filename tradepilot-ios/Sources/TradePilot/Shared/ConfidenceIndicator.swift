import SwiftUI

/// Color-coded confidence score indicator (0.0–1.0).
struct ConfidenceIndicator: View {
    let score: Double   // 0.0 to 1.0

    private var color: Color {
        switch score {
        case 0.75...: return .green
        case 0.5...: return .yellow
        default:     return .red
        }
    }

    private var label: String {
        String(format: "%.0f%%", score * 100)
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption.monospacedDigit())
                .foregroundStyle(color)
        }
        .voiceOverLabel("Confidence \(label), \(score >= 0.75 ? \"high\" : score >= 0.5 ? \"medium\" : \"low\")")
        .accessibilityTrait(.isStaticText)
    }
}
