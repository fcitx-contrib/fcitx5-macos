import Foundation
import SwiftUI

// For type-erasure.
// Typed data are stored in the `FooOption` structs.
public protocol Option {
  associatedtype Storage
  var value: Storage { get }
}

class SimpleOption<T>: Option, ObservableObject {
  let defaultValue: T
  @Published var value: T

  init(defaultValue: T, value: T) {
    self.defaultValue = defaultValue
    self.value = value
  }
}

extension IntegerOption: CustomStringConvertible {
  var description: String {
    return "\(value) (was \(defaultValue))"
  }
}

typealias BooleanOption = SimpleOption<Bool>
typealias StringOption = SimpleOption<String>

class IntegerOption: Option, ObservableObject {
  let defaultValue: Int
  let max: Int
  let min: Int
  @Published var value: Int

  init(defaultValue: Int, value: Int, min: Int, max: Int) {
    self.defaultValue = defaultValue
    self.value = value
    self.min = min
    self.max = max
  }
}

extension SimpleOption: CustomStringConvertible {
  var description: String {
    return "\(value) (was \(defaultValue))"
  }
}

class EnumOption: Option, ObservableObject, FcitxCodable {
  let defaultValue: String
  let enumStrings: [String]
  let enumStringsI18n: [String]
  @Published var value: String

  init(defaultValue: String, value: String, enumStrings: [String], enumStringsI18n: [String]) {
    self.defaultValue = defaultValue
    self.value = value
    self.enumStrings = enumStrings
    self.enumStringsI18n = enumStringsI18n
  }
}

extension EnumOption: CustomStringConvertible {
  var description: String {
    return "\(value)"
  }
}

class ListOption<T>: Option, ObservableObject {
  let defaultValue: [T]
  let elementType: String
  @Published var value: [T]

  init(defaultValue: [T], value: [T], elementType: String) {
    self.defaultValue = defaultValue
    self.elementType = elementType
    self.value = value
  }
}

struct ExternalOption: Option, Decodable {
  let value: () = ()
  let launchSubConfig: Bool
  let external: String

  enum CodingKeys: String, CodingKey {
    case launchSubConfig = "LaunchSubConfig"
    case external = "External"
  }
}

struct UnknownOption: Option {
  let type: String

  enum CodingKeys: String, CodingKey {
    case type = "Type"
  }
}

// TODO KeyOption
typealias KeyOption = StringOption
