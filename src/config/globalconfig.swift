import Logging
import SwiftUI

class GlobalConfigController: NSWindowController {
  convenience init() {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
      styleMask: [.titled, .closable],
      backing: .buffered, defer: false)
    window.title = "Global Config"
    window.center()
    self.init(window: window)
    do {
      let configModel = try getGlobalConfig()
      window.contentView = NSHostingView(rootView: GlobalConfigView(model: configModel))
    } catch {
      window.contentView = NSHostingView(
        rootView: Text("Cannot show global options: \(String(describing: error))"))
    }
  }
}

struct GlobalConfigView: View {
  let model: Config
  var body: some View {
    VStack {
      ScrollView {
        buildView(config: model)
      }
      HStack {
        Spacer()
        Button("Print") {
          // Should see changes.
          print(model)
        }
      }
    }.padding()
  }
}
