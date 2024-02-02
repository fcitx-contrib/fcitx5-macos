@testable import Fcitx
import SwiftyJSON

@_cdecl("main")
func main() {
  start_fcitx_thread()
  try! testGetConfigFromFcitx()
  try! testDecode()
  stop_fcitx_thread()
}

func testGetConfigFromFcitx() throws {
  let _ = try getConfig(uri: "fcitx://config/global")

  do {
    let _ = try getConfig(uri: "fcitx://NOT-FOUND");
  } catch is FcitxConfigError {
    assert(true)
  } catch {
    assert(false)
  }
}

func testDecode() throws {
  // empty object
  try {
    let json = JSON(parseJSON: #"null"#)
    let cfg = try parseJSON(json, "")
    switch cfg.kind {
    case .group(_): assert(true)
    case .option(_): assert(false)
    }
  }();

  // path
  try {
    let json = JSON(parseJSON: #"{"A": {"Description": "inside a" , "B": {"Description": "inside b", "C": {"Description": "inside c"}}}}"#)
    let root = try parseJSON(json, "root")
    switch root.kind{
    case .option: assert(false)
    case .group(let rootchildren):
      assert(rootchildren.count == 1)
      let a = rootchildren[0]
      assert(a.description == "inside a")
      assert(a.path == "root/A")
      switch a.kind {
      case .option(_): assert(false)
      case .group(let achildren):
        assert(achildren.count == 1)
        let b = achildren[0]
        assert(b.description == "inside b")
        assert(b.path == "root/A/B")
        switch b.kind {
        case .option(_): assert(false)
        case .group(let bchildren):
          assert(bchildren.count == 1)
          let c = bchildren[0]
          assert(c.description == "inside c")
          assert(c.path == "root/A/B/C")
        }
      }
    }
  }()

  // Boolean
  try {
    let json = JSON(parseJSON: #"{"Type": "Boolean", "Value": "True", "DefaultValue": "False", "Description": "bool"}"#)
    let cfg = try parseJSON(json, "")
    assert(cfg.description == "bool")
    switch cfg.kind {
    case .option(let opt as BooleanOption):
      assert(opt.defaultValue == false)
      assert(opt.value == true)
    case .group(_): assert(false)
    case .option(_): assert(false)
    }
  }();

  // Integer
  try {
    let json = JSON(parseJSON: #"{"Type": "Integer", "Value": "100", "DefaultValue": "0", "IntMin": "0", "IntMax": "1000", "Description": "int"}"#)
    let cfg = try parseJSON(json, "")
    assert(cfg.description == "int")
    switch cfg.kind {
    case .option(let opt as IntegerOption):
      assert(opt.defaultValue == 0)
      assert(opt.value == 100)
      assert(opt.min == 0)
      assert(opt.max == 1000)
    case .group(_): assert(false)
    case .option(_): assert(false)
    }
  }();

  // String
  try {
    let json = JSON(parseJSON: #"{"Type": "String", "Value": "Hello Fcitx", "DefaultValue": "HSN", "Description": "str"}"#)
    let cfg = try parseJSON(json, "")
    assert(cfg.description == "str")
    switch cfg.kind {
    case .option(let opt as StringOption):
      assert(opt.defaultValue == "HSN")
      assert(opt.value == "Hello Fcitx")
    case .group(_): assert(false)
    case .option(_): assert(false)
    }
  }();

  // Enum
  try {
    let json = JSON(parseJSON: #"{"Type": "Enum", "Value": "No", "DefaultValue": "Yes", "Enum": {"0": "Yes", "1": "No"},  "EnumI18n": {"0": "是", "1": "否"}, "Description": "enum"}"#)
    let cfg = try parseJSON(json, "")
    assert(cfg.description == "enum")
    switch cfg.kind {
    case .option(let opt as EnumOption):
      assert(opt.defaultValue == "Yes")
      assert(opt.value == "No")
    case .group(_): assert(false)
    case .option(_): assert(false)
    }
  }();
}