import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @State private var viewModel = SettingsViewModel()

    var body: some View {
        NavigationStack {
            Form {
                apiKeysSection
                preferencesSection
                aboutSection
            }
            .navigationTitle("Settings")
            .onAppear {
                viewModel.loadFromKeychain()
                viewModel.loadPreferences(context: context)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await viewModel.save(context: context) }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
            .overlay(alignment: .bottom) {
                if let msg = viewModel.validationMessage {
                    Text(msg)
                        .font(.footnote)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut, value: viewModel.validationMessage)
        }
    }

    // MARK: - Sections

    private var apiKeysSection: some View {
        Section {
            SecureField("Polygon.io Key", text: $viewModel.polygonKey)
            SecureField("Unusual Whales Key", text: $viewModel.unusualWhalesKey)
            SecureField("Claude (Anthropic) Key", text: $viewModel.claudeKey)
            SecureField("News API Key", text: $viewModel.newsKey)
            SecureField("Reddit Client ID", text: $viewModel.redditClientID)
            SecureField("Reddit Client Secret", text: $viewModel.redditClientSecret)
        } header: {
            Text("API Keys")
        } footer: {
            Text("Keys are stored in the system Keychain and never leave your device.")
                .font(.caption)
        }
    }

    private var preferencesSection: some View {
        Section("Preferences") {
            Picker("Risk Tolerance", selection: $viewModel.riskTolerance) {
                ForEach(RiskTolerance.allCases) { level in
                    Text(level.displayName).tag(level)
                }
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: appVersion)
            LabeledContent("Build", value: buildNumber)
            if let privacyURL = URL(string: "https://tradepilot.app/privacy") {
                Link("Privacy Policy", destination: privacyURL)
            }
            if let termsURL = URL(string: "https://tradepilot.app/terms") {
                Link("Terms of Use", destination: termsURL)
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
