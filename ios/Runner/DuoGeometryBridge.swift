//
//  DuoGeometryBridge.swift
//  Runner
//
//  折叠屏几何桥：把 UIKit 的铰链状态与保留分区（折叠线、摄像头遮挡）暴露给 Dart。
//
//  为什么需要它：Flutter 引擎在 iOS 上不提供折叠信息——
//  `ViewConfiguration.displayFeatures` 的官方文档写明「只在 Android 填充」，
//  iOS 上恒为空数组。折叠线位置与铰链角只能从 UIKit 取：
//    · `UIHingeInteraction`（iOS 27.1 起）给出铰链状态与角度（弧度）；
//    · `UIView.reservedRegions(of:)`（iOS 27.1 起）给出「分区」与「遮挡」两类保留区，
//      frame 在**被查询视图的坐标系**里，与 Flutter 的逻辑像素 1:1 对应。
//
//  通道：MethodChannel("flux/duo")
//    → getGeometry   返回当前几何快照
//    ← onHinge       铰链变化时主动推送（载荷与快照里的 hinge 同构）
//
//  低于 iOS 27.1 时快照为 {"supported": false}，Dart 侧按「没有折叠信息」处理，
//  布局回落到普通 iPhone 逻辑——即不引入任何行为变化。
//

import Flutter
import UIKit

final class DuoGeometryBridge {
  static let channelName = "flux/duo"

  private let channel: FlutterMethodChannel
  private weak var attachedView: UIView?
  private var hingeInteraction: AnyObject?
  private var lastHinge: [String: Any]?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: DuoGeometryBridge.channelName,
      binaryMessenger: messenger
    )

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(nil)
        return
      }
      switch call.method {
      case "getGeometry":
        result(self.geometrySnapshot())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // MARK: - 快照

  private func geometrySnapshot() -> [String: Any] {
    guard #available(iOS 27.1, *) else {
      return ["supported": false, "reason": "ios_below_27_1"]
    }

    guard let view = resolveHostView() else {
      // 视图还没挂上（启动早期）：Dart 侧会重试，这里如实报未附着。
      return ["supported": true, "attached": false]
    }

    attachHingeIfNeeded(to: view)

    var snapshot: [String: Any] = [
      "supported": true,
      "attached": true,
      "viewWidth": Double(view.bounds.width),
      "viewHeight": Double(view.bounds.height),
      "scale": Double(view.contentScaleFactor),
      "divisions": regionPayloads(in: view, kind: __UIViewReservedRegionKind.division()),
      "occlusions": regionPayloads(in: view, kind: __UIViewReservedRegionKind.occlusion()),
    ]
    if let hinge = lastHinge {
      snapshot["hinge"] = hinge
    }
    return snapshot
  }

  /// 保留区一律带 `active` 标志返回：非活动分区的 frame 没有意义，由 Dart 侧过滤。
  @available(iOS 27.1, *)
  private func regionPayloads(
    in view: UIView,
    kind: __UIViewReservedRegionKind
  ) -> [[String: Any]] {
    let regions = view.__reservedRegions(of: kind, options: .includeInactive)
    return regions.map { region in
      let frame = region.frame
      let margins = region.margins
      return [
        "x": Double(frame.origin.x),
        "y": Double(frame.origin.y),
        "width": Double(frame.size.width),
        "height": Double(frame.size.height),
        "insetTop": Double(margins.top),
        "insetLeft": Double(margins.left),
        "insetBottom": Double(margins.bottom),
        "insetRight": Double(margins.right),
        "active": region.isActive,
      ]
    }
  }

  // MARK: - 铰链

  private func attachHingeIfNeeded(to view: UIView) {
    guard #available(iOS 27.1, *) else { return }
    if hingeInteraction != nil && attachedView === view { return }

    let interaction = UIHingeInteraction { [weak self] _, update in
      guard let self = self else { return }
      // update.hinge 为 nil 表示离开了能提供铰链信息的层级。
      guard let hinge = update.hinge else {
        self.lastHinge = nil
        self.channel.invokeMethod("onHinge", arguments: NSNull())
        return
      }
      let payload = self.hingePayload(hinge)
      self.lastHinge = payload
      self.channel.invokeMethod("onHinge", arguments: payload)
    }

    view.addInteraction(interaction)
    hingeInteraction = interaction
    attachedView = view
  }

  @available(iOS 27.1, *)
  private func hingePayload(_ hinge: UIHinge) -> [String: Any] {
    let status: String
    switch hinge.status {
    case .closed:
      status = "closed"
    case .partiallyOpen:
      status = "partiallyOpen"
    case .fullyOpen:
      status = "fullyOpen"
    default:
      status = "unknown"
    }
    return [
      "status": status,
      "statusRaw": hinge.status.rawValue,
      "angleRadians": Double(hinge.angle),
    ]
  }

  // MARK: - 宿主视图

  /// Flutter 的绘制面就是 FlutterViewController 的 view；保留区坐标以它为基准。
  private func resolveHostView() -> UIView? {
    if let view = attachedView, view.window != nil {
      return view
    }

    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let ordered = scenes.sorted { lhs, rhs in
      (lhs.activationState == .foregroundActive) && (rhs.activationState != .foregroundActive)
    }

    // 先找 keyWindow，再退到任意 window。
    for preferKey in [true, false] {
      for scene in ordered {
        for window in scene.windows where !preferKey || window.isKeyWindow {
          if let controller = window.rootViewController as? FlutterViewController {
            return controller.view
          }
        }
      }
    }
    return nil
  }
}
