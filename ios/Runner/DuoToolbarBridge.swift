//
//  DuoToolbarBridge.swift
//  Runner
//
//  B 方案探针：把 Flutter 内容装进 `UINavigationController`，让「添加设备 / 更多」
//  变成真正的 `UIBarButtonItem`。
//
//  为什么需要它：Duo 上「工具栏竖排到右侧」是 **系统条** 的摆位行为，只有
//  `UINavigationBar` 里的 item 才会被系统搬迁。Flutter 自绘的按钮行在系统眼里
//  只是普通视图内容，换 SDK 也不会移动。这一点已在 `DuoGeometryBridge` 的
//  遮挡区数据上验证过（右侧 84pt 保留区与引擎 padding 完全一致）。
//
//  通道：MethodChannel("flux/duo_toolbar")
//    → setVisible   {visible}            显示/隐藏系统栏
//    → setItems     {addLabel, moreLabel, menu:[{id,title,symbol,destructive}]}
//    ← onAddTap                          系统「+」被点击
//    ← onMenuSelect {id}                系统下拉菜单某项被选中
//    → isAttached                        探针用：确认壳是否真的装上了
//
//  设计约定：**默认隐藏**。壳装上后立刻 `setNavigationBarHidden(true)`，
//  只有 Dart 侧明确要求时才显示——非折叠设备的行为与改动前逐像素一致。
//

import Flutter
import UIKit

final class DuoToolbarBridge: NSObject {
  static let channelName = "flux/duo_toolbar"

  private let channel: FlutterMethodChannel
  private weak var navigationController: UINavigationController?

  /// 系统栏是否已显示。`nil` 表示从未设置过。
  private var barVisible: Bool?

