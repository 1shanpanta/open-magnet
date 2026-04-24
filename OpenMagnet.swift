import Cocoa
import Carbon

// ── OpenMagnet: a minimal Magnet clone ──────────────────────────────────
// Menu bar app. Global hotkeys move/resize the focused window.
// Uses AppleScript for window manipulation (more reliable permissions).
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

// ── window manipulation via AppleScript ──────────────────────────
func openMagnetWindow(to pos: OpenMagnetPosition) {
    guard let screen = NSScreen.main else { return }
    let v = screen.visibleFrame
    let fullH = screen.frame.height

    // convert from NSScreen coords (origin bottom-left) to screen coords (origin top-left)
    let sx = Int(v.origin.x)
    let sy = Int(fullH - v.origin.y - v.height)
    let sw = Int(v.width)
    let sh = Int(v.height)

    var x = sx, y = sy, w = sw, h = sh

    switch pos {
    case .leftHalf:     w = sw / 2
    case .rightHalf:    x = sx + sw / 2; w = sw / 2
    case .topHalf:      h = sh / 2
    case .bottomHalf:   y = sy + sh / 2; h = sh / 2
    case .maximize:     break
    case .center:
        w = sw * 2 / 3; h = sh * 2 / 3
        x = sx + (sw - w) / 2; y = sy + (sh - h) / 2
    case .topLeft:      w = sw / 2; h = sh / 2
    case .topRight:     x = sx + sw / 2; w = sw / 2; h = sh / 2
    case .bottomLeft:   y = sy + sh / 2; w = sw / 2; h = sh / 2
    case .bottomRight:  x = sx + sw / 2; y = sy + sh / 2; w = sw / 2; h = sh / 2
    case .leftThird:    w = sw / 3
    case .centerThird:  x = sx + sw / 3; w = sw / 3
    case .rightThird:   x = sx + sw * 2 / 3; w = sw / 3
    }

    let script = """
    tell application "System Events"
        set frontApp to name of first application process whose frontmost is true
    end tell
    tell application frontApp
        set bounds of front window to {\(x), \(y), \(x + w), \(y + h)}
    end tell
    """

    var error: NSDictionary?
    if let appleScript = NSAppleScript(source: script) {
        appleScript.executeAndReturnError(&error)
        if let err = error {
            NSLog("OpenMagnet: AppleScript error: %@", err)
        }
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

var hotkeyRefs: [EventHotKeyRef?] = []

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

    for (i, hk) in hotkeys.enumerated() {
        let hkID = EventHotKeyID(signature: OSType(0x4F504D47), id: UInt32(i))
        var hkRef: EventHotKeyRef?
        RegisterEventHotKey(hk.keyCode, modifiers, hkID, GetApplicationEventTarget(), 0, &hkRef)
        hotkeyRefs.append(hkRef)
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
        registerHotkeys()

        // quick test: log to confirm running
        NSLog("OpenMagnet: running, hotkeys registered")
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
}

// ── main ─────────────────────────────────────────────────────────
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
