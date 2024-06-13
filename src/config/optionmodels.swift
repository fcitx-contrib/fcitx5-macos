import Foundation
import Logging
import SwiftUI
import SwiftyJSON

// In fcitx, a "config" can be either an option or a container for
// options.
struct Config: Identifiable {
  public let path: String
  public let description: String
  public let kind: ConfigKind
  public let id = UUID()
}

extension Config: FcitxCodable {
  static func decode(json: JSON) throws -> Config {
    return try jsonToConfig(json, "")
  }

  /// Encode the config as a "value json" J.
  /// Such that J["A"]["B"]["C"] is the value for option A/B/C.
  func encodeValueJSON() -> JSON {
    return configToJson(self)
  }
}

extension Config {
  func key() -> String? {
    return path.split(separator: "/").last.map { String($0) }
  }

  func resetToDefault() {
    switch self.kind {
    case .group(let children):
      for child in children {
        child.resetToDefault()
      }
    case .option(let opt):
      opt.resetToDefault()
    }
  }
}

enum ConfigKind {
  case group([Config])
  case option(any Option)
}

// For type-erasure.
// Typed data are stored in the `FooOption` structs.
protocol Option: FcitxCodable {
  associatedtype Storage: FcitxCodable
  var value: Storage { get set }
  func resetToDefault()
}

struct Identified<T>: Identifiable {
  var value: T
  let id = UUID()
}

extension Identified: FcitxCodable where T: FcitxCodable {
  static func decode(json: JSON) throws -> Self {
    return Identified(value: try T.decode(json: json))
  }

  func encodeValueJSON() -> JSON {
    return value.encodeValueJSON()
  }
}

class SimpleOption<T: FcitxCodable>: Option, ObservableObject {
  let defaultValue: T
  @Published var value: T

  required init(defaultValue: T, value: T?) {
    self.defaultValue = defaultValue
    self.value = value ?? defaultValue
  }

  static func decode(json: JSON) throws -> Self {
    return Self(
      defaultValue: try T.decode(json: json["DefaultValue"]),
      value: try T?.decode(json: json["Value"])
    )
  }

  func encodeValueJSON() -> JSON {
    return value.encodeValueJSON()
  }

  func resetToDefault() {
    value = defaultValue
  }
}

typealias BooleanOption = SimpleOption<Bool>
typealias StringOption = SimpleOption<String>

extension StringOption: EmptyConstructible {
  static func empty(json: JSON) throws -> Self {
    return Self(defaultValue: "", value: "")
  }
}

class IntegerOption: Option, ObservableObject {
  let defaultValue: Int
  let max: Int?
  let min: Int?
  @Published var value: Int

  required init(defaultValue: Int, value: Int?, min: Int?, max: Int?) {
    self.defaultValue = defaultValue
    self.value = value ?? defaultValue
    self.min = min
    self.max = max
  }

  static func decode(json: JSON) throws -> Self {
    return Self(
      defaultValue: try Int.decode(json: json["DefaultValue"]),
      value: try Int?.decode(json: json["Value"]),
      min: try Int?.decode(json: json["IntMin"]),
      max: try Int?.decode(json: json["IntMax"])
    )
  }

  func encodeValueJSON() -> JSON {
    return value.encodeValueJSON()
  }

  func resetToDefault() {
    value = defaultValue
  }
}

extension IntegerOption: CustomStringConvertible {
  var description: String {
    return "\(value) (was \(defaultValue))"
  }
}

class ColorOption: Option, ObservableObject {
  typealias Storage = Color
  let defaultValue: Color
  // Prior to macOS 14.0, ColorPicker doesn't support alpha
  var value: Color
  @Published var rgb: Color {
    didSet { updateColor() }
  }
  @Published var alpha: Int {
    didSet { updateColor() }
  }

  required init(defaultValue: Color, value: Color?) {
    self.defaultValue = defaultValue
    let rgb = value ?? defaultValue
    self.rgb = rgb
    self.alpha = Int(round(rgb.cgColor!.components![3] * 255.0))
    self.value = rgb
  }

  func updateColor() {
    let s = colorToString(rgb)
    value = stringToColor(String(format: "%@%02X", String(s.prefix(s.count - 2)), alpha))
  }

