# LosNotches QA checklist

Results recorded 2026-10-14 on MacBook Pro (M5 Pro, 14", macOS 26.5.1), single built-in display.
Legend: ✅ verified · ⚠️ verified with caveat · ⏳ not verifiable here (needs hardware/permission/user input).

Verification method: screenshots driven by a DEBUG-only distributed-notification hook
(`dev.losnotches.debug`), because posting synthetic mouse events needs Accessibility for the tooling.

## Window & interaction
- ✅ Black shape exactly over the notch; panel stays at its computed frame across all states
- ✅ Open Nook (792×190) with widget grid, top bar (lock, settings)
- ✅ Activity wings (media, HUD, timer, calendar, bluetooth) and Quick Peek strip
- ✅ Drop targets (Tray / AirDrop) view; onboarding with permission checklist
- ⏳ Real hover / click / swipe / right-click (needs a human; logic covered by NotchReducer + accumulator tests)
- ⏳ External display hot-plug, clamshell (no second display here; ScreenDiff tests cover the diffing)

## Spaces & appearance (2026-10-15)
- ⏳ Three-finger Space swipe: island stays put, no second island (fix: private notch space; needs a human swipe to confirm)
- ⏳ Fullscreen-app swipe, sleep/wake, second display: island stays in the notch space
- ✅ Context menu popped over the open Nook draws above the island (not hidden under it)
- ✅ Appearance: island border, larger open radius, orange widget cards applied live; border not drawn along the screen edge
- ✅ Translucent blurred Nook, Nook/Tray tabs, circle + spectrograph effects render
- ⏳ Quick Look thumbnails, browser image/link drops, calendar event click-through, peek controls (need real input)

## Media
- ✅ Adapter returns live Now Playing (Chrome/YouTube) and the media activity rendered with artwork + waves
- ✅ Adapter killed → restarted automatically (new pid within 3 s)
- ✅ Quit (SIGTERM) → adapter child is killed; crash (SIGKILL) → orphan cleared at next launch
- ⏳ Play/pause/next/scrub against Spotify/Music (needs user media session)

## HUD
- ✅ Core logic (decode, steps, OSD suppression ordering, activation policy) unit-tested
- ⏳ Real key interception (needs Accessibility grant by the user)

## Widgets
- ✅ Timers wheel centres on the selected value; presets; Tray empty state; Notes empty state; Quick Apps empty state
- ✅ Calendar permission-needed state
- ⏳ Mirror (not exercised to avoid turning on the camera without the user)

## Performance
- ✅ Idle CPU 0.0% (6 samples × 5 s, release build, Nook closed, nothing playing); RSS 42 MB
- ✅ Perl adapter idle CPU 0.0%

## Robustness
- ✅ Launch never blocks on the Bluetooth permission prompt (IOBluetooth only after CoreBluetooth reports access)
- ✅ 153 unit tests pass (`scripts/test.sh`)
