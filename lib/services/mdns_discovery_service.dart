import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:multicast_dns/multicast_dns.dart';
import '../models/wled_device.dart';

/// mDNS 设备发现服务
/// iOS: 使用原生 Bonjour API (通过 MethodChannel)
class MdnsDiscoveryService {
  static const _channel = MethodChannel('flux/mdns_discovery');

  StreamController<WledDevice>? _currentScanController;
  bool _isScanning = false;
  MDnsClient? _dartMdnsClient;

  /// 扫描局域网中的 WLED 设备
  Stream<WledDevice> scanDevices({
    Duration duration = const Duration(seconds: 10),
  }) {
    // 停止之前的扫描
    stopScan();

    final controller = StreamController<WledDevice>();
    _currentScanController = controller;

    _startScan(duration);

    // 当监听者取消订阅时（例如页面退出），停止扫描
    controller.onCancel = () {
      stopScan();
    };

    return controller.stream;
  }

  Future<void> _startScan(Duration duration) async {
    if (_isScanning) return;
    _isScanning = true;

    // 1. 设置 MethodChannel 回调 (iOS/macOS)
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onDeviceFound') {
        _handleDeviceFound(call.arguments);
      }
    });

    try {
      // 2. 启动原生 mDNS 扫描
      if (Platform.isIOS || Platform.isMacOS) {
        debugPrint('[Discovery] Starting Native Bonjour Scan');
        await _channel.invokeMethod('startDiscovery');
      } else {
        // Android / Other: Use Dart multicast_dns
        _scanUsingDartMdns();
      }
    } catch (e) {
      debugPrint('[Discovery] Error starting scan: $e');
      stopScan();
    }

    // 3. 设置超时
    Future.delayed(duration, () {
      if (_isScanning) {
        debugPrint('[Discovery] Scan completed (timeout)');
        stopScan();
      }
    });
  }

  Future<void> _scanUsingDartMdns() async {
    debugPrint('[Discovery] Starting Dart mDNS Scan');
    _dartMdnsClient = MDnsClient();
    try {
      await _dartMdnsClient!.start();

      // 查找 _wled._tcp
      final query = ResourceRecordQuery.serverPointer('_wled._tcp.local');

      await for (final PtrResourceRecord ptr
          in _dartMdnsClient!.lookup<PtrResourceRecord>(query)) {
        if (!_isScanning) break;

        await for (final SrvResourceRecord srv
            in _dartMdnsClient!.lookup<SrvResourceRecord>(
              ResourceRecordQuery.service(ptr.domainName),
            )) {
          await for (final IPAddressResourceRecord ip
              in _dartMdnsClient!.lookup<IPAddressResourceRecord>(
                ResourceRecordQuery.addressIPv4(srv.target),
              )) {
            // 简单的名字处理: "WLED-123456._wled._tcp.local" -> "WLED-123456"
            final rawName = ptr.domainName.split('.').first;
            // 移除前面的Instance名可能包含的转义字符等（暂且简单处理）

            _handleDeviceFound({
              'name': rawName,
              'ip': ip.address.address,
              'port': srv.port,
            });
          }
        }
      }
    } catch (e) {
      debugPrint('[Discovery] Dart mDNS Error: $e');
    }
  }

  void _handleDeviceFound(dynamic arguments) {
    if (_currentScanController == null || _currentScanController!.isClosed)
      return;

    if (arguments is Map) {
      final name = arguments['name'] as String? ?? 'WLED Device';
      final ip = arguments['ip'] as String?;
      final port = arguments['port'] as int? ?? 80;

      if (ip != null && ip.isNotEmpty) {
        debugPrint('[Discovery] Found: $name @ $ip');
        _currentScanController?.add(
          WledDevice.fromMdns(name: name, ip: ip, port: port),
        );
      }
    }
  }

  void stopScan() {
    _isScanning = false;

    if (_currentScanController != null) {
      if (!_currentScanController!.isClosed) {
        _currentScanController!.close();
      }
      _currentScanController = null;
    }

    if (Platform.isIOS || Platform.isMacOS) {
      try {
        _channel.invokeMethod('stopDiscovery');
        _channel.setMethodCallHandler(null);
      } catch (_) {}
    }

    if (_dartMdnsClient != null) {
      _dartMdnsClient!.stop();
      _dartMdnsClient = null;
    }
  }

  /// 验证指定 IP 是否为 WLED 设备
  static Future<WledDevice?> verifyDevice(String ip, {int port = 80}) async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 3);
      final request = await client.getUrl(
        Uri.parse('http://$ip:$port/json/info'),
      );
      final response = await request.close();

      if (response.statusCode == 200) {
        return WledDevice.manual(ip: ip, port: port);
      }
    } catch (_) {
      // 设备不可达或不是 WLED
    }
    return null;
  }

  void dispose() {
    stopScan();
  }
}
