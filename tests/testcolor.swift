import AppKit

func grayScale(gray: CGFloat, alpha: CGFloat) -> NSColor {
  let components: [CGFloat] = [gray, alpha]
  return NSColor(cgColor: CGColor(colorSpace: CGColorSpaceCreateDeviceGray(), components: components)!)!
}

func testSRGB() {
  let sRGBColor = NSColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 0.4)
  assert(sRGBColor.cgColor.components?.count == 4)
  assert(nsColorToString(sRGBColor) == "#1A334D66")
}

func testGrayScale() {
  let grayColor = grayScale(gray: 0.5, alpha: 1.0)
  assert(grayColor.cgColor.components?.count == 2)
  assert(nsColorToString(grayColor) == "#808080FF")
}

func testGetAccentColor() {
  let accentColor = getAccentColor("com.apple.Notes")
  assert(accentColor == "#FCB827FF")
}

@_cdecl("main")
func main() -> Int {
  testGrayScale()
  testSRGB()
  testGetAccentColor()
  return 0
}
