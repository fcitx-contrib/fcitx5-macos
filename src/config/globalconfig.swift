import Fcitx
import Logging
import SwiftUI

class GlobalConfigController: ConfigWindowController {
  convenience init() {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
      styleMask: [.titled, .closable],
      backing: .buffered, defer: false)
    window.title = NSLocalizedString("Global Config", comment: "")
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
        Button {
          model.resetToDefault()
        } label: {
          Text("Reset to default")
        }
        Spacer()
        Button {
          save()
        } label: {
          Text("Apply")
        }
        Button {
          save()
          FcitxInputController.globalConfigController.window?.performClose(_: nil)
        } label: {
          Text("OK")
        }
      }
    }.padding()
  }

  private func save() {
    Fcitx.setConfig("fcitx://config/global", model.encodeValue())
  }
}
