import OSLog

let logger = Logger(subsystem: "org.fcitx.inputmethod.Fcitx5", category: "FcitxLog")

public func FCITX_DEBUG(_ message: String) {
    logger.debug("\(message, privacy: .public)")
}

public func FCITX_INFO(_ message: String) {
    logger.info("\(message, privacy: .public)")
}

public func FCITX_WARN(_ message: String) {
    logger.error("\(message, privacy: .public)")
}

public func FCITX_ERROR(_ message: String) {
    logger.fault("\(message, privacy: .public)")
}
