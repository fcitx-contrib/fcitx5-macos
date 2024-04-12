import OSLog

let logger = Logger(subsystem: "org.fcitx.inputmethod.Fcitx5", category: "FcitxLog")

public func FCITX_DEBUG(_ message: String) {
  if isDebug {
    logger.debug("\(message, privacy: .public)")
    fputs(message + "\n", stderr)
  }
}

public func FCITX_INFO(_ message: String) {
  if isDebug {
    logger.info("\(message, privacy: .public)")
  }
  fputs(message + "\n", stderr)
}

public func FCITX_WARN(_ message: String) {
  if isDebug {
    logger.error("\(message, privacy: .public)")
  }
  fputs(message + "\n", stderr)
}

public func FCITX_ERROR(_ message: String) {
  if isDebug {
    logger.fault("\(message, privacy: .public)")
  }
  fputs(message + "\n", stderr)
}
