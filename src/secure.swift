import AppKit
import Carbon
import IOKit

// Translated from https://github.com/espanso/espanso
// The return value is not guaranteed accurate. To reproduce, execute
// import Carbon
// EnableSecureEventInput()
// in swift repl, then this function returns terminal app's pid.
// However, after Ctrl+Cmd+Q and re-login, it returns com.apple.loginwindow's pid.
func getSecureInputProcessPID() -> Int32? {
  let rootService = IORegistryGetRootEntry(kIOMainPortDefault)
  guard rootService != 0 else { return nil }

  defer { IOObjectRelease(rootService) }
  if let cfConsoleUsers = IORegistryEntryCreateCFProperty(
    rootService,
    "IOConsoleUsers" as CFString,
    kCFAllocatorDefault,
    0
  )?.takeRetainedValue() as? [Any] {
    for user in cfConsoleUsers {
      if let userDict = user as? [String: Any],
        let secureInputPID = userDict["kCGSSessionSecureInputPID"] as? NSNumber
      {
        return secureInputPID.int32Value
      }
    }
  }
  return nil
}
