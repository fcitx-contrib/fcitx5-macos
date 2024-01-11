import SwiftUI

struct ContentView: View {
  var body: some View {
    Text("Fcitx5 macOS")
      .font(.title)
      .padding()
  }
}

class FcitxAbout: NSWindowController {
  convenience init() {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
      styleMask: [.titled, .closable],
      backing: .buffered, defer: false)
    window.contentView = NSHostingView(rootView: ContentView())
    window.center()
    self.init(window: window)
  }
}
