import SwiftUI

struct RecordingOverlay: NSViewRepresentable {
  @Binding var recordedShortcut: String

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
    private static let codeMap = [
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
      0x7e: "↑",
      0x7d: "↓",
      0x7b: "←",
      0x7c: "→",
      0x74: "⇡",
      0x79: "⇣",
      0x73: "⇱",
      0x77: "⇲",
      // pc keyboard
      0x72: "⎀",
      0x71: "⎉",
      0x69: "⎙",
      0x6b: "⇳",
    ]
    private var parent: RecordingOverlay
    private var key = ""
    private var modifier = NSEvent.ModifierFlags()

    init(_ parent: RecordingOverlay) {
      self.parent = parent
    }

    func handleKeyCapture(key: String, code: Int) {
      self.key = Coordinator.codeMap[code] ?? key

      updateParent()
    }

    func handleKeyCapture(modifier: NSEvent.ModifierFlags) {
      if modifier.isDisjoint(with: [.command, .option, .control, .shift]) {
        self.modifier = NSEvent.ModifierFlags()
      } else {
        if modifier.isSuperset(of: self.modifier) {
          // Don't change on release
          self.modifier = modifier
          self.key = ""
        }
        updateParent()
      }
    }

    private func updateParent() {
      parent.recordedShortcut = modifier.description + key
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
      key: event.charactersIgnoringModifiers ?? "", code: Int(event.keyCode))
  }

  override func flagsChanged(with event: NSEvent) {
    coordinator?.handleKeyCapture(modifier: event.modifierFlags)
  }
}

extension NSEvent.ModifierFlags {
  var description: String {
    var desc = ""
    if contains(.control) { desc += "⌃" }
    if contains(.option) { desc += "⌥" }
    if contains(.shift) {
      if (rawValue & 0x20104) == 0x20104 {
        desc += "⬆"  // Shift_R
      } else {
        desc += "⇧"  // Shift_L
      }
    }
    if contains(.command) { desc += "⌘" }
    return desc
  }
}
