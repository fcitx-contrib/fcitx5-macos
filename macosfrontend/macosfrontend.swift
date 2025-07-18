import AppKit
import InputMethodKit

private var u16pos = 0
private var currentPreedit = ""

private let zeroWidthSpace = "\u{200B}"

public var hasCaret = false

private var controller: IMKInputController? = nil

public func setController(_ ctrl: Any) {
  controller = ctrl as? IMKInputController
}

private var statusItemCallback: ((Int32?, String?) -> Void)? = nil

public func setStatusItemCallback(_ callback: @escaping (Int32?, String?) -> Void) {
  statusItemCallback = callback
}

public func setStatusItemText(_ text: String) {
  statusItemCallback?(nil, text)
}

public func setStatusItemMode(_ mode: Int32) {
  statusItemCallback?(mode, nil)
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
  _ dummyPreedit: Bool, focusOut: Bool = false
) {
  if !commit.isEmpty {
    commitString(client, commit)
  }
  // Setting preedit on focus out may cause IMK stall for seconds. High possibility
  // to reproduce by having no caret on a Safari page and Cmd+T to open a new Tab.
  if focusOut && !hasCaret {
    return
  }
  // Without client preedit, Backspace bypasses IM in Terminal, every key
  // is both processed by IM and passed to client in iTerm, so we force a
  // dummy client preedit here.
  // Some apps also need it to get accurate caret position to place candidate window.
  // This is fine even when there is selected text. In Word, not using dummy preedit to
  // replace selected text will let Esc bypass IM. When using Shift+click to select, if
  // interval is too little, IM switch happens, but dummyPreedit is false in that case.
  if preedit.isEmpty && dummyPreedit {
    let length = client.length()
    let selectedRange = client.selectedRange()
    // For SwiftUI TextField, there is a bug that if caret is at the end of text, zero-width space preedit
    // spreads from the start to the end, making the whole text underlined. Fortunately, SwiftUI's length
    // and selectedRange are reliable, so we use a normal space in this case.
    if length > 0 && length - currentPreedit.count == NSMaxRange(selectedRange) {
      setPreedit(client, " ", 0)
    } else {
      setPreedit(client, zeroWidthSpace, 0)
    }
  } else {
    setPreedit(client, preedit, caretPos)
  }
}

public func commitAndSetPreeditAsync(
  _ clientPtr: UnsafeMutableRawPointer, _ commit: String, _ preedit: String, _ caretPos: Int,
  _ dummyPreedit: Bool
) {
  let client: AnyObject = Unmanaged.fromOpaque(clientPtr).takeUnretainedValue()
  guard let client = client as? IMKTextInput else {
    return
  }
  DispatchQueue.main.async {
    commitAndSetPreeditSync(client, commit, preedit, caretPos, dummyPreedit)
  }
}

public func commitAsync(_ clientPtr: UnsafeMutableRawPointer, _ commit: String) {
  let client: AnyObject = Unmanaged.fromOpaque(clientPtr).takeUnretainedValue()
  guard let client = client as? IMKTextInput else {
    return
  }
  DispatchQueue.main.async {
    commitString(client, commit)
  }
}

public func getCaretCoordinates(
  _ clientPtr: UnsafeMutableRawPointer,
  _ followCaret: Bool,
  _ x: UnsafeMutablePointer<Double>,
  _ y: UnsafeMutablePointer<Double>,
  _ height: UnsafeMutablePointer<Double>
) -> Bool {
  let client: AnyObject = Unmanaged.fromOpaque(clientPtr).takeUnretainedValue()
  guard let client = client as? IMKTextInput else {
    return false
  }
  var rect = NSRect(x: 0, y: 0, width: 0, height: 0)
  // n characters have n+1 caret positions, but character index only accepts 0 to n-1,
  // and passing n results in (0,0). So if caret is in the end, go back and add 10px
  let isEnd = u16pos == currentPreedit.count
  client.attributes(
    forCharacterIndex: followCaret ? (isEnd ? u16pos - 1 : u16pos) : 0,
    lineHeightRectangle: &rect)
  if rect.width == 0 && rect.height == 0 {
    hasCaret = false
    return false
  }
  x.pointee = Double(NSMinX(rect))
  y.pointee = Double(NSMinY(rect))
  height.pointee = Double(rect.height)
  if followCaret && isEnd {
    x.pointee += 10
  }
  hasCaret = true
  return true
}
