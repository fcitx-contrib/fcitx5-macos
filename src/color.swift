import AppKit

public func nsColorToString(_ color: NSColor) -> String? {
  guard let rgbColor = color.usingColorSpace(.sRGB) else {
    return nil
  }
  let red = UInt8(round(rgbColor.redComponent * 255.0))
  let green = UInt8(round(rgbColor.greenComponent * 255.0))
  let blue = UInt8(round(rgbColor.blueComponent * 255.0))
  let alpha = UInt8(round(rgbColor.alphaComponent * 255.0))
  return String(format: "#%02X%02X%02X%02X", red, green, blue, alpha)
}

private var colorMap = [String: String]()

func getAccentColor(_ id: String) -> String {
  if let cachedColor = colorMap[id] {
    return cachedColor
  }
  if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id),
    let bundle = Bundle(url: url),
    let info = bundle.infoDictionary,
    let name = info["NSAccentColorName"] as? String,
    let color = NSColor(named: NSColor.Name(name), bundle: bundle),
    let string = nsColorToString(color)
  {
    colorMap[id] = string
    return string
  } else {
    colorMap[id] = ""
    return ""
  }
}
