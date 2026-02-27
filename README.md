[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

# DevWispr

A macOS menu-bar dictation app that transcribes speech to text using the OpenAI Whisper API and inserts it into the active application. Apple Silicon only.

## Features

- Hold-to-talk (`Control`) and toggle (`Control + Space`) recording modes
- Floating indicator panel with live audio waveform
- Automatic text insertion into the active app via Accessibility
- Output language selection with optional translation
- Transcription history with search and pagination

## Requirements

- macOS 26.0+
- Apple Silicon (arm64)
- OpenAI API key (or compatible proxy)

## Setup

### 1. API Key

Click the menu bar icon and set your API key in the popover. It is stored securely in the macOS Keychain, encrypted at rest and scoped to the app's sandbox. The key is only sent to the configured API endpoint over HTTPS and is never transmitted elsewhere. You can change or remove a saved key at any time from the popover's API Key settings.

### 2. Permissions

The app will request on launch:
- **Microphone** — required for recording
- **Accessibility** — required for text insertion (paste into active app)

### 3. Custom API Environment

DevWispr supports OpenAI-compatible proxies. You can configure a custom API endpoint using a deeplink or an environment variable.

#### Deeplink

Open a URL with the `devwispr://` scheme to configure the endpoint:

```
devwispr://configure?baseURL=<url>&apiKeyURL=<url>
```

| Parameter   | Required | Description |
|-------------|----------|-------------|
| `baseURL`   | Yes      | Base URL of the OpenAI-compatible API (e.g. `https://proxy.example.com/v1`) |
| `apiKeyURL` | No       | URL where the user can obtain an API key |

A confirmation dialog is shown before any changes are applied. Accepting switches the provider to **Custom** and stores the URLs.

**Examples:**

```bash
# Base URL only
open "devwispr://configure?baseURL=https://proxy.example.com/v1"

# Base URL + API key URL
open "devwispr://configure?baseURL=https://proxy.example.com/v1&apiKeyURL=https://proxy.example.com/keys"
```

To switch back to the default OpenAI endpoint, select **OpenAI** in the provider picker inside the popover.

---

## Development

### Open in Xcode

Open `DevWispr.xcodeproj` in Xcode 16+.

### Run Tests

```bash
xcodebuild test \
  -project "DevWispr.xcodeproj" \
  -scheme "DevWispr" \
  -destination "platform=macOS"
```

---

## Security

If you discover a security vulnerability, please report it responsibly via [GitHub private vulnerability reporting](https://github.com/fredy-mederos/devwispr/security/advisories/new). Do **not** open a public issue for security vulnerabilities.

## License

MIT — see [LICENSE](LICENSE).