  static func decode(json: JSON) throws -> Self {
    return Self(
      defaultValue: try Color.decode(json: json["DefaultValue"]),
      value: try Color?.decode(json: json["Value"])
    )
  }

  func encodeValueJSON() -> JSON {
    return value.encodeValueJSON()
  }

  func resetToDefault() {
    rgb = defaultValue
    alpha = Int(round(rgb.cgColor!.components![3] * 255.0))
  }
}

private func stringToColor(_ hex: String) -> Color {
  let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
  var rgbValue: UInt64 = 0

  Scanner(string: hex).scanHexInt64(&rgbValue)

  let hasAlpha = hex.count > 6
  let alpha = hasAlpha ? Double(rgbValue & 0xFF) / 255.0 : 1.0
  if hasAlpha {
    rgbValue >>= 8
  }
  let red = Double((rgbValue & 0xFF0000) >> 16) / 255.0
  let green = Double((rgbValue & 0x00FF00) >> 8) / 255.0
  let blue = Double(rgbValue & 0x0000FF) / 255.0

  return Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
}

private func colorToString(_ color: Color) -> String {
  let resolved = NSColor(color)
  let components = resolved.cgColor.components!
  let red = UInt8(round(components[0] * 255.0))
  let green = UInt8(round(components[1] * 255.0))
  let blue = UInt8(round(components[2] * 255.0))
  let alpha = UInt8(round(components[3] * 255.0))

  return String(format: "#%02X%02X%02X%02X", red, green, blue, alpha)
}

extension Color: FcitxCodable {
  static func decode(json: JSON) throws -> Self {
    let colorStr = try String.decode(json: json)
    return stringToColor(colorStr)
  }

  func encodeValueJSON() -> JSON {
    return colorToString(self).encodeValueJSON()
  }
}

class EnumOption: Option, ObservableObject, EmptyConstructible {
  let defaultValue: String
  let enumStrings: [String]
  let enumStringsI18n: [String]
  @Published var value: String

  required init(
    defaultValue: String, value: String?, enumStrings: [String], enumStringsI18n: [String]
  ) {
    self.defaultValue = defaultValue
    self.value = value ?? defaultValue
    self.enumStrings = enumStrings
    self.enumStringsI18n = enumStringsI18n
  }

  static func decode(json: JSON) throws -> Self {
    let obj = try Self.empty(json: json)
    return Self(
      defaultValue: json["DefaultValue"].stringValue,
      value: json["Value"].string,
      enumStrings: obj.enumStrings,
      enumStringsI18n: obj.enumStringsI18n
    )
  }

  func encodeValueJSON() -> JSON {
    return value.encodeValueJSON()
  }

  func resetToDefault() {
    value = defaultValue
  }

  static func empty(json: JSON) throws -> Self {
    let enums = try [String].decode(json: json["Enum"])
    let enumsi18n = try [String].decode(json: json["EnumI18n"])
    return Self(
      defaultValue: "",
      value: "",
      enumStrings: enums,
      enumStringsI18n: enumsi18n.count < enums.count ? enums : enumsi18n
    )
  }
}

extension EnumOption: CustomStringConvertible {
  var description: String {
    return "\(value)"
  }
}

/// Construct an "empty" object from the json document, in the sense
/// that Value and DefaultValue can be uninitialized.
protocol EmptyConstructible {
  static func empty(json: JSON) throws -> Self
}

class FontOption: StringOption {}

class AppIMOption: Option, ObservableObject, EmptyConstructible {
  typealias Storage = String
  let defaultValue: String
  var value: String
  @Published var appId: String {
    didSet { updateValue() }
  }
  @Published var appName: String {
    didSet { updateValue() }
  }
  @Published var appPath: String {
    didSet { updateValue() }
  }
  @Published var imName: String {
    didSet { updateValue() }
  }

  required init(defaultValue: String, value: String?) {
    self.defaultValue = defaultValue
    self.value = value ?? defaultValue
    do {
      if let data = (value ?? defaultValue).data(using: .utf8) {
        let json = try JSON(data: data)
        appId = try String?.decode(json: json["appId"]) ?? ""
        appName = try String?.decode(json: json["appName"]) ?? ""
        appPath = try String?.decode(json: json["appPath"]) ?? ""
        imName = try String?.decode(json: json["imName"]) ?? ""
      } else {
        throw NSError()
      }
    } catch {
      appId = ""
      appName = ""
      appPath = ""
      imName = ""
    }
  }

