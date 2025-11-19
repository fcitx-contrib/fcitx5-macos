import Carbon

let enId = "org.fcitx.inputmethod.Fcitx5.fcitx5"

let inputSource = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
let id = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID)
if let id = id {
  print(Unmanaged<AnyObject>.fromOpaque(id).takeUnretainedValue() as? String ?? enId)
} else {
  print(enId)
}
