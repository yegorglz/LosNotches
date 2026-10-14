# LosNotches

A free, local, open notch utility for macOS: turns the MacBook notch (or a slim handle on notch-less
displays) into a Dynamic-Island-style surface. No accounts, no licence server, no network calls.

**Features:** media controls for any Now Playing app (Music, Spotify, browsers…) with scrubber and
source switching · live activities (media, volume/brightness HUD, battery, Bluetooth, calendar,
timers, tray) with Quick Peek · calendar with Zoom/Meet/Teams/Webex join buttons · notes (rich text +
code mode) · to-dos (stars, auto-archive) · timers (wheels, haptics, survive restarts) · file Tray +
AirDrop drop targets · camera Mirror · Shortcuts · Quick Apps · fullscreen detection · multi-display.

Requires macOS 14.6+, Apple silicon or Intel.

## Permissions

| Permission | Used for |
|---|---|
| Accessibility | Volume & brightness HUD replacement (intercepts the media keys). Optional, off by default. |
| Automation | Reading and controlling Music / Spotify while they run (lets you switch sources). Asked the first time either app is open. |
| Calendar | Calendar widget and calendar live activity. |
| Camera | Mirror widget only; the camera runs only while the Mirror is on screen. |
| Bluetooth | Connect / disconnect live activity. |

No Screen Recording, Full Disk Access or Input Monitoring is needed. The app is not sandboxed: it runs
`/usr/bin/perl` with the bundled mediaremote-adapter (the only way to read Now Playing on macOS 15.4+)
and freezes/thaws `OSDUIHelper` for the HUD replacement (always restored on quit, and at next launch
after a crash).

## Build, test, run

Works with the Command Line Tools alone (no Xcode needed).

```bash
scripts/test.sh                 # unit tests (NookCore)
scripts/run.sh                  # debug build + launch
scripts/build-app.sh release    # universal build/LosNotches.app + build/LosNotches-<version>.zip
```

### Signing

Builds are signed ad-hoc by default. macOS ties permission grants to the signature, so **every
rebuild resets Accessibility/Bluetooth/Camera grants**. For stable grants, create a self-signed
code-signing certificate named "LosNotches Dev" (Keychain Access → Certificate Assistant → Create a
Certificate → Code Signing) and build with:

```bash
LOSNOTCHES_SIGN_ID="LosNotches Dev" scripts/build-app.sh release
```

## Using it

Hover the notch, click (or two-finger swipe down) to open the Nook. Swipe up to close; swipe up on a
closed notch to hide it, down to bring it back. Swipe up on a live activity to dismiss it. Drag files
onto the notch for the Tray / AirDrop targets (⌥ moves instead of referencing). Right-click for
Settings. Horizontal swipes skip tracks.

## Data and uninstall

Data lives in `~/Library/Application Support/LosNotches/` (notes, to-dos, timers, tray). To remove
everything:

```bash
rm -rf ~/Library/Application\ Support/LosNotches
```

```bash
defaults delete dev.losnotches.LosNotches
```

```bash
tccutil reset All dev.losnotches.LosNotches
```

## Layout

- `Sources/NookCore` — all decision logic (geometry, state reducer, activity arbitration, decoders,
  stores, policies). Foundation/CoreGraphics only, fully unit-tested.
- `Sources/LosNotches` — AppKit/SwiftUI app and system adapters.
- `Vendor/mediaremote-adapter` — pinned upstream (see `VERSION`), built by `scripts/build-adapter.sh`.

## Credits

Now Playing via [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) © Jonas van den
Berg and contributors, BSD-3-Clause (`Vendor/mediaremote-adapter/LICENSE`).
