import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var bonjourBrowser: NetServiceBrowser?
  private var discoveredServices: [NetService] = []
  private var discoveryChannel: FlutterMethodChannel?

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
  
  override func applicationDidFinishLaunching(_ notification: Notification) {
    let controller: FlutterViewController = mainFlutterWindow?.contentViewController as! FlutterViewController
    discoveryChannel = FlutterMethodChannel(name: "flux/mdns_discovery", binaryMessenger: controller.engine.binaryMessenger)
    
    discoveryChannel?.setMethodCallHandler({ [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      switch call.method {
      case "startDiscovery":
        self?.startDiscovery(result: result)
      case "stopDiscovery":
        self?.stopDiscovery()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    })
    
    super.applicationDidFinishLaunching(notification)
  }
  
  private func startDiscovery(result: @escaping FlutterResult) {
    stopDiscovery()
    
    bonjourBrowser = NetServiceBrowser()
    bonjourBrowser?.delegate = self
    bonjourBrowser?.searchForServices(ofType: "_wled._tcp.", inDomain: "local.")
    
    result(true)
  }
  
  private func stopDiscovery() {
    bonjourBrowser?.stop()
    bonjourBrowser = nil
    for service in discoveredServices {
      service.stop()
    }
    discoveredServices.removeAll()
  }
}

// MARK: - NetServiceBrowserDelegate
extension AppDelegate: NetServiceBrowserDelegate {
  func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
    // print("[Bonjour] Found service: \(service.name)")
    discoveredServices.append(service)
    service.delegate = self
    service.resolve(withTimeout: 5.0)
  }
  
  func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
    print("[Bonjour] Search error: \(errorDict)")
  }
}

// MARK: - NetServiceDelegate
extension AppDelegate: NetServiceDelegate {
  func netServiceDidResolveAddress(_ sender: NetService) {
    guard let addresses = sender.addresses else { return }
    
    for addressData in addresses {
      var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
      
      addressData.withUnsafeBytes { ptr in
        let sockaddr = ptr.baseAddress!.assumingMemoryBound(to: sockaddr.self)
        getnameinfo(
          sockaddr,
          socklen_t(addressData.count),
          &hostname,
          socklen_t(hostname.count),
          nil,
          0,
          NI_NUMERICHOST
        )
      }
      
      let ipAddress = String(cString: hostname)
      
      // Only handle IPv4
      if ipAddress.contains(".") && !ipAddress.contains(":") {
        let device: [String: Any] = [
          "name": sender.name,
          "ip": ipAddress,
          "port": sender.port
        ]
        
        // print("[Bonjour] Resolved: \(sender.name) -> \(ipAddress):\(sender.port)")
        
        DispatchQueue.main.async { [weak self] in
          self?.discoveryChannel?.invokeMethod("onDeviceFound", arguments: device)
        }
        break
      }
    }
  }
  
  func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
    print("[Bonjour] Failed to resolve \(sender.name): \(errorDict)")
  }
}
