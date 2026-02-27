# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

macOS menu-bar dictation app. Hold or toggle a hotkey to record speech; the app transcribes via OpenAI Whisper, optionally translates, and inserts the text into the active application. Apple Silicon only.

- **Platform:** macOS 26.0+, arm64
- **Language:** Swift + SwiftUI / AppKit
- **Dependencies:** HotKey (Swift Package) for global toggle shortcuts

---

## Architecture

Clean layered architecture. Inner layers have no knowledge of outer ones.

```
Domain/          — Protocols, Entities, Errors, UseCases (no platform imports)
App/             — AppContainer (DI), AppState (central state), RecordingCoordinator
System/          — Platform implementations (Audio, Hotkeys, OpenAI, Settings, …)
Presentation/    — SwiftUI views + view models
```

### Key files

| File | Role |
|------|------|
| `Domain/Protocols/Protocols.swift` | All 14 service contracts in one file |
| `App/AppContainer.swift` | DI container; all params optional (nil = production default) |
| `App/AppState.swift` | `@MainActor ObservableObject`; single source of truth for UI state |
| `App/RecordingCoordinator.swift` | Orchestrates record → transcribe → translate → insert pipeline |
| `App/APIKeyManager.swift` | Keychain-backed API key storage and validation |
| `App/DeepLinkHandler.swift` | Handles `devwispr://configure` deep links |
| `System/Config/AppConfig.swift` | Constants: min recording duration (1000ms), engine idle timeout (15s), URLs |
| `System/Audio/AVAudioRecorderService.swift` | Audio engine with recovery, pre-roll buffering, napping |
| `System/Hotkeys/HotKeyManager.swift` | Global hotkey registration (HotKey lib + NSEvent monitors) |
| `System/Settings/UserDefaultsSettingsStore.swift` | UserDefaults persistence for preferences |
| `System/Settings/KeychainHelper.swift` | Keychain read/write for API keys |
| `Presentation/PopoverContentView.swift` | Main popover UI |

### Bind pattern

`RecordingCoordinator` and `APIKeyManager` don't own `AppState` — they receive a weak reference via `bind(to:)`, called from `AppState.init`. This avoids retain cycles between the coordinator and the state object.

### OpenAI client sharing

`AppContainer` shares a single `OpenAIClient` between transcription and translation services in production. The client uses closure-based configuration (`baseURLProvider`, `apiKeyProvider`) so switching API providers doesn't require recreating services.

---

## Common Commands

### Run all tests
```bash
xcodebuild test \
  -project "DevWispr.xcodeproj" \
  -scheme "DevWispr" \
  -destination "platform=macOS"
```

### Run a specific test file
```bash
xcodebuild test \
  -project "DevWispr.xcodeproj" \
  -scheme "DevWispr" \
  -destination "platform=macOS" \
  -only-testing "DevWisprTests/RecordingCoordinatorTests"
```

### Run tests in a specific locale
```bash
xcodebuild test -project "DevWispr.xcodeproj" -scheme "DevWispr" \
  -destination "platform=macOS" \
  -AppleLanguages '("es")' -AppleLocale es_ES
```

### Release (build → sign → DMG → notarize → staple)
```bash
APP_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
  NOTARY_KEYCHAIN_PROFILE="wispr-notary" bash scripts/release.sh
```

Output artifact: `build/DevWispr.dmg`

Individual steps can be run separately:
```bash
# Build + sign DMG only
APP_SIGN_IDENTITY="..." ./scripts/create_dmg.sh

# Notarize + staple only
NOTARY_KEYCHAIN_PROFILE="wispr-notary" ./scripts/notarize_dmg.sh
```

Store notarization credentials once per machine:
```bash
xcrun notarytool store-credentials "wispr-notary" \
  --apple-id "you@example.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "xxxx-xxxx-xxxx-xxxx"
```

### Verify release artifact
```bash
codesign -dvv "build/DevWispr.dmg"
xcrun stapler validate "build/DevWispr.dmg"
```

---

## Testing

Uses Apple's **Testing** framework (`import Testing`), **not** XCTest.

```swift
@Test("description")
@MainActor
func testFoo() async {
    let (coordinator, appState, mock) = makeSUT()
    #expect(appState.status == .idle)
}
```

### Test helpers

Each test file defines a private `makeSUT()` factory that injects mocks into `AppContainer` and returns the system under test. All mock parameters have defaults, so tests only specify what they need to override.

### Mock conventions

