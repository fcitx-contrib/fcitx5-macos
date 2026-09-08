import AppKit
import CxxFrontend
import InputMethodKit
import Logging

nonisolated(unsafe) private var u16pos = 0
nonisolated(unsafe) private var currentPreedit = ""

private let zeroWidthSpace = "\u{200B}"

private let passwordOnlyApps: Set<String> = [
  "com.apple.loginwindow",
  // Below are apps that only have password fields but don't call EnableSecureEventInput.
  "com.apple.wifi.WiFiAgent",  // join wifi from wifi menu
  "com.apple.wifi-settings-extension",  // join wifi from System Settings
  "com.apple.LocalAuthenticationRemoteService",  // Software Update
]

// Given issues when no preedit is so widespread regardless of UI framework,
// any app that is added here must be fully tested with Esc, Backspace, Arrow and normal keys.
// Union password-only apps so that fcitx clipboard can be used (though you may have to type instead of click to commit).
private let appsWithoutDummyPreedit: Set<String> = passwordOnlyApps.union([
  // <200b>
  "org.vim.MacVim",
  // When writing a new email and caret is at the beginning of To or Cc, Mail calls commitComposition
  // if the preedit is any kind of white space.
  "com.apple.mail",
  // Space (both commit and preedit) is not allowed immediately after ordered list (1.), which is the
  // dummy preedit we use for the SwiftUI TextField workaround. While we can change that normal space
  // to full-width space, it seems DingTalk doesn't need dummy preedit at all.
  "com.alibaba.DingTalkMac",
])

public func isPasswordOnly(app: String) -> Bool {
  return passwordOnlyApps.contains(app)
}

private func isJetBrains(_ app: String) -> Bool {
  return app == "com.google.android.studio" || app.starts(with: "com.jetbrains.")
}

nonisolated(unsafe) private var controller: IMKInputController? = nil
nonisolated(unsafe) private var currentLayout: String? = nil

public func setController(_ ctrl: Any) {
  guard let ctrl = ctrl as? IMKInputController, controller != ctrl else {
    return
  }
  controller = ctrl
  currentLayout = nil
}

@MainActor
private var statusItemCallback: ((Int32?, String?) -> Void)? = nil

@MainActor
public func setStatusItemCallback(_ callback: @escaping (Int32?, String?) -> Void) {
  statusItemCallback = callback
}

public func setStatusItemText(_ text: String) {
  Task { @MainActor in
    statusItemCallback?(nil, text)
  }
}

public func setStatusItemMode(_ mode: Int32) {
  Task { @MainActor in
    statusItemCallback?(mode, nil)
  }
}

