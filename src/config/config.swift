import Fcitx
import Foundation
import Logging
import SwiftyJSON

public func getConfig(uri: String) throws -> Config {
  let jsonString = String(Fcitx.getConfig(uri))
  let data = jsonString.data(using: .utf8, allowLossyConversion: false)!
  do {
    let json = try JSON(data: data)
    if json["ERROR"].exists() {
      throw FcitxConfigError.fcitxError(json["ERROR"].stringValue)
    }
    return try parseJSON(json, "")
  } catch let error as FcitxCodingError {
    throw FcitxConfigError.codingError(error)
  }
}

public func getGlobalConfig() throws -> Config {
  return try getConfig(uri: "fcitx://config/global")
}

public func getConfig(addon: String) throws -> Config {
  return try getConfig(uri: "fcitx://config/addon/\(addon)/")
}

public func getConfig(im: String) throws -> Config {
  return try getConfig(uri: "fcitx://config/inputmethod/\(im)")
}

struct DynamicCodingKey: CodingKey {
  var stringValue: String
  var intValue: Int?

  init?(stringValue: String) {
    self.stringValue = stringValue
    self.intValue = nil
  }

  init?(intValue: Int) {
    self.stringValue = String(intValue)
    self.intValue = intValue
  }
}

func parseJSON(_ json: JSON, _ pathPrefix: String) throws -> Config {
  let description = json["Description"].stringValue
  // Option
  if let type = json["Type"].string,
    !type.contains("$")
  {
    do {
      let option = try parseOptionJSON(json, type)
      return Config(path: pathPrefix, description: description, kind: .option(option))
    } catch {
      throw FcitxCodingError.innerError(path: pathPrefix, context: json, error: error)
    }
  }
  // Group
  var children: [Config] = []
  for (key, subJson): (String, JSON) in json {
    if key == "Value" || key == "Description" || key == "DefaultValue" || key == "Type" {
      continue
    }
    do {
      children.append(try parseJSON(subJson, pathPrefix + "/" + key))
    } catch {
      throw FcitxCodingError.innerError(
        path: pathPrefix + "/" + key, context: subJson, error: error)
    }
  }
  // JSON is unordered -- sort options by description lexically.
  children.sort { $0.description < $1.description }
  return Config(path: pathPrefix, description: description, kind: .group(children))
}

func parseOptionJSON(_ json: JSON, _ type: String) throws -> any Option {
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
  // TODO: func encode() -> String
}

extension FcitxCodable {
  static func decode(_ str: String) throws -> Self {
    return try Self.decode(json: JSON(parseJSON: str))
  }
}

extension Int: FcitxCodable {
  static func decode(json: JSON) throws -> Int {
    // json is like "100"
    if let int = Int(json.stringValue.trimmingCharacters(in: CharacterSet(charactersIn: "\""))) {
      return int
    } else {
      throw FcitxCodingError.invalidArgument(context: json)
    }
  }
  func encode() -> String {
    String(self)
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
  func encode() -> String {
    if self { return "True" } else { return "False" }
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
  func encode() -> String {
    let encodedString = self.replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
    return "\"\(encodedString)\""
  }
}

extension Array: FcitxCodable where Element: FcitxCodable {
  static func decode(json: JSON) throws -> Self {
    var result: [Element] = []
    for (_, subJSON): (String, JSON) in json {
      result.append(try Element.decode(json: subJSON))
    }
    return result
  }
  // func encode() -> String {
  //   var json = JSON()
  //   for (idx, obj) in self.enumerated() {
  //     json[String(idx)] = obj.encode()
  //   }
  //   return json.rawStringes()
  // }
}

enum FcitxConfigError: Error {
  case fcitxError(String)
  case codingError(FcitxCodingError)
}
