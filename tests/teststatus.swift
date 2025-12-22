func testPrefixForStatusItem() {
  assert(prefixForStatusItem("") == "🐧")
  assert(prefixForStatusItem("A") == "A")
  assert(prefixForStatusItem("拼") == "拼")
  assert(prefixForStatusItem("en") == "en")
  assert(prefixForStatusItem("双拼") == "双")
  assert(prefixForStatusItem("Bamboo") == "Ba")
}

@_cdecl("main")
func main() -> Int {
  testPrefixForStatusItem()
  return 0
}
