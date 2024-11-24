import Carbon

let arguments = CommandLine.arguments

if arguments.count < 2 {
  exit(1)
}

let im = arguments[1]

let conditions = NSMutableDictionary()
conditions.setValue(im, forKey: kTISPropertyInputSourceID as String)
if let array = TISCreateInputSourceList(conditions, true)?.takeRetainedValue()
  as? [TISInputSource]
{
  for inputSource in array {
    TISSelectInputSource(inputSource)
    exit(0)
  }
}
