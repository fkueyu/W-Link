import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// WLED UDP 控制服务
/// 使用 UDP 端口 21324 发送低延迟 Realtime 数据包 (DRGB / DDP)
/// 适合高频调光与实时刷帧，降低 ESP8266/ESP32 的 HTTP/JSON 处理开销
class WledUdpService {
  RawDatagramSocket? _socket;
  static const int wledUdpPort = 21324;

  Future<void> _ensureSocket() async {
    if (_socket != null) return;
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    } catch (e) {
      debugPrint('[WledUdpService] Failed to bind UDP socket: $e');
    }
  }

  /// 发送单色全阵列 DRGB 实时包
  /// [ipAddress] 目标设备 IP
  /// [r], [g], [b] 红色、绿色、蓝色值 (0-255)
  /// [timeoutSeconds] 实时模式超时恢复自动模式的时间 (秒，默认 2)
  Future<void> sendSolidColor({
    required String ipAddress,
    required int r,
    required int g,
    required int b,
    int timeoutSeconds = 2,
  }) async {
    await _ensureSocket();
    if (_socket == null) return;

    try {
      final target = InternetAddress(ipAddress);
      // DRGB 协议头:
      // Byte 0: 2 (DRGB)
      // Byte 1: 超时时间(秒)
      // Byte 2..4: R, G, B
      final packet = Uint8List.fromList([
        2,
        timeoutSeconds.clamp(1, 255),
        r.clamp(0, 255),
        g.clamp(0, 255),
        b.clamp(0, 255),
      ]);

      _socket?.send(packet, target, wledUdpPort);
    } catch (e) {
      debugPrint('[WledUdpService] Error sending UDP packet to $ipAddress: $e');
    }
  }

  /// 释放 Socket 资源
  void dispose() {
    _socket?.close();
    _socket = null;
  }
}

/// Provider
final wledUdpServiceProvider = Provider<WledUdpService>((ref) {
  final service = WledUdpService();
  ref.onDispose(() => service.dispose());
  return service;
});
