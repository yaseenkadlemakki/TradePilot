import SwiftUI

struct OnboardingView: View {
    var onComplete: () -> Void

    @State private var currentPage = 0

    private struct Page {
        let title: String
        let subtitle: String
        let systemImage: String
        let color: Color
    }

    private let pages: [Page] = [
        Page(
            title: "AI-Powered Options",
            subtitle: "TradePilot combines sentiment, unusual flow, and technical signals to surface high-conviction trade setups.",
            systemImage: "brain.head.profile",
            color: .blue
        ),
        Page(
            title: "Full Transparency",
            subtitle: "Every recommendation includes detailed rationale, supporting signals, risk analysis, and source citations.",
            systemImage: "doc.text.magnifyingglass",
            color: .green
        ),
        Page(
            title: "Your Keys, Your Data",
            subtitle: "Bring your own API keys. All data stays on-device — nothing is sent to external servers.",
            systemImage: "lock.shield",
            color: .purple
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { idx in
                    pageView(pages[idx]).tag(idx)
                }
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .never))
            #endif
            .animation(.easeInOut, value: currentPage)

            bottomBar
        }
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Sub-views

    private func pageView(_ page: Page) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: page.systemImage)
                .font(.system(size: 72))
                .foregroundStyle(page.color)
                .padding(.bottom, 8)
            Text(page.title)
                .font(.title.weight(.bold))
                .multilineTextAlignment(.center)
            Text(page.subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 16) {
            pageIndicator

            Button(action: advance) {
                Text(currentPage == pages.count - 1 ? "Get Started" : "Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(pages[currentPage].color)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(.background)
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(pages.indices, id: \.self) { idx in
                Circle()
                    .fill(idx == currentPage ? pages[currentPage].color : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut, value: currentPage)
            }
        }
    }

    private func advance() {
        if currentPage < pages.count - 1 {
            currentPage += 1
        } else {
            onComplete()
        }
    }
}