  /// 最近一次下发的菜单项，重建 `UIMenu` 时复用。
  private var menuSpec: [[String: Any]] = []

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: DuoToolbarBridge.channelName,
      binaryMessenger: messenger
    )
    super.init()

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(nil)
        return
      }
      switch call.method {
      case "ensureAttached":
        result(["attached": self.attachIfNeeded()])
      case "setVisible":
        let args = call.arguments as? [String: Any]
        result(self.setVisible(args?["visible"] as? Bool ?? false))
      case "setItems":
        let args = (call.arguments as? [String: Any]) ?? [:]
        result(self.applyItems(args))
      case "isAttached":
        result(["attached": self.navigationController?.view.window != nil])
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // MARK: - 装壳

  /// 把当前窗口的根视图包进 `UINavigationController`。
  ///
  /// 顺序很关键：先让一个**空**的 nav 成为根，再把原根塞进去。
  /// 反过来（先 `UINavigationController(rootViewController: root)` 再赋给窗口）
  /// 会让 UIKit 把 root 的 view 从 nav 里摘走，界面直接空白。
  @discardableResult
  func attachIfNeeded() -> Bool {
    guard #available(iOS 27.1, *) else { return false }
    if let nav = navigationController, nav.view.window != nil {
      return true
    }
    guard let window = Self.keyWindow(), let root = window.rootViewController else {
      return false
    }
    if let nav = root as? UINavigationController {
      navigationController = nav
      return true
    }

    // ⚠️ 顺序不能反，两条路都试过：
    //
    // `UINavigationController(rootViewController: root)` 之后再赋给窗口，UIKit
    // 会把「旧根」的 view 从它的 superview 里摘掉——此时旧根的 superview 已经
    // 是 nav.view，于是 Flutter 视图被移出去，`root.view.superview == nil`、
    // frame 变成 `{inf, inf, 0, 0}`，屏幕全黑。
    //
    // 正确顺序：先让**空** nav 成为窗口根（被替换掉的是 root 自己，移除的是它
    // 挂在 window 上的 view），再把 root 放进 nav。
    let nav = UINavigationController()
    nav.setNavigationBarHidden(true, animated: false)
    nav.navigationBar.prefersLargeTitles = false

    window.rootViewController = nav
    nav.setViewControllers([root], animated: false)

    // 兜底：任何路径上 root.view 没挂上，手动补回去，宁可丑也不能黑屏。
    if root.view.superview == nil {
      root.view.frame = nav.view.bounds
      root.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      nav.view.addSubview(root.view)
    }

    NSLog(
      "[DuoToolbar] attach ok superview=%@ nav=%@ root=%@",
      root.view.superview.map { String(describing: type(of: $0)) } ?? "nil",
      NSCoder.string(for: nav.view.frame),
      NSCoder.string(for: root.view.frame)
    )

    navigationController = nav
    barVisible = false
    return nav.view.window != nil && root.view.window != nil
  }

  private static func keyWindow() -> UIWindow? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    for scene in scenes {
      if let window = scene.windows.first(where: { $0.isKeyWindow }) {
        return window
      }
    }
    for scene in scenes {
      if let window = scene.windows.first {
        return window
      }
    }
    return nil
  }

  // MARK: - 系统栏

  private func setVisible(_ visible: Bool) -> Bool {
    guard let nav = navigationController, nav.view.window != nil else { return false }
    guard barVisible != visible else { return true }
    nav.setNavigationBarHidden(!visible, animated: false)
    barVisible = visible
    if visible {
      applyBarAppearance(nav.navigationBar)
    }
    return true
  }

  /// 系统栏外观：透明底 + 品牌色 tint。
  ///
  /// 用透明底而不是系统默认的毛玻璃，是为了让它能浮在我们的渐变背景上；
  /// 这一点正是本探针要判断的东西——如果透明底仍然「像贴了一张系统条」，
  /// 说明 B 方案的代价被低估了。
  private func applyBarAppearance(_ bar: UINavigationBar) {
    let appearance = UINavigationBarAppearance()
    appearance.configureWithTransparentBackground()
    appearance.titleTextAttributes = [.foregroundColor: UIColor.clear]

    bar.standardAppearance = appearance
    bar.scrollEdgeAppearance = appearance
    bar.compactAppearance = appearance
    // 品牌紫（FluxTheme.primary = 0xFFAF47FF），与自绘按钮同色。
    bar.tintColor = UIColor(red: 0.686, green: 0.278, blue: 1.0, alpha: 1.0)
  }

  // MARK: - 按钮

  private func applyItems(_ args: [String: Any]) -> Bool {
    guard let nav = navigationController, nav.view.window != nil,
          let controller = nav.topViewController else { return false }

    let addLabel = args["addLabel"] as? String ?? "Add"
    let moreLabel = args["moreLabel"] as? String ?? "More"
    let backLabel = args["backLabel"] as? String
    let addSymbol = args["addSymbol"] as? String ?? "plus"
    let addEnabled = args["addEnabled"] as? Bool ?? true
    let showMenu = args["showMenu"] as? Bool ?? true
    let showPrimary = args["showPrimary"] as? Bool ?? true
    let addDestructive = args["addDestructive"] as? Bool ?? false
    let addBusy = args["addBusy"] as? Bool ?? false
    menuSpec = (args["menu"] as? [[String: Any]]) ?? []

    let addItem = UIBarButtonItem(
      image: UIImage(systemName: addSymbol),
      primaryAction: UIAction(title: addLabel, attributes: addDestructive ? .destructive : []) { [weak self] _ in
        self?.channel.invokeMethod("onAddTap", arguments: nil)
      }
    )
    addItem.accessibilityLabel = addLabel
    addItem.isEnabled = addEnabled

    if let backLabel = backLabel {
      let backItem = UIBarButtonItem(
        image: UIImage(systemName: "chevron.backward"),
        primaryAction: UIAction { [weak self] _ in
          self?.channel.invokeMethod("onBackTap", arguments: nil)
        }
      )
      backItem.accessibilityLabel = backLabel
      controller.navigationItem.leftBarButtonItem = backItem
    } else {
      controller.navigationItem.leftBarButtonItem = nil
    }

    let moreItem = UIBarButtonItem(
      image: UIImage(systemName: "ellipsis"),
      menu: buildMenu()
    )
    moreItem.accessibilityLabel = moreLabel

    var rightItems: [UIBarButtonItem] = []
    if showMenu { rightItems.append(moreItem) }
    if showPrimary {
      if addBusy {
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.isAccessibilityElement = true
        spinner.accessibilityLabel = addLabel
        spinner.startAnimating()
        rightItems.append(UIBarButtonItem(customView: spinner))
      } else {
        rightItems.append(addItem)
      }
    }
    controller.navigationItem.rightBarButtonItems = rightItems
    // 标题留空：品牌信息由 Flutter 自己的头部承担，系统栏只放动作。
    controller.navigationItem.title = ""
    return true
  }

  private func buildMenu() -> UIMenu {
    let actions: [UIAction] = menuSpec.map { entry in
      let id = entry["id"] as? String ?? ""
      let title = entry["title"] as? String ?? id
      let symbol = entry["symbol"] as? String
      let isDestructive = entry["destructive"] as? Bool ?? false
      let isEnabled = entry["enabled"] as? Bool ?? true
      let isSelected = entry["selected"] as? Bool ?? false
      var attributes: UIMenuElement.Attributes = []
      if isDestructive { attributes.insert(.destructive) }
      if !isEnabled { attributes.insert(.disabled) }

      return UIAction(
        title: title,
        image: symbol.flatMap { UIImage(systemName: $0) },
        attributes: attributes,
        state: isSelected ? .on : .off
      ) { [weak self] _ in
        self?.channel.invokeMethod("onMenuSelect", arguments: ["id": id])
      }
    }
    return UIMenu(title: "", children: actions)
  }
}
