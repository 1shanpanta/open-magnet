import Cocoa
import Carbon
import ApplicationServices

// ── OpenMagnet: a minimal Magnet clone ──────────────────────────────────
// Menu bar app. Global hotkeys move/resize the focused window.
// Uses the macOS Accessibility API (AXUIElement) for window manipulation.
//
// Shortcuts (Ctrl + Option + ...):
//   Left/Right  → halves
//   Up/Down     → top/bottom half
//   Return      → maximize
//   C           → center
//   U/I/J/K     → quarters
//   D/F/G       → thirds

// ── openMagnet positions ───────────────────────────────────────────────
enum OpenMagnetPosition: String, CaseIterable {
    case leftHalf = "Left Half"
    case rightHalf = "Right Half"
    case topHalf = "Top Half"
    case bottomHalf = "Bottom Half"
    case maximize = "Maximize"
    case center = "Center"
    case topLeft = "Top Left"
    case topRight = "Top Right"
    case bottomLeft = "Bottom Left"
    case bottomRight = "Bottom Right"
    case leftThird = "Left Third"
    case centerThird = "Center Third"
    case rightThird = "Right Third"
}

// Returns the screen the user is currently looking at — the one containing
// the mouse cursor. Handles multi-monitor setups where NSScreen.main would
// otherwise snap to the wrong display.
func currentScreen() -> NSScreen? {
    let mouse = NSEvent.mouseLocation
    return NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main ?? NSScreen.screens.first
}

// Reads a boolean Accessibility attribute, defaulting to false when it is
// absent or unreadable.
func axBool(_ element: AXUIElement, _ attribute: String) -> Bool {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success
        && (value as? Bool == true)
}

// ── window manipulation via Accessibility API ────────────────────
func openMagnetWindow(to pos: OpenMagnetPosition) {
    guard let screen = currentScreen() else {
        NSLog("OpenMagnet: no active display, ignoring snap")
        return
    }
    let v = screen.visibleFrame
    // AX uses top-left origin of the primary display, same as AppleScript did.
    // For correct Y-flip on secondary monitors, subtract from the primary's height.
    let primaryH = (NSScreen.screens.first { $0.frame.origin == .zero } ?? screen).frame.height

    // convert from NSScreen coords (origin bottom-left) to screen coords (origin top-left)
    let sx = Int(v.origin.x)
    let sy = Int(primaryH - v.origin.y - v.height)
    let sw = Int(v.width)
    let sh = Int(v.height)

    var x = sx, y = sy, w = sw, h = sh

    // Width/height for the right/bottom side is computed as `sw - sw/2` (and
    // similarly for thirds) so the trailing edge always lands exactly on the
    // screen edge when the dimension is odd. Using `sw / 2` on both sides
    // would leave a 1-px gap.
    switch pos {
    case .leftHalf:     w = sw / 2
    case .rightHalf:    x = sx + sw / 2; w = sw - sw / 2
    case .topHalf:      h = sh / 2
    case .bottomHalf:   y = sy + sh / 2; h = sh - sh / 2
    case .maximize:     break
    case .center:
        w = sw * 2 / 3; h = sh * 2 / 3
        x = sx + (sw - w) / 2; y = sy + (sh - h) / 2
    case .topLeft:      w = sw / 2; h = sh / 2
    case .topRight:     x = sx + sw / 2; w = sw - sw / 2; h = sh / 2
    case .bottomLeft:   y = sy + sh / 2; w = sw / 2; h = sh - sh / 2
    case .bottomRight:  x = sx + sw / 2; y = sy + sh / 2; w = sw - sw / 2; h = sh - sh / 2
    case .leftThird:    w = sw / 3
    case .centerThird:  x = sx + sw / 3; w = sw * 2 / 3 - sw / 3
    case .rightThird:   x = sx + sw * 2 / 3; w = sw - sw * 2 / 3
    }

    guard let app = NSWorkspace.shared.frontmostApplication else {
        NSLog("OpenMagnet: no frontmost application")
        NSSound.beep()
        return
    }
    let appElem = AXUIElementCreateApplication(app.processIdentifier)

    var winRef: CFTypeRef?
    guard AXUIElementCopyAttributeValue(appElem, kAXFocusedWindowAttribute as CFString, &winRef) == .success,
          let w0 = winRef else {
        // Most often this means Accessibility permission is not granted.
        NSLog("OpenMagnet: no focused window (grant Accessibility access if snaps do nothing)")
        NSSound.beep()
        return
    }
    let win = w0 as! AXUIElement

    // Apply the geometry, toggling AXEnhancedUserInterface off around the
    // writes. Some apps (Electron, JetBrains, MS Office) set EUI and route
    // window geometry through a non-deterministic codepath that breaks
    // programmatic resize. size → position → size dodges macOS's per-screen
    // size clamp when moving across displays.
    let apply = {
        let euiName = "AXEnhancedUserInterface"
        let hadEUI = axBool(appElem, euiName)
        if hadEUI { AXUIElementSetAttributeValue(appElem, euiName as CFString, kCFBooleanFalse) }
        defer { if hadEUI { AXUIElementSetAttributeValue(appElem, euiName as CFString, kCFBooleanTrue) } }

        var size = CGSize(width: w, height: h)
        var origin = CGPoint(x: x, y: y)
        guard let sizeVal = AXValueCreate(.cgSize, &size),
              let posVal  = AXValueCreate(.cgPoint, &origin) else { return }
        AXUIElementSetAttributeValue(win, kAXSizeAttribute as CFString, sizeVal)
        AXUIElementSetAttributeValue(win, kAXPositionAttribute as CFString, posVal)
        AXUIElementSetAttributeValue(win, kAXSizeAttribute as CFString, sizeVal)
    }

    // A window in native fullscreen lives in its own Space and ignores
    // geometry writes. Take it out of fullscreen first, then apply the frame
    // once the animated transition has settled.
    let fsName = "AXFullScreen"
    if axBool(win, fsName) {
        AXUIElementSetAttributeValue(win, fsName as CFString, kCFBooleanFalse)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: apply)
    } else {
        apply()
    }
}

