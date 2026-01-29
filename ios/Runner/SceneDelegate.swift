import UIKit
import Flutter

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // 如果你的项目有特殊的启动逻辑可以在这里处理
        // 对于标准的 Flutter 项目，这里通常保持默认即可
        guard let _ = (scene as? UIWindowScene) else { return }
    }
}
