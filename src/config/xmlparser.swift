import Foundation

class CustomPhraseParserDelegate: NSObject, XMLParserDelegate {
  var currentKey: String = ""
  var expectArray: Bool = false
  var expectDict: Bool = false
  var expectPhrase: Bool = false
  var expectShortcut: Bool = false
  var shortcut: String?
  var phrase: String?
  var result: [(shortcut: String, phrase: String)] = []

  func parser(
    _ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
    qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]
  ) {
    if expectArray && elementName == "array" {
      expectDict = true
    } else if expectDict && elementName == "dict" {
      expectPhrase = false
      expectShortcut = false
      shortcut = nil
      phrase = nil
    }
    currentKey = elementName
  }

  func parser(_ parser: XMLParser, foundCharacters string: String) {
    if currentKey == "key" {
      if string == "NSUserDictionaryReplacementItems" {
        expectArray = true
      } else if string == "with" {
        expectPhrase = true
      } else if string == "replace" {
        expectShortcut = true
      }
    } else if currentKey == "string" {
      if expectPhrase {
        phrase = string
        expectPhrase = false
      } else if expectShortcut {
        shortcut = string
        expectShortcut = false
      }
    }
  }

  func parser(
    _ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
    qualifiedName qName: String?
  ) {
    if expectArray && elementName == "array" {
      expectDict = false
      expectArray = false
    } else if expectDict && elementName == "dict" {
      if let shortcut = shortcut, let phrase = phrase {
        result.append((shortcut, phrase))
      }
    }
  }
}

func parseCustomPhraseXML(_ file: URL) -> [(shortcut: String, phrase: String)] {
  if let parser = XMLParser(contentsOf: file) {
    let delegate = CustomPhraseParserDelegate()
    parser.delegate = delegate
    if parser.parse() {
      return delegate.result
    }
  }
  return []
}
