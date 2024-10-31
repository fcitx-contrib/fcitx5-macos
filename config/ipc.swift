import AppKit

let fcitx5Executable = "/Library/Input Methods/Fcitx5.app/Contents/MacOS/Fcitx5"
let switchImExecutable =
  "/Library/Input Methods/Fcitx5.app/Contents/MacOS/Fcitx5ConfigTool.app/Contents/Resources/switch_im"

func switchOut() {
  let _ = exec(switchImExecutable, ["com.apple.keylayout.ABC"])
  let _ = exec(switchImExecutable, ["com.apple.keylayout.US"])
}

func switchIn() {
  let _ = exec(switchImExecutable, ["org.fcitx.inputmethod.Fcitx5.fcitx5"])
}

func restartFcitxProcess(inputMethods: [String] = []) {
  switchOut()
  let _ = exec("/usr/bin/killall", ["Fcitx5"])
  let _ = exec(fcitx5Executable, inputMethods, isAsync: true)
  switchIn()
}
