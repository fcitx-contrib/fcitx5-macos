import Foundation
import Logging

func quote(_ s: String) -> String {
  return s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
}

func twiceQuote(_ s: String) -> String {
  let quoted = quote(s)
  return quote("\"\(quoted)\"")
}

func sudo(_ script: String, _ arg: String, _ logPath: String) -> Bool {
  let user = NSUserName()
  guard let scriptPath = Bundle.main.path(forResource: script, ofType: "sh") else {
    FCITX_ERROR("\(script).sh not found")
    return false
  }
  let command =
    "do shell script \"\(twiceQuote(scriptPath)) \(twiceQuote(user)) \(twiceQuote(arg)) 2>\(logPath)\" with administrator privileges"
  guard let appleScript = NSAppleScript(source: command) else {
    FCITX_ERROR("Fail to initialize AppleScript")
    return false
  }
  var error: NSDictionary? = nil
  appleScript.executeAndReturnError(&error)
  if let error = error {
    FCITX_ERROR("Fail to execute AppleScript: \(error)")
    return false
  }
  return true
}
