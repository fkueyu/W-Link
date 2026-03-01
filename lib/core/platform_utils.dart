import 'dart:io';
import 'package:flutter/services.dart';

/// 平台工具类
class PlatformUtils {
  PlatformUtils._();

  /// 是否为桌面平台
  static bool get isDesktop =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  /// 是否为移动平台
  static bool get isMobile => Platform.isIOS || Platform.isAndroid;

  /// 平台感知的触觉反馈（桌面端静默跳过）
  static void hapticLight() {
    if (isMobile) HapticFeedback.lightImpact();
  }

  static void hapticMedium() {
    if (isMobile) HapticFeedback.mediumImpact();
  }

  static void hapticHeavy() {
    if (isMobile) HapticFeedback.heavyImpact();
  }
}
