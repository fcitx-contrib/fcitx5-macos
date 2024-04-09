import InputMethodKit

private var u16pos = 0
private var currentPreedit = ""

public func commit(_ client: Any!, _ string: String) {
  if let client = client as? IMKTextInput {
    client.insertText(string, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
  }
}

// Executed in fcitx thread, so before process_key returns, no UI update
// will happen. That means we can't get coordinates in this function.
public func setPreedit(_ client: Any!, _ preedit: String, _ caretPosUtf8: Int) {
  if let client = client as? IMKTextInput {
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
}

// Must be executed after actual preedit UI update, i.e. not simply setPreedit.
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
