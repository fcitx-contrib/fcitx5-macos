import SwiftUI

private let codeMap = [
  // keypad
  0x52: "🄋",
  0x53: "➀",
  0x54: "➁",
  0x55: "➂",
  0x56: "➃",
  0x57: "➄",
  0x58: "➅",
  0x59: "➆",
  0x5b: "➇",
  0x5c: "➈",
  0x51: "⊜",
  0x4e: "⊖",
  0x43: "⊗",
  0x45: "⊕",
  0x4b: "⊘",
  // special
  0x33: "⌫",
  0x4c: "⌅",
  0x35: "⎋",
  0x75: "⌦",
  0x24: "↵",
  0x31: "␣",
  0x30: "⇥",
  // function
  0x7a: "F1",
  0x78: "F2",
  0x63: "F3",
  0x76: "F4",
  0x60: "F5",
  0x61: "F6",
  0x62: "F7",
  0x64: "F8",
  0x65: "F9",
  0x6d: "F10",
  0x67: "F11",
  0x6f: "F12",
  // cursor
  0x7e: "▲",
  0x7d: "▼",
  0x7b: "◀",
  0x7c: "▶",
  0x74: "⭡",
  0x79: "⭣",
  0x73: "⇱",
  0x77: "⇲",
  // pc keyboard
  0x72: "⎀",
  0x71: "⎉",
  0x69: "⎙",
  0x6b: "⇳",
]

func shortcutRepr(_ key: String, _ modifiers: NSEvent.ModifierFlags, _ code: UInt16) -> String {
  var desc = ""
  if modifiers.contains(.control) { desc += "⌃" }
  if modifiers.contains(.option) { desc += "⌥" }
  if modifiers.contains(.shift) {
    if (modifiers.rawValue & 0x20104) == 0x20104 {
      desc += "⬆"  // Shift_R
    } else {
      desc += "⇧"  // Shift_L
    }
  }
  if modifiers.contains(.command) { desc += "⌘" }
  // Use uppercase to match menu.
  return desc + (codeMap[Int(code)] ?? key.uppercased())
}

struct RecordingOverlay: NSViewRepresentable {
  @Binding var recordedShortcut: String
  @Binding var recordedKey: String
  @Binding var recordedModifiers: NSEvent.ModifierFlags
  @Binding var recordedCode: UInt16

  func makeNSView(context: Context) -> NSView {
    let view = KeyCaptureView()
    view.coordinator = context.coordinator
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  class Coordinator: NSObject {
    private var parent: RecordingOverlay
    private var key = ""
    private var modifiers = NSEvent.ModifierFlags()
    private var code: UInt16 = 0

    init(_ parent: RecordingOverlay) {
      self.parent = parent
    }

    func handleKeyCapture(key: String, code: UInt16) {
      self.key = key
      self.code = code
      updateParent()
    }

    func handleKeyCapture(modifiers: NSEvent.ModifierFlags, code: UInt16) {
      if modifiers.isDisjoint(with: [.command, .option, .control, .shift]) {
        self.modifiers = NSEvent.ModifierFlags()
        self.code = 0
      } else {
        if modifiers.isSuperset(of: self.modifiers) {
          // Don't change on release
          self.modifiers = modifiers
          self.key = ""
          self.code = code
        }
        updateParent()
      }
    }

    private func updateParent() {
      parent.recordedKey = key
      parent.recordedModifiers = modifiers
      parent.recordedCode = code
      parent.recordedShortcut = shortcutRepr(key, modifiers, code)
    }
  }
}

class KeyCaptureView: NSView {
  weak var coordinator: RecordingOverlay.Coordinator?

  // comment out will focus textfield. What if not textfield?
  override var acceptsFirstResponder: Bool {
    return true
  }

  override func keyDown(with event: NSEvent) {
    coordinator?.handleKeyCapture(
      key: event.charactersIgnoringModifiers ?? "", code: event.keyCode)
  }

  override func flagsChanged(with event: NSEvent) {
    coordinator?.handleKeyCapture(modifiers: event.modifierFlags, code: event.keyCode)
  }
}