  private func updateValue() {
    let json = JSON([
      "appId": appId.encodeValueJSON(),
      "appName": appName.encodeValueJSON(),
      "appPath": appPath.encodeValueJSON(),
      "imName": imName.encodeValueJSON(),
    ])
    value = jsonToString(json)
  }

  static func decode(json: JSON) throws -> Self {
    return Self(
      defaultValue: try String.decode(json: json["DefaultValue"]),
      value: try String?.decode(json: json["Value"])
    )
  }

  func encodeValueJSON() -> JSON {
    return value.encodeValueJSON()
  }

  func resetToDefault() {
    appId = ""
    appName = ""
    appPath = ""
    imName = ""
  }

  static func empty(json: JSON) throws -> Self {
    return Self(defaultValue: "", value: "")
  }
}

class PunctuationMapOption: Option, ObservableObject, EmptyConstructible {
  typealias Storage = [String: String]
  let defaultValue: [String: String]
  var value: [String: String]

  required init(defaultValue: Storage, value: Storage?) {
    self.defaultValue = defaultValue
    self.value = value ?? defaultValue
  }

  static func decode(json: JSON) throws -> Self {
    return Self(
      defaultValue: try Storage.decode(json: json["DefaultValue"]),
      value: try Storage?.decode(json: json["Value"])
    )
  }

  func encodeValueJSON() -> JSON {
    return value.encodeValueJSON()
  }

  func resetToDefault() {
  }

  static func empty(json: JSON) throws -> Self {
    return Self(defaultValue: [:], value: [:])
  }
}

class ListOption<T: Option & EmptyConstructible>: Option, ObservableObject {
  let defaultValue: [T]
  @Published var value: [Identified<T>]
  let elementType: String
  let raw: JSON

  required init(defaultValue: [T], value: [T]?, elementType: String, raw: JSON) {
    self.defaultValue = defaultValue
    self.value = (value ?? defaultValue).map { Identified(value: $0) }
    self.elementType = elementType
    self.raw = raw
  }

  static func decode(json: JSON) throws -> Self {
    let defaultOptions = try [T.Storage].decode(json: json["DefaultValue"]).map {
      return try T.decode(json: [
        "DefaultValue": $0.encodeValueJSON(), "Value": $0.encodeValueJSON(),
      ])
    }
    let options = try [T.Storage].decode(json: json["Value"]).map {
      return try T.decode(json: [
        "DefaultValue": $0.encodeValueJSON(), "Value": $0.encodeValueJSON(),
      ])
    }
    return Self(
      defaultValue: defaultOptions,
      value: options,
      elementType: json["Type"].stringValue,
      raw: json
    )
  }

  func encodeValueJSON() -> JSON {
    return value.encodeValueJSON()
  }

  func resetToDefault() {
    value = defaultValue.map { Identified(value: $0) }
  }

  func addEmpty(at index: Int) {
    do {
      let newOpt = try T.empty(json: raw)
      self.value.insert(Identified(value: newOpt), at: index)
    } catch {
      FCITX_ERROR(
        "Cannot add new elements because I cannot construct empty objects: \(error.localizedDescription)"
      )
    }
  }
}

extension ListOption: CustomStringConvertible {
  var description: String {
    return "\(value)"
  }
}

struct ExternalOption: Option, FcitxCodable {
  typealias Storage = UnusedCodable
  var value = UnusedCodable()
  let option: String
  let external: String

  static func decode(json: JSON) throws -> Self {
    ExternalOption(
      option: try String.decode(json: json["Option"]),
      external: try String.decode(json: json["External"])
    )
  }

  func encodeValueJSON() -> JSON {
    return JSON()
  }

  func resetToDefault() {}
}

struct UnknownOption: Option {
  typealias Storage = UnusedCodable
  var value = UnusedCodable()
  let type: String
  let raw: JSON

  static func decode(json: JSON) throws -> Self {
    return UnknownOption(
      type: json["Type"].stringValue,
      raw: json
    )
  }

  func encodeValueJSON() -> JSON {
    return raw["Value"]
  }

  func resetToDefault() {}
}

class KeyOption: StringOption {}
