import SwiftUI

struct ContentView: View {
  var body: some View {
    Text("Hello, SwiftUI Dialog!")
      .padding()
  }
}

class FcitxAbout {
  static var window: NSWindow?

  static func show() {
    if FcitxAbout.window == nil {
      FcitxAbout.window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
        styleMask: [.titled, .closable, .resizable],
        backing: .buffered, defer: false)
    }
    FcitxAbout.window!.contentView = NSHostingView(rootView: ContentView())
    FcitxAbout.window!.makeKeyAndOrderFront(nil)
  }
}
