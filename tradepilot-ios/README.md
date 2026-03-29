# TradePilot iOS

SPM-based iOS 17+ app — 5-agent options pipeline, SwiftUI interface, and full CI/CD.

![CI](https://github.com/yaseenkadlemakki/TradePilot/actions/workflows/ci-ios.yml/badge.svg)

## Structure

```
Sources/TradePilot/
├── App/            SwiftUI @main entry point
├── Core/
│   ├── Models/         Codable data models (mirrors Python schemas)
│   ├── Networking/     APIClient (NWPathMonitor offline detection) + 4 service clients
│   ├── Auth/           KeychainManager (BYO API keys, never stored in plaintext)
│   ├── Storage/        SwiftData LocalCache
│   ├── Pipeline/       5-agent pipeline (DataAggregator → SentimentScorer → QuantStrategy → RiskCompliance → ExpertAdvisor)
│   ├── Accessibility/  VoiceOver + Dynamic Type view modifiers
│   └── Privacy/        PrivacyInfo.xcprivacy setup notes
├── Features/
│   ├── Dashboard/      Main trade recommendations view
│   ├── TradeDetail/    Per-trade analysis
│   ├── History/        Past recommendations
│   ├── Settings/       API key management
│   └── Onboarding/     First-launch key setup flow
├── Navigation/     AppCoordinator + MainTabView
├── Resources/      Assets.xcassets (AccentColor, AppIcon placeholder)
└── Shared/         ConfidenceIndicator, SkeletonView, StrategyBadge
Tests/TradePilotTests/
    Unit: ModelTests, KeychainTests, PipelineTests, QuantStrategyTests,
          RiskComplianceTests, APIClientTests, DashboardViewModelTests,
          HistoryViewModelTests, SettingsViewModelTests, OnboardingTests
    Integration: FullPipelineIntegrationTest
```

## Build

```bash
cd tradepilot-ios
swift build     # compiles all Sources
swift test      # runs all unit + integration tests
```

Requires Swift 5.9+ / Xcode 15+.

## Xcode Project Setup

TradePilot uses Swift Package Manager — no `.xcodeproj` is checked in.

1. **Open in Xcode:**  `File ▸ Open` → select the `tradepilot-ios/` folder (Xcode detects `Package.swift`).
2. **Scheme:** Select the `TradePilot` scheme and an iOS 17 simulator.
3. **Run:** `Cmd+R`.

> **AppIcon / LaunchScreen:** Replace the AppIcon placeholder in `Sources/TradePilot/Resources/Assets.xcassets/AppIcon.appiconset/` with your 1024×1024 PNG.  Add a LaunchScreen storyboard to the Xcode target (not tracked by SPM).

> **PrivacyInfo.xcprivacy:** Required for App Store submission. See `Sources/TradePilot/Core/Privacy/PrivacyNotes.swift` for the required entries and creation steps.

## API Keys (BYO)

All keys are stored in the iOS Keychain after first launch via the Onboarding screen.  **Never** commit keys to source control.

| Service | Where to get it | Used for |
|---|---|---|
| [Polygon.io](https://polygon.io) | polygon.io/dashboard | OHLCV price data, RSI |
| [Unusual Whales](https://unusualwhales.com) | unusualwhales.com/api | Options flow data |
| [Reddit (OAuth2)](https://www.reddit.com/prefs/apps) | reddit.com/prefs/apps → "script" app | WSB sentiment |
| [News API](https://newsapi.org) | newsapi.org/register | Financial news sentiment |

Free tiers are sufficient for personal use. Polygon's free tier covers delayed data.

## CI

GitHub Actions runs on every push / PR touching `tradepilot-ios/`:

| Job | Runner | What it does |
|---|---|---|
| `build-and-test` | macos-15 / Xcode 16 | `swift build` + `swift test` |
| `lint` | macos-15 | SwiftLint `--strict` |

Workflow: `.github/workflows/ci-ios.yml`

## TestFlight

1. **Xcode project required** — generate one via `File ▸ New ▸ Project` or use `xcodegen` with a `project.yml`.
2. **Bundle ID:** Set to your Apple Developer team's bundle ID (e.g. `com.yourname.tradepilot`).
3. **Signing:** Automatic signing with your team's provisioning profile.
4. **Archive:** `Product ▸ Archive` → Distribute App → App Store Connect → TestFlight.
5. **API keys are NOT bundled** — testers set their own keys on first launch via the Onboarding screen.

### Automated TestFlight (optional)

Add the following secrets to your GitHub repository and uncomment the `testflight` job in `ci-ios.yml`:

```
APP_STORE_CONNECT_API_KEY_ID
APP_STORE_CONNECT_ISSUER_ID
APP_STORE_CONNECT_API_KEY_BASE64
MATCH_GIT_BASIC_AUTHORIZATION   # if using fastlane match
```

## Screenshots

| Dashboard | Trade Detail | History | Settings |
|---|---|---|---|
| *(add screenshot)* | *(add screenshot)* | *(add screenshot)* | *(add screenshot)* |

## Accessibility

All interactive views use `AccessibilityModifiers.swift`:
- `voiceOverLabel(_:hint:)` — VoiceOver labels on every card and button
- `cappedDynamicType(_:)` — prevents layout breaks at largest accessibility text sizes
- `accessibilityTrait(_:)` — semantic traits (`.isButton`, `.isHeader`)