// ── hotkey registration (Carbon) ─────────────────────────────────
struct HotkeyDef {
    let keyCode: UInt32
    let position: OpenMagnetPosition
}

let hotkeys: [HotkeyDef] = [
    HotkeyDef(keyCode: UInt32(kVK_LeftArrow),  position: .leftHalf),
    HotkeyDef(keyCode: UInt32(kVK_RightArrow), position: .rightHalf),
    HotkeyDef(keyCode: UInt32(kVK_UpArrow),    position: .topHalf),
    HotkeyDef(keyCode: UInt32(kVK_DownArrow),  position: .bottomHalf),
    HotkeyDef(keyCode: UInt32(kVK_Return),     position: .maximize),
    HotkeyDef(keyCode: UInt32(kVK_ANSI_C),     position: .center),
    HotkeyDef(keyCode: UInt32(kVK_ANSI_U),     position: .topLeft),
    HotkeyDef(keyCode: UInt32(kVK_ANSI_I),     position: .topRight),
    HotkeyDef(keyCode: UInt32(kVK_ANSI_J),     position: .bottomLeft),
    HotkeyDef(keyCode: UInt32(kVK_ANSI_K),     position: .bottomRight),
    HotkeyDef(keyCode: UInt32(kVK_ANSI_D),     position: .leftThird),
    HotkeyDef(keyCode: UInt32(kVK_ANSI_F),     position: .centerThird),
    HotkeyDef(keyCode: UInt32(kVK_ANSI_G),     position: .rightThird),
]

