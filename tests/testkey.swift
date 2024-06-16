func testMacToFcitx() {
  assert(macKeyToFcitxString("a", .control, 0) == "Control+A")
  assert(macKeyToFcitxString("A", .control.union(.shift), 0) == "Control+Shift+A")

  assert(macKeyToFcitxString("", .option.union(.shift), 0x38) == "Alt+Shift+Shift_L")
  assert(macKeyToFcitxString("", .command.union(.shift), 0x3c) == "Shift+Super+Shift_R")
}

func testFcitxToMac() {
  assert(fcitxStringToMacShortcut("0") == "0")
  assert(fcitxStringToMacShortcut("KP_0") == "🄋")
  assert(fcitxStringToMacShortcut("Control+A") == "⌃A")
  assert(fcitxStringToMacShortcut("Control+Shift+A") == "⌃⇧A")
  assert(fcitxStringToMacShortcut("Shift+Super+Shift_L") == "⇧⌘")
  assert(fcitxStringToMacShortcut("Alt+Shift+Shift_R") == "⌥⬆")
}

@_cdecl("main")
func main() -> Int {
  testMacToFcitx()
  testFcitxToMac()
  return 0
}
