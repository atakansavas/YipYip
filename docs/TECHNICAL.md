# YipYip — technical notes

[![CI](https://github.com/atakansavas/YipYip/actions/workflows/ci.yml/badge.svg)](https://github.com/atakansavas/YipYip/actions/workflows/ci.yml)

Reference for people reading or changing the code. For what the app is and how
to install it, start at the [README](../README.md).

A local-first clipboard manager for macOS. Everything you copy stays on your Mac —
encrypted, searchable, and one keystroke away.

<!-- Screenshot: add docs/search-panel.png and reference it here -->

**Requirements:** macOS 14+, Swift 6 (`xcode-select --install`).

## Install

```bash
git clone https://github.com/atakansavas/YipYip.git
cd YipYip
./Scripts/build-app.sh
open /Applications/YipYip.app
```

The script builds a release binary, assembles `YipYip.app`, signs it with a code
signing identity if one is available, and installs it to `/Applications`.

Then press `⌘⌥V` and start copying.

## Permissions

macOS asks for two things, both just in time:

| Permission    | Why                                                                                                                  |
|---------------|----------------------------------------------------------------------------------------------------------------------|
| Keychain      | Stores the AES-256 key that encrypts your history. Choose **Always Allow** — the app waits on this dialog at launch.  |
| Accessibility | Lets YipYip paste into the app you were using. Without it the clip is still copied and you press ⌘V yourself.        |

If auto-paste stops working after rebuilding, the grant went stale because the
code signature changed. Clear it and approve once more:

```bash
tccutil reset Accessibility com.benatakan.yipyip
```

Nothing else is requested — no contacts, location, camera, or microphone.

## Features

- **Encrypted history** — every clip is AES-256-GCM encrypted with a key kept in the macOS Keychain.
- **Instant search** — `⌘⌥V` from anywhere. Arrow keys navigate, Enter pastes into the app you came from, Escape closes.
- **Diacritic-insensitive search** — `insallah` finds `inşallah`, `istanbul` finds `İSTANBUL`, `gunes` finds `güneş`, and the reverse.
- **Images and files** — images are stored as PNG and shown as thumbnails; files (including videos) are stored as references with their Finder icon, so a 4 GB video costs a few bytes. Pasting restores the original form, not a text stand-in.
- **Pinboards** — pin the clips you keep reaching for into named collections.
- **No duplicates, no burying** — re-copying something already in history moves it back to the top instead of adding a second row.
- **Sound cues** — soft synthesised tones on capture and paste, each switchable.
- **Auto-expiration** — clips expire after a configurable number of days (default: 30).
- **Skips secrets** — clips a password manager marks as concealed (or transient) are not recorded. Switchable in Settings.
- **Export** — history metadata and settings as JSON, from the menu bar or Settings.

## Keyboard Shortcuts

| Key       | Action                   |
|-----------|--------------------------|
| `⌘⌥V`     | Toggle the search window (configurable) |
| `↑` / `↓` | Navigate items           |
| `↩`       | Paste selected at cursor |
| `⌘P`      | Pin selected item        |
| `⌘⌫`      | Delete selected item     |
| `Tab`     | Switch All / Pinned      |
| `Esc`     | Close                    |

`⌘⌥V` shadows Finder's "Move Item Here" while YipYip runs. Settings ▸ Shortcut
records a different combination — click the field and press one.

## Privacy

YipYip is offline by default:

- Clipboard content never leaves your Mac. No account, no sync, no telemetry.
- History lives in `~/Library/Application Support/YipYip/yipyip.db`, encrypted with a Keychain-held key.
- The **only** network request the app can make is the opt-in update check, which asks the GitHub Releases API for a version number. It is off unless you enable it.
- Export writes metadata only — previews and timestamps, never encrypted contents.

Worth knowing: previews are stored unencrypted so search can work, so treat the
history file as sensitive and use **Clear All History** when you need to. Clips
an app marks as concealed (the `org.nspasteboard.ConcealedType` convention most
password managers follow) are skipped, but an app that does not set the marker
will still be recorded.

## Data Location

| What           | Where                                                            |
|----------------|------------------------------------------------------------------|
| History        | `~/Library/Application Support/YipYip/yipyip.db`                  |
| Settings       | `~/Library/Application Support/YipYip/settings.json`              |
| Encryption key | macOS Keychain, service `com.benatakan.yipyip.encryption-key`     |

## Architecture

```
Sources/
├── YipYip/                  # App layer (SwiftUI + AppKit)
│   ├── App.swift            # Entry point, status item, menu, search panel
│   ├── AppState.swift       # Observable state bridging core → UI
│   ├── HotkeyManager.swift  # Global ⌘⌥V via the Carbon API
│   ├── PasteHelper.swift    # Refocuses the previous app and sends ⌘V
│   ├── SoundPlayer.swift    # Plays the synthesised cues
│   ├── StatusItemIcon.swift # Hand-drawn menu bar glyph
│   └── Views/               # Search panel, rows, settings, pinboard sheet
└── YipYipCore/              # Business logic library (no UI imports)
    ├── Audio/               # Cue synthesis
    ├── Clipboard/           # Pasteboard capture and restore
    ├── Database/            # SQLite storage
    ├── Export/              # JSON export and diagnostics
    ├── Pinboard/            # Named pinboard helpers
    ├── Search/              # Diacritic folding
    ├── Security/            # AES-256-GCM and Keychain
    ├── Settings/            # Preferences
    └── Update/              # Opt-in release check
```

No third-party dependencies — only system frameworks: `AppKit`, `SwiftUI`,
`CryptoKit`, `Security`, `SQLite3`, `Carbon`, `AVFoundation`, `ServiceManagement`.

Keeping the core free of UI imports is what makes it testable: the suite covers
capture classification, encryption, storage, search folding, settings migration,
tone synthesis, and the update check, with no app running.

## Development

```bash
swift build                                  # debug build
swift test                                   # run the suite
./Scripts/build-app.sh                       # release build, bundle, sign, install
swift Scripts/generate-icon.swift Resources  # regenerate the app icon
./Scripts/capture-screenshot.sh              # capture the README screenshot
```

The version has a single source of truth: `fallbackVersion` in
`Sources/YipYipCore/AppInfo.swift`, which `Scripts/build-app.sh` reads to stamp
the bundle.

## Not planned

Cloud sync, accounts, telemetry, an extension marketplace, script execution.
YipYip is meant to stay a small local tool.

## Uninstall

```bash
killall YipYip
rm -rf /Applications/YipYip.app
rm -rf ~/Library/Application\ Support/YipYip
security delete-generic-password -s com.benatakan.yipyip.encryption-key
```

## Contributing

Issues and pull requests are welcome — see [CONTRIBUTING.md](../CONTRIBUTING.md).
For anything security-related, read [SECURITY.md](../SECURITY.md) first.

## License

[MIT](../LICENSE) © Atakan Savaş
