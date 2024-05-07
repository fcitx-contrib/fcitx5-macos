import Foundation

@_cdecl("main")
func main() -> Int {
  if CommandLine.argc != 2 {
    print("Usage: \(CommandLine.arguments[0]) <.plist file>")
    return 1
  }
  let url = URL(fileURLWithPath: CommandLine.arguments[1])
  let expected = [(shortcut: "msd", phrase: "马上到！"), (shortcut: "omw", phrase: "On my way!")]
  let actual = parseCustomPhraseXML(url)
  assert(actual.count == expected.count)
  for i in 0..<actual.count {
    assert(actual[i].shortcut == expected[i].shortcut)
    assert(actual[i].phrase == expected[i].phrase)
  }
  return 0
}