Mocks live in `DevWisprTests/Fakes/`. Pattern:
- `callCount` integers for call verification
- `shouldThrow: Error?` for error simulation
- Configurable return values (e.g., `result: TranscriptionResult?`)

Inject via `AppContainer`'s optional init parameters:

```swift
let container = AppContainer(
    audioRecorder: MockAudioRecorder(),
    transcriptionService: MockTranscriptionService(),
    // …
)
let appState = AppState(container: container)
```

---

## Recording Pipeline

`RecordingCoordinator` manages the full lifecycle:

1. **Start** — Validate API key → check permissions → `audioRecorder.startRecording()` → status = `.recording`
2. **Stop** — Discard if < 1000ms (prevents Whisper hallucination) → `audioRecorder.stopRecording()` → get audio file URL
3. **Transcribe** — `transcriptionService.transcribe(audioFileURL:)` → status = `.transcribing`
4. **Translate** (conditional) — If `autoTranslateToEnglish` and input ≠ English → `translationUseCase.translateIfNeeded(...)` → status = `.translating`
5. **Insert** — If accessibility granted and not clipboard-only → `textInserter.insertText(_:)`, otherwise copy to pasteboard → status = `.inserting`
6. **Persist** — Save `TranscriptItem` to `historyStore` with frontmost app info
7. **Complete** — `appState.lastOutput = finalText`, status = `.idle`

### Mode locking

Hold-to-talk sessions can only be stopped by releasing the modifier key. Toggle sessions can only be stopped by the toggle hotkey. This prevents mode confusion when both are configured.

---

## Audio Engine

`AVAudioRecorderService` handles complex real-world audio scenarios:

- **Engine recovery** — Detects audio route changes (e.g., Bluetooth connect/disconnect) and rebuilds the engine
- **Health check timer** — Detects zombie engines (running but producing no audio) and recreates
- **Pre-roll buffering** — 1-second buffer after engine start so recording begins instantly
- **Engine napping** — Shuts down the engine after 15s idle to release the macOS microphone indicator
- **Retry logic** — Exponential backoff (up to 6 attempts) for engine start failures

---

## Settings & API Keys

`UserDefaultsSettingsStore` stores user preferences. `AppState` reads from it at init and syncs back in `@Published` property `didSet` observers. When the popover opens, `AppState.refreshShortcutsState()` re-reads from the store to pick up any changes.

API keys are stored in the macOS **Keychain** via `KeychainHelper`, not in UserDefaults. `APIKeyManager` handles the read/write/delete lifecycle.

### Custom API providers

`APIProvider` enum: `.openAI` (default) or `.custom`. Custom providers configure a base URL and optional API key URL. The deep link `devwispr://configure?baseURL=<url>&apiKeyURL=<url>` triggers a confirmation dialog, then stores the custom provider settings.

---

## Hotkey System

Two independent modes:

| Mode             | Mechanism                                                          |
| ---------------- | ------------------------------------------------------------------ |
| **Hold-to-talk** | Global `NSEvent` `flagsChanged` monitor; tracks physical key codes |
| **Toggle**       | HotKey library; registered with a `KeyCombo`                       |

`HoldModifierKey` enum has `.control` (key codes 59, 62) and `.option` (58, 61).

When `ShortcutRecorderView` is active, call `hotkeyManager.suspendToggle()` so the toggle hotkey doesn't fire during capture. Resume with `resumeToggle()` when done.

`NSWindow` intercepts `Command+key` via `performKeyEquivalent` before `keyDown`, so `ShortcutRecorderView` overrides `performKeyEquivalent` to capture those combos.

---

## Version Bumping

`MARKETING_VERSION` in `DevWispr.xcodeproj/project.pbxproj` (two entries for the app target). Bump both before running `release.sh`.

---

## Localization

Uses **Xcode String Catalogs** (`Localizable.xcstrings`).

### Supported languages
- English (development language)
- Spanish

### Rules
1. SwiftUI `Text("literal")` — auto-extracted, just add translations in catalog
2. Programmatic strings & error messages — use `String(localized: "key")`
3. Enums with UI display names — add `localizedName` computed property using `String(localized:)`
4. AppKit (NSAlert, NSMenuItem) — always use `String(localized:)`, never hardcoded
5. Keyboard key names — keep in English (match physical keys)

### Adding strings
- New `Text("...")` literals are auto-discovered on build
- New programmatic strings need manual `String(localized:)` and will appear in catalog after build
