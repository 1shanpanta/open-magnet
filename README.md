# OpenMagnet

A tiny, free, single-file Swift window snapper for macOS. Keyboard shortcuts move and resize the focused window into halves, quarters, thirds, center, or maximize. The whole app is one ~250-line file with zero dependencies beyond the system frameworks.

## Honest positioning (read this first)

If you just want the best free window manager, you have two strong options already, and OpenMagnet is probably not it:

- **macOS 15 Sequoia ships tiling built in.** Hover the green traffic-light button, or use `Fn`+`Control`+arrows. It does halves, quarters, fill, and center. The catches: no thirds, the hover menu has a noticeable lag before it appears, and it needs macOS 15 or later.
- **[Rectangle](https://github.com/rxhanson/Rectangle) is free, open source, and far more capable.** Thirds, sixths, ninths, move-to-display, custom shortcuts, drag-to-snap areas, config import/export. For most people, the right answer is "install Rectangle."

OpenMagnet is not trying to beat either of them on features. It exists to be the smallest thing that works: one readable Swift file you can audit in five minutes, no package manager, no Xcode project, no auto-updater, no telemetry, and nothing phoning home. Build it, read it, change it, own it. It uses the same macOS Accessibility API that Rectangle, Magnet, yabai, and Spectacle use for the actual window moves, so it works on Terminal, Electron, JetBrains apps, and anything else that exposes a normal accessibility tree.

(For price reference: Magnet on the App Store is $4.99; Rectangle is free.)

## Shortcuts

All shortcuts are **Ctrl + Option + …**

| Key | Action |
|---|---|
| `←` `→` | Left / Right half |
| `↑` `↓` | Top / Bottom half |
| `⏎` | Maximize |
| `C` | Center (2/3 of screen) |
| `U` `I` `J` `K` | Quarters: TL / TR / BL / BR |
| `D` `F` `G` | Thirds: Left / Center / Right |

All 13 also live in the menu-bar drop-down with their shortcuts shown alongside. They sit under `Ctrl`+`Option`, so they do not collide with macOS Sequoia's native tiling shortcuts (which use `Fn`+`Control`).

## Install

Two ways to get it:

1. **Download** the latest `OpenMagnet.zip` from [Releases](https://github.com/1shanpanta/open-magnet/releases), unzip, and drag `OpenMagnet.app` into `/Applications`. The build is ad-hoc signed (not notarized), so on first launch macOS will block it: right-click the app, choose **Open**, then confirm. (Or clear the quarantine flag once: `xattr -dr com.apple.quarantine /Applications/OpenMagnet.app`.)
2. **Build from source** (below). Building locally produces no Gatekeeper prompt.

## Build

```bash
./build.sh
open build/OpenMagnet.app
```

`build.sh` compiles the single file with `swiftc`, bundles it into `OpenMagnet.app`, ad-hoc signs it, and also installs a copy to `~/Applications`. Requires Xcode Command Line Tools (`xcode-select --install`); no other dependencies.

By default the app is ad-hoc signed, so it builds on any Mac with no Apple Developer account. If you have a signing identity and want macOS to remember the Accessibility grant across rebuilds, export it first:

```bash
SIGNING_IDENTITY="Apple Development: Your Name (TEAMID)" ./build.sh
```

On first launch, macOS asks for **Accessibility** permission: click Allow (System Settings > Privacy & Security > Accessibility). The app lives in your menu bar (the split-rectangle icon) and has no Dock presence (`LSUIElement = true`).

## How it works

- **Hotkeys:** Carbon `RegisterEventHotKey`, still the de-facto API for global hotkeys on macOS.
- **Window moves:** `AXUIElementCreateApplication(pid)`, then `kAXFocusedWindowAttribute`, then set `kAXSizeAttribute`, `kAXPositionAttribute`, and `kAXSizeAttribute` again. The size-position-size dance dodges macOS's per-screen size clamp, and toggling `AXEnhancedUserInterface` around the calls fixes Electron, JetBrains, and MS Office windows.
- **Coordinate math:** convert from NSScreen's bottom-left origin to the Accessibility API's top-left origin, and subtract the menu bar via `visibleFrame`.

## Known limitations

- **Native fullscreen windows are not moved.** A window in macOS native fullscreen lives in its own Space and ignores programmatic resize. Take it out of fullscreen first, then snap it.
- **Shortcuts are fixed** at `Ctrl`+`Option`+… and are not configurable in-app.
- **No move-to-other-display command.**
- **Snaps target the display under the mouse cursor**, which on a multi-monitor setup can differ from the display the focused window is on.

## Requirements

macOS 11 (Big Sur) or later. Xcode Command Line Tools for `swiftc`.

## License

MIT
