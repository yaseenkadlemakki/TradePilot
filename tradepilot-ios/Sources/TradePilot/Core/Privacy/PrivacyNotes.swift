// MARK: - PrivacyInfo.xcprivacy — Setup Instructions
//
// Xcode 15+ requires a PrivacyInfo.xcprivacy manifest for App Store submission when
// the app (or any SDK it links) uses privacy-sensitive APIs.
//
// TradePilot required entries:
//
//   NSPrivacyAccessedAPITypes:
//     - NSPrivacyAccessedAPIType: NSPrivacyAccessedAPICategoryUserDefaults
//       NSPrivacyAccessedAPITypeReasons: [CA92.1]    (app-owned user defaults)
//
//   NSPrivacyCollectedDataTypes:
//     - NSPrivacyCollectedDataType: NSPrivacyCollectedDataTypeOtherFinancialInfo
//       NSPrivacyCollectedDataTypeLinked: false
//       NSPrivacyCollectedDataTypeTracking: false
//       NSPrivacyCollectedDataTypePurposes: [NSPrivacyCollectedDataTypePurposeAppFunctionality]
//
// How to create:
//   1. In Xcode: File ▸ New ▸ File ▸ "App Privacy" template
//   2. Place the resulting PrivacyInfo.xcprivacy in tradepilot-ios/
//   3. Add it to the Xcode target (it is *not* picked up by SPM automatically)
//
// API keys are stored exclusively in the iOS Keychain (SecItemAdd / SecItemCopyMatching).
// No keys or financial data are transmitted to Anthropic or any analytics service.

enum PrivacyInfo {
    // Namespace — no runtime behaviour; see the file-level comment for setup steps.
}