func registerHotkeys() {
    var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    InstallEventHandler(GetApplicationEventTarget(), { (_, event, _) -> OSStatus in
        var hkID = EventHotKeyID()
        GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                          nil, MemoryLayout<EventHotKeyID>.size, nil, &hkID)
        let idx = Int(hkID.id)
        if idx >= 0 && idx < hotkeys.count {
            DispatchQueue.main.async { openMagnetWindow(to: hotkeys[idx].position) }
        }
        return noErr
    }, 1, &eventType, nil, nil)

    let modifiers: UInt32 = UInt32(controlKey | optionKey)

    var failed = 0
    for (i, hk) in hotkeys.enumerated() {
        let hkID = EventHotKeyID(signature: OSType(0x4F504D47), id: UInt32(i))
        var hkRef: EventHotKeyRef?
        let status = RegisterEventHotKey(hk.keyCode, modifiers, hkID, GetApplicationEventTarget(), 0, &hkRef)
        if status != noErr || hkRef == nil {
            failed += 1
            NSLog("OpenMagnet: could not bind the hotkey for \(hk.position.rawValue) (OSStatus \(status)); another app may already own it. Use the menu instead.")
        }
    }
    if failed > 0 {
        NSLog("OpenMagnet: \(hotkeys.count - failed)/\(hotkeys.count) hotkeys registered")
    }
}

// ── app delegate ─────────────────────────────────────────────────
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // menu bar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let btn = statusItem.button {
            btn.image = NSImage(systemSymbolName: "rectangle.split.2x1", accessibilityDescription: "OpenMagnet")
            btn.image?.isTemplate = true
        }

        buildMenu()
        // Trigger the Accessibility prompt before hotkeys go live so the user's
        // first Ctrl+Opt+… is not eaten by the consent dialog. Without an AX
        // grant every AXUIElementSetAttributeValue below silently no-ops.
        ensureAccessibility()
        registerHotkeys()

        NSLog("OpenMagnet: running, hotkeys registered")
    }

    func ensureAccessibility() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
    }

    func buildMenu() {
        let menu = NSMenu()

        let titleItem = NSMenuItem(title: "OpenMagnet", action: nil, keyEquivalent: "")
        titleItem.attributedTitle = NSAttributedString(string: "OpenMagnet", attributes: [
            .font: NSFont.boldSystemFont(ofSize: 13),
        ])
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())

        let items: [(String, String, OpenMagnetPosition)] = [
            ("Left Half",     "Ctrl+Opt+\u{2190}", .leftHalf),
            ("Right Half",    "Ctrl+Opt+\u{2192}", .rightHalf),
            ("Top Half",      "Ctrl+Opt+\u{2191}", .topHalf),
            ("Bottom Half",   "Ctrl+Opt+\u{2193}", .bottomHalf),
            ("Maximize",      "Ctrl+Opt+\u{21A9}", .maximize),
            ("Center",        "Ctrl+Opt+C",        .center),
            ("Top Left",      "Ctrl+Opt+U",        .topLeft),
            ("Top Right",     "Ctrl+Opt+I",        .topRight),
            ("Bottom Left",   "Ctrl+Opt+J",        .bottomLeft),
            ("Bottom Right",  "Ctrl+Opt+K",        .bottomRight),
            ("Left Third",    "Ctrl+Opt+D",        .leftThird),
            ("Center Third",  "Ctrl+Opt+F",        .centerThird),
            ("Right Third",   "Ctrl+Opt+G",        .rightThird),
        ]

        for (name, shortcut, pos) in items {
            let item = NSMenuItem(title: name, action: #selector(menuOpenMagnet(_:)), keyEquivalent: "")
            item.target = self
            item.tag = OpenMagnetPosition.allCases.firstIndex(of: pos)!

            let attrTitle = NSMutableAttributedString(string: "\(name)  ", attributes: [
                .font: NSFont.systemFont(ofSize: 13),
            ])
            attrTitle.append(NSAttributedString(string: shortcut, attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]))
            item.attributedTitle = attrTitle
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())
        let axItem = NSMenuItem(title: "Open Accessibility Settings…", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        axItem.target = self
        menu.addItem(axItem)
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    @objc func menuOpenMagnet(_ sender: NSMenuItem) {
        let pos = OpenMagnetPosition.allCases[sender.tag]
        // delay so menu closes and previous app regains focus
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            openMagnetWindow(to: pos)
        }
    }

    @objc func openAccessibilitySettings() {
        // Deep-link straight to the Accessibility pane so a user whose snaps
        // do nothing can grant permission without hunting through Settings.
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

// ── main ─────────────────────────────────────────────────────────
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
