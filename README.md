# OpenMagnet

A free, 212-line Swift clone of [Magnet](https://magnet.crowdcafe.com). Menu-bar window snapper for macOS — keyboard shortcuts to move and resize the focused window into halves, quarters, thirds, or maximize.

No package manager, no Xcode project, no App Store. One Swift file, one build script, `open .app` and you're done.

## Why

Magnet is $10 on the App Store. Rectangle is great but brings a broader surface. This is the smallest thing that could possibly work: the keyboard layer, plus AppleScript for the actual window moves (so you grant *Automation* permission instead of *Accessibility*, which tends to behave more reliably on modern macOS).

## Shortcuts

All shortcuts are **Ctrl + Option + …**

| Key | Action |
|---|---|
| `←` `→` | Left / Right half |
| `↑` `↓` | Top / Bottom half |
| `⏎` | Maximize |
| `C` | Center (2/3 of screen) |
| `U` `I` `J` `K` | Quarters — TL / TR / BL / BR |
| `D` `F` `G` | Thirds — Left / Center / Right |

All 13 also live in the menu bar drop-down with their shortcuts shown alongside.

## Build

```bash
./build.sh
open build/OpenMagnet.app
```

Requires Xcode Command Line Tools (`xcode-select --install`) for `swiftc`. No other dependencies.

On first use, macOS will ask for **Automation** permission — click Allow. The app lives in your menu bar (look for the `rectangle.split.2x1` icon) and has no Dock presence (`LSUIElement = true`).

## How it works

- **Hotkeys** — Carbon `RegisterEventHotKey` (yes, Carbon still works in 2026 for this).
- **Window moves** — build an AppleScript on the fly that sets `bounds of front window` on whichever app is frontmost.
- **Coordinate math** — convert from NSScreen's bottom-left origin to AppleScript's top-left origin; subtract the menu bar via `visibleFrame`.

## License

MIT