private func commitString(_ client: IMKTextInput, _ string: String) {
  client.insertText(string, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
  // Without it currentPreedit.count in commitAndSetPreeditSync will be wrong with pinyin prediction.
  currentPreedit = ""
}

private func setPreedit(_ client: IMKTextInput, _ preedit: String, _ caretPosUtf8: Int) {
  currentPreedit = preedit
  // The caretPos argument is specified in UTF-8 bytes.
  // Convert it to UTF-16.
  var u8pos = 0
  u16pos = 0
  for ch in preedit {
    if u8pos == caretPosUtf8 {
      break
    }
    u8pos += ch.utf8.count
    u16pos += ch.utf16.count  // Usually 1 but can be more, e.g. emoji.
  }
  // Make underline as thin as macOS pinyin.
  let attrs =
    controller?.mark(forStyle: kTSMHiliteConvertedText, at: NSMakeRange(NSNotFound, 0))
    as? [NSAttributedString.Key: Any]
  client.setMarkedText(
    NSMutableAttributedString(string: preedit, attributes: attrs),
    selectionRange: NSRange(location: u16pos, length: 0),
    replacementRange: NSRange(location: NSNotFound, length: 0)
  )
}

public func commitAndSetPreeditSync(
  _ client: IMKTextInput, _ commit: String, _ preedit: String, _ caretPos: Int,
  _ dummyPreedit: Bool
) {
  if !commit.isEmpty {
    commitString(client, commit)
  }
  let app = client.bundleIdentifier() ?? ""
  // Without client preedit, Backspace bypasses IM in Terminal, every key is both
  // processed by IM and passed to client in iTerm, JetBrains and VSCode terminal,
  // Backspace is double-processed in Chrome address bar/VSCode editor/Bruno URL input,
  // ArrowDown is swallowed in Spotlight, so we force a dummy client preedit here.
  // Some apps also need it to get accurate caret position to place candidate window.
  // This is fine even when there is selected text. In Word, not using dummy preedit to
  // replace selected text will let Esc bypass IM. When using Shift+click to select, if
  // interval is too little, IM switch happens, but dummyPreedit is false in that case.
  if preedit.isEmpty && dummyPreedit {
    if appsWithoutDummyPreedit.contains(app) {
      return
    }
    let length = client.length()
    let selectedRange = client.selectedRange()
    // We prefer ZWS to avoid text layout shift after caret, e.g. VSCode.
    // For SwiftUI TextField, there is a bug that if caret is at the end of text, zero-width space preedit
    // spreads from the start to the end, making the whole text underlined. Fortunately, SwiftUI's length
    // and selectedRange are reliable, so we use a normal space in this case.
    // JetBrains-based IDEs displays zero-width space as "ZWSP" so we'd rather use a normal space.
    if (length > 0 && length - currentPreedit.count == NSMaxRange(selectedRange))
      || isJetBrains(app)
    {
      setPreedit(client, " ", 0)
    } else {
      setPreedit(client, zeroWidthSpace, 0)
    }
  } else {
    setPreedit(client, preedit, caretPos)
  }
}

public func commitAndSetPreeditAsync(
  _ commit: String, _ preedit: String, _ caretPos: Int, _ dummyPreedit: Bool
) {
  Task { @MainActor in
    guard let client = controller?.client() else {
      return
    }
    commitAndSetPreeditSync(client, commit, preedit, caretPos, dummyPreedit)
  }
}

public func commitAsync(_ commit: String) {
  Task { @MainActor in
    guard let client = controller?.client() else {
      return
    }
    commitString(client, commit)
  }
}

public func getSurroundingText(_ location: Int, _ length: Int) -> (String, UInt32, UInt32) {
  guard let client = controller?.client(), location != NSNotFound else {
    return ("", 0, 0)
  }
  let totalLength = client.length()
  // currentPreedit is inserted at location - u16pos
  let preeditStart = max(0, location - u16pos)
  let preeditEnd = preeditStart + currentPreedit.utf16.count

  var actual = NSRange(location: 0, length: 0)
  let beforeStr =
    client.string(from: NSRange(location: 0, length: preeditStart), actualRange: &actual) ?? ""
  let fullText =
    beforeStr
    + (client.string(
      from: NSRange(location: preeditEnd, length: max(0, totalLength - preeditEnd)),
      actualRange: &actual) ?? "")

  // fcitx5 expects Unicode code point count for anchor and cursor in surrounding text.
  let anchor = UInt32(beforeStr.unicodeScalars.count)
  if currentPreedit.isEmpty && length > 0 {
    let selectionStr =
      client.string(from: NSRange(location: location, length: length), actualRange: &actual) ?? ""
    return (fullText, anchor + UInt32(selectionStr.unicodeScalars.count), anchor)
  }
  return (fullText, anchor, anchor)
}

// It's called from C++ within dispatch_async(dispatch_get_main_queue())
// so we can mark corresponding variables as nonisolated(unsafe).
public func getCaretCoordinates(_ followCaret: Bool) -> [Double] {
  guard let client = controller?.client() else {
    return []
  }
  var rect = NSRect(x: 0, y: 0, width: 0, height: 0)
  // n characters have n+1 caret positions, but character index only accepts 0 to n-1,
  // and passing n results in (0,0). So if caret is in the end, go back and add some width.
  // For dummy preedit, index is 0. For no preedit at all, don't apply it.
  let shouldGoBack = followCaret && currentPreedit.count > 0 && u16pos == currentPreedit.utf16.count
  let lastCharacter = currentPreedit.last.map(String.init) ?? ""
  let index = followCaret ? (shouldGoBack ? u16pos - lastCharacter.utf16.count : u16pos) : 0
  let attributes = client.attributes(forCharacterIndex: index, lineHeightRectangle: &rect)
  if rect.width == 0 && rect.height == 0 {
    return []
  }
  var x = Double(NSMinX(rect))
  let y = Double(NSMinY(rect))
  let height = Double(rect.height)
  if shouldGoBack {
    let lineHeight = Double(max(abs(rect.width), abs(rect.height)))
    let reportedFont = attributes?[NSAttributedString.Key.font] as? NSFont
    let font: NSFont
    // Terminal reports correct font with size (Menlo-Regular 14.00 pt), but others just give Helvetica 12.00 pt.
    // If line height is 1-1.5x font size, we treat font size as exact, otherwise font size = line height / 1.2 .
    if let reportedFont, reportedFont.pointSize <= lineHeight,
      lineHeight <= reportedFont.pointSize * 1.5
    {
      font = reportedFont
    } else {
      font = NSFont.systemFont(ofSize: lineHeight / 1.2)
    }
    x += (lastCharacter as NSString).size(withAttributes: [.font: font]).width
  }
  return [x, y, height]
}

// Called from C++ within dispatch_async(dispatch_get_main_queue())
public func getSelection() -> String {
  guard let client = controller?.client() else {
    return ""
  }
  let range = client.selectedRange()
  if range.location == NSNotFound {
    return ""
  }
  var actualRange = NSRange(location: 0, length: 0)
  return client.string(from: range, actualRange: &actualRange) ?? ""
}

// Call it on
// 1. Open a new App: FcitxInputController.init
// 2. Switch App: FcitxInputController.activateServer
// 3. Switch group: condition covered by 4
// (below are HACK for VSCode terminal and Neovide Chinese punctuation)
// 4. Switch input method: InputContextInputMethodActivated
// 5. Update punctuation option: UserInterfaceComponent::StatusArea
public func overrideKeyboardLayout() {
  let layout = String(get_current_group_layout())
  let appleLayout = layout == "PinyinKeyboard" ? "PinyinKeyboard" : layoutMap[layout] ?? "ABC"
  guard let client = controller?.client(), currentLayout != appleLayout else {
    return
  }
  FCITX_DEBUG("Override keyboard layout to \(appleLayout)")
  currentLayout = appleLayout
  client.overrideKeyboard(withKeyboardNamed: "com.apple.keylayout.\(appleLayout)")
}
