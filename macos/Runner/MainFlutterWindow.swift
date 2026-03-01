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

    super.awakeFromNib()
  }
}
