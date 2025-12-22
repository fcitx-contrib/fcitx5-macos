func prefixForStatusItem(_ text: String) -> String {
  if text.isEmpty { return "🐧" }
  let chars = Array(text)
  guard chars.count >= 2 else { return text }

  if chars[0].unicodeScalars.allSatisfy({ $0.isASCII }),
    chars[1].unicodeScalars.allSatisfy({ $0.isASCII })
  {
    return String(chars[0...1])
  }
  return String(chars[0])
}
