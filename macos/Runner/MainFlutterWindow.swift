import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // 窗口配置
    self.title = "W-Link"
    self.setContentSize(NSSize(width: 960, height: 680))
    self.minSize = NSSize(width: 520, height: 480)
    self.styleMask = [.titled, .closable, .miniaturizable, .resizable]
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    let infoChannel = FlutterMethodChannel(name: "flux/app_info", binaryMessenger: flutterViewController.engine.binaryMessenger)
    infoChannel.setMethodCallHandler { call, result in
      if call.method == "getAppVersion" {
        result(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}
