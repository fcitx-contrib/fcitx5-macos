import InputMethodKit

var globalClient: Any?

public func setClient(_ client: Any) {
  globalClient = client
}

public func commit(_ string: String) {
  guard let client = globalClient as? IMKTextInput else {
    return
  }
  client.insertText(string, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
}

// Executed in fcitx thread, so before process_key returns, no UI update
// will happen. That means we can't get coordinates in this function.
public func setPreedit(_ preedit: String, _ caretPosUtf8: Int) {
  guard let client = globalClient as? IMKTextInput else {
    return
  }
  // The caretPos argument is specified in UTF-8 bytes.
  // Convert it to UTF-16.
  var u8pos = 0
  var u16pos = 0
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

// Must be executed after actual preedit UI update, i.e. not simply setPreedit.
public func getCursorCoordinates(
  _ x: UnsafeMutablePointer<Float>,
  _ y: UnsafeMutablePointer<Float>
) -> Bool {
  if let client = globalClient as? IMKTextInput {
    var rect = NSRect(x: 0, y: 0, width: 0, height: 0)
    client.attributes(forCharacterIndex: 0, lineHeightRectangle: &rect)
    x.pointee = Float(NSMinX(rect))
    y.pointee = Float(NSMinY(rect))
    return true
  }
  return false
}
