import InputMethodKit

private var u16pos = 0
private var currentPreedit = ""

private func commitString(_ client: IMKTextInput, _ string: String) {
  client.insertText(string, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
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
    u16pos += 1
  }
  client.setMarkedText(
    NSMutableAttributedString(string: preedit),
    selectionRange: NSRange(location: u16pos, length: 0),
    replacementRange: NSRange(location: NSNotFound, length: 0)
  )
}

public func commitAndSetPreeditSync(
  _ client: IMKTextInput, _ commit: String, _ preedit: String, _ cursorPos: Int,
  _ dummyPreedit: Bool
) {
  if !commit.isEmpty {
    commitString(client, commit)
  }
  // Without client preedit, Backspace bypasses IM in Terminal, every key
  // is both processed by IM and passed to client in iTerm, so we force a
  // dummy client preedit here.
  if preedit.isEmpty && dummyPreedit {
    setPreedit(client, " ", 0)
  } else {
    setPreedit(client, preedit, cursorPos)
  }
}

public func commitAndSetPreeditAsync(
  _ clientPtr: UnsafeMutableRawPointer, _ commit: String, _ preedit: String, _ cursorPos: Int,
  _ dummyPreedit: Bool
) {
  let client: AnyObject = Unmanaged.fromOpaque(clientPtr).takeUnretainedValue()
  guard let client = client as? IMKTextInput else {
    return
  }
  DispatchQueue.main.async {
    commitAndSetPreeditSync(client, commit, preedit, cursorPos, dummyPreedit)
  }
}

public func getCursorCoordinates(
  _ clientPtr: UnsafeMutableRawPointer,
  _ followCursor: Bool,
  _ x: UnsafeMutablePointer<Double>,
  _ y: UnsafeMutablePointer<Double>
) -> Bool {
  let client: AnyObject = Unmanaged.fromOpaque(clientPtr).takeUnretainedValue()
  if let client = client as? IMKTextInput {
    var rect = NSRect(x: 0, y: 0, width: 0, height: 0)
    // n characters have n+1 cursor positions, but character index only accepts 0 to n-1,
    // and passing n results in (0,0). So if cursor is in the end, go back and add 10px
    let isEnd = u16pos == currentPreedit.count
    client.attributes(
      forCharacterIndex: followCursor ? (isEnd ? u16pos - 1 : u16pos) : 0,
      lineHeightRectangle: &rect)
    x.pointee = Double(NSMinX(rect))
    y.pointee = Double(NSMinY(rect))
    if followCursor && isEnd {
      x.pointee += 10
    }
    return true
  }
  return false
}
