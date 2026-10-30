import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 读取当前安装包元数据，避免与构建版本或 --build-name 覆盖值不一致。
final appVersionProvider = FutureProvider<String?>((ref) async {
  try {
    final version = await const MethodChannel(
      'flux/app_info',
    ).invokeMethod<String>('getAppVersion');
    return version == null || version.trim().isEmpty ? null : version;
  } on MissingPluginException {
    return null;
  } on PlatformException {
    return null;
  }
});
