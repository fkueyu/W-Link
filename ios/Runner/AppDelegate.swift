import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var bonjourBrowser: NetServiceBrowser?
  private var discoveredServices: [NetService] = []
  private var resolvedDevices: [[String: Any]] = []
  private var discoveryChannel: FlutterMethodChannel?
  private var pendingResult: FlutterResult?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // 使用 registrar API 获取 messenger，避免 rootViewController 访问警告
    if let registrar = self.registrar(forPlugin: "flux/mdns_discovery") {
      discoveryChannel = FlutterMethodChannel(
        name: "flux/mdns_discovery",
        binaryMessenger: registrar.messenger()
      )
      
      discoveryChannel?.setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "startDiscovery":
          self?.startDiscovery(result: result)
        case "stopDiscovery":
          self?.stopDiscovery()
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func startDiscovery(result: @escaping FlutterResult) {
    // 清理之前的状态
    stopDiscovery()
    
    bonjourBrowser = NetServiceBrowser()
    bonjourBrowser?.delegate = self
    bonjourBrowser?.searchForServices(ofType: "_wled._tcp.", inDomain: "local.")
    
    // 立即返回成功，真正的结果通过 onDeviceFound 异步发送
    result(true)
  }
  
  private func stopDiscovery() {
    bonjourBrowser?.stop()
    bonjourBrowser = nil
    for service in discoveredServices {
      service.stop()
    }
    discoveredServices = []
  }

  // MARK: UISceneSession Lifecycle
  override func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
    return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
  }

  override func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
  }
}

// MARK: - NetServiceBrowserDelegate
extension AppDelegate: NetServiceBrowserDelegate {
  func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
    print("[Bonjour] Found service: \(service.name)")
    discoveredServices.append(service)
    service.delegate = self
    // 立即开始解析地址
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
        guard let sockaddr_ptr = ptr.baseAddress?.assumingMemoryBound(to: sockaddr.self) else { return }
        let sockaddr_len = socklen_t(addressData.count)
        
        if getnameinfo(
          sockaddr_ptr,
          sockaddr_len,
          &hostname,
          socklen_t(hostname.count),
          nil,
          0,
          NI_NUMERICHOST
        ) == 0 {
          let ipAddress = String(cString: hostname)
          
          // 只处理 IPv4 地址
          if ipAddress.contains(".") && !ipAddress.contains(":") {
            let device: [String: Any] = [
              "name": sender.name,
              "ip": ipAddress,
              "port": sender.port
            ]
            
            print("[Bonjour] Resolved: \(sender.name) -> \(ipAddress):\(sender.port)")
            
            // 实时发送给 Flutter
            DispatchQueue.main.async { [weak self] in
              self?.discoveryChannel?.invokeMethod("onDeviceFound", arguments: device)
            }
          }
        }
      }
    }
  }
  
  func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
    print("[Bonjour] Failed to resolve \(sender.name): \(errorDict)")
  }
}
