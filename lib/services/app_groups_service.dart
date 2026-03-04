import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import '../models/wled_device.dart';

/// App Groups 数据同步服务
/// 将设备列表同步到 App Groups UserDefaults，供 iOS App Intents 读取
class AppGroupsService {
  static const _channel = MethodChannel('flux/app_groups');

  /// 同步设备列表到 App Groups
  static Future<void> syncDevices(List<WledDevice> devices) async {
    if (!Platform.isIOS) return;

    try {
      final deviceList = devices
          .map((d) => {'id': d.id, 'name': d.name, 'ip': d.ip, 'port': d.port})
          .toList();

      await _channel.invokeMethod('syncDevices', {
        'devices': jsonEncode(deviceList),
      });
    } catch (e) {
      // App Groups 不可用时静默失败，不影响主功能
    }
  }
}
