import Foundation
import SwiftUI
import SwiftyJSON

// In fcitx, a "config" can be either an option or a container for
// options.
public struct Config: Identifiable {
  public let path: String
  public let description: String
  public let sortKey: Int
  public let kind: ConfigKind
  public let id = UUID()
}

extension Config {
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

public enum ConfigKind {
  case group([Config])
  case option(any Option)
}

// For type-erasure.
// Typed data are stored in the `FooOption` structs.
public protocol Option {
  associatedtype Storage
  var value: Storage { get }
  func resetToDefault()
}

class SimpleOption<T: FcitxCodable>: Option, ObservableObject, FcitxCodable {
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

  func resetToDefault() {
    value = defaultValue
  }
}

extension IntegerOption: CustomStringConvertible {
  var description: String {
    return "\(value) (was \(defaultValue))"
  }
}

typealias BooleanOption = SimpleOption<Bool>
typealias StringOption = SimpleOption<String>

class IntegerOption: Option, ObservableObject, FcitxCodable {
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

  func resetToDefault() {
    value = defaultValue
  }
}

class EnumOption: Option, ObservableObject, FcitxCodable {
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
    let enums = try [String].decode(json: json["Enum"])
    let enumsi18n = try [String].decode(json: json["EnumI18n"])
    return Self(
      defaultValue: json["DefaultValue"].stringValue,
      value: json["Value"].string,
      enumStrings: enums,
      enumStringsI18n: enumsi18n.count < enums.count ? enums : enumsi18n
    )
  }

  func resetToDefault() {
    value = defaultValue
  }
}

extension EnumOption: CustomStringConvertible {
  var description: String {
    return "\(value)"
  }
}

class ListOption<T: FcitxCodable>: Option, ObservableObject, FcitxCodable {
  let defaultValue: [T]
  @Published var value: [T]
  let elementType: String

  required init(defaultValue: [T], value: [T]?, elementType: String) {
    self.defaultValue = defaultValue
    self.value = value ?? defaultValue
    self.elementType = elementType
  }

  static func decode(json: JSON) throws -> Self {
    return Self(
      defaultValue: try [T].decode(json: json["DefaultValue"]),
      value: try [T]?.decode(json: json["Value"]),
      elementType: json["Type"].stringValue
    )
  }

  func resetToDefault() {
    value = defaultValue
  }
}

extension ListOption: CustomStringConvertible {
  var description: String {
    return "\(value)"
  }
}

struct ExternalOption: Option, FcitxCodable {
  let value: () = ()
  let external: String

  static func decode(json: JSON) throws -> Self {
    ExternalOption(
      external: try String.decode(json: json["External"])
    )
  }

  func resetToDefault() {}
}

struct UnknownOption: Option, FcitxCodable {
  let value: () = ()
  let type: String
  let raw: JSON

  static func decode(json: JSON) throws -> Self {
    return UnknownOption(
      type: json["Type"].stringValue,
      raw: json
    )
  }

  func resetToDefault() {}
}

// TODO KeyOption
typealias KeyOption = StringOption
