import Fcitx
import Foundation
import Logging
import SwiftyJSON

func getConfig(uri: String) throws -> Config {
  let jsonString = String(Fcitx.getConfig(uri))
  let data = jsonString.data(using: .utf8, allowLossyConversion: false)!
  do {
    let json = try JSON(data: data)
    if json["ERROR"].exists() {
      throw FcitxConfigError.fcitxError(json["ERROR"].stringValue)
    }
    return try jsonToConfig(json, "")
  } catch let error as FcitxCodingError {
    throw FcitxConfigError.codingError(error)
  }
}

func getGlobalConfig() throws -> Config {
  return try getConfig(uri: "fcitx://config/global")
}

func getConfig(addon: String) throws -> Config {
  return try getConfig(uri: "fcitx://config/addon/\(addon)/")
}

func getConfig(im: String) throws -> Config {
  return try getConfig(uri: "fcitx://config/inputmethod/\(im)")
}

func configToJson(_ config: Config) -> JSON {
  switch config.kind {
  case .group(let children):
    var json = JSON()
    for c in children {
      if let key = c.key() {
        json[key] = c.encodeValueJSON()
      } else {
        FCITX_ERROR("Cannot encode option at path " + c.path)
      }
    }
    return json
  case .option(let opt):
    return opt.encodeValueJSON()
  }
}

func jsonToConfig(_ json: JSON, _ pathPrefix: String) throws -> Config {
  let description = json["Description"].stringValue
  let sortKey = json["__SortKey"].intValue
  // Option
  if let type = json["Type"].string,
    !type.contains("$")
  {
    do {
      let option = try jsonToOption(json, type)
      return Config(
        path: pathPrefix, description: description, sortKey: sortKey, kind: .option(option))
    } catch {
      throw FcitxCodingError.innerError(path: pathPrefix, context: json, error: error)
    }
  }
  // Group
  var children: [Config] = []
  for (key, subJson): (String, JSON) in json {
    if key == "Value" || key == "Description" || key == "DefaultValue" || key == "Type"
      || key == "__SortKey"
    {
      continue
    }
    do {
      children.append(try jsonToConfig(subJson, pathPrefix + "/" + key))
    } catch {
      throw FcitxCodingError.innerError(
        path: pathPrefix + "/" + key, context: subJson, error: error)
    }
  }
  children.sort { $0.sortKey < $1.sortKey }
  return Config(
    path: pathPrefix, description: description, sortKey: sortKey, kind: .group(children))
}

private func jsonToOption(_ json: JSON, _ type: String) throws -> any Option {
  if type == "Integer" {
    return try IntegerOption.decode(json: json)
  } else if type == "Boolean" {
    return try BooleanOption.decode(json: json)
  } else if type == "String" {
    return try StringOption.decode(json: json)
  } else if type == "Enum" {
    return try EnumOption.decode(json: json)
  } else if type == "Key" {
    return try KeyOption.decode(json: json)
  } else if type == "List|String" {
    return try ListOption<String>.decode(json: json)
  } else if type == "List|Key" {
    // TODO
    return try ListOption<String>.decode(json: json)
  } else if type == "External" {
    return try ExternalOption.decode(json: json)
  } else {
    return try UnknownOption.decode(json: json)
  }
}

enum FcitxCodingError: Error {
  case innerError(path: String, context: JSON, error: any Error)
  case invalidArgument(context: JSON)
}

protocol FcitxCodable {
  static func decode(json: JSON) throws -> Self
  static func decode(_ str: String) throws -> Self
  func encodeValueJSON() -> JSON
  func encodeValue() -> String
}

extension FcitxCodable {
  static func decode(_ str: String) throws -> Self {
    let data = str.data(using: .utf8)!
    let json = try JSON(data: data, options: [.fragmentsAllowed])
    return try Self.decode(json: json)
  }

  func encodeValue() -> String {
    let json = self.encodeValueJSON()
    // I'm amazed by the fact that SwiftyJSON has problems dealing with type conversion.
    return jsonToString(json)
  }
}

// Encode json to string and guarantee the round-trip property.
// It is preferred to `.rawString` unconditionally!
public func jsonToString(_ json: JSON) -> String {
  if json.type == .string {
    let str = json.object as! String
    return "\""
      + str.replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"") + "\""
  } else {
    // Assume that serialization always work.
    return json.rawString([
      .jsonSerialization: [JSONSerialization.WritingOptions.fragmentsAllowed],
      .castNilToNSNull: true, .maxObjextDepth: 100,
    ])!
  }
}

extension Int: FcitxCodable {
  static func decode(json: JSON) throws -> Int {
    // json is like "100"
    if let int = Int(json.stringValue) {
      return int
    } else {
      throw FcitxCodingError.invalidArgument(context: json)
    }
  }
  func encodeValueJSON() -> JSON {
    return JSON(String(self))
  }
}

extension Bool: FcitxCodable {
  static func decode(json: JSON) throws -> Self {
    if json.stringValue == "True" {
      return true
    } else if json.stringValue == "False" {
      return false
    } else {
      throw FcitxCodingError.invalidArgument(context: json)
    }
  }
  func encodeValueJSON() -> JSON {
    if self { return JSON("True") } else { return JSON("False") }
  }
}

extension String: FcitxCodable {
  static func decode(json: JSON) throws -> Self {
    if let decoded = json.string {
      return decoded
    } else {
      throw FcitxCodingError.invalidArgument(context: json)
    }
  }
  func encodeValueJSON() -> JSON {
    return JSON(self)
  }
}

extension Array: FcitxCodable where Element: FcitxCodable {
  static func decode(json: JSON) throws -> Self {
    var result: [Element] = []
    // Retrieve by key to preserve order.
    for i in 0..<json.count {
      result.append(try Element.decode(json: json[String(i)]))
    }
    return result
  }
  func encodeValueJSON() -> JSON {
    var json = JSON()
    for (idx, element) in self.enumerated() {
      json[String(idx)] = element.encodeValueJSON()
    }
    return json
  }
}

extension Optional: FcitxCodable where Wrapped: FcitxCodable {
  static func decode(json: JSON) throws -> Self {
    do {
      return try Wrapped.decode(json: json)
    } catch {
      return nil
    }
  }

  func encodeValueJSON() -> JSON {
    if let value = self {
      return value.encodeValueJSON()
    } else {
      return JSON()
    }
  }
}

enum FcitxConfigError: Error {
  case fcitxError(String)
  case codingError(FcitxCodingError)
}
