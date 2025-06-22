func testMacToFcitx() {
  assert(macKeyToFcitxString("a", .control, 0) == "Control+A")
  assert(macKeyToFcitxString("A", .control.union(.shift), 0) == "Control+Shift+A")

  assert(macKeyToFcitxString("", .option.union(.shift), 0x38) == "Alt+Shift+Shift_L")
  assert(macKeyToFcitxString("", .command.union(.shift), 0x3c) == "Shift+Super+Shift_R")
}

func testFcitxToMac() {
  assert(fcitxStringToMacShortcut("0") == ("0", nil))
  assert(fcitxStringToMacShortcut("KP_0") == ("🄋", nil))
  assert(fcitxStringToMacShortcut("Control+A") == ("⌃A", nil))
  assert(fcitxStringToMacShortcut("Control+Shift+A") == ("⌃⇧A", nil))
  assert(fcitxStringToMacShortcut("Shift+Super+Shift_L") == ("⇧⌘", nil))
  assert(fcitxStringToMacShortcut("Alt+Shift+Shift_R") == ("⌥⬆", nil))
  assert(fcitxStringToMacShortcut("F12") == ("", "F12"))
  assert(fcitxStringToMacShortcut("Shift+F12") == ("⇧", "F12"))
  assert(fcitxStringToMacShortcut("Super+Home") == ("⌘⤒", nil))
}

@_cdecl("main")
func main() -> Int {
  testMacToFcitx()
  testFcitxToMac()
  return 0
}
