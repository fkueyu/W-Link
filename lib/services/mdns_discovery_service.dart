import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:multicast_dns/multicast_dns.dart';
import '../models/wled_device.dart';
import '../models/wled_info.dart';

/// mDNS 设备发现服务
/// iOS: 使用原生 Bonjour API (通过 MethodChannel)
class MdnsDiscoveryService {
  static const _channel = MethodChannel('flux/mdns_discovery');

  StreamController<WledDevice>? _currentScanController;
  Timer? _scanTimer;
  MDnsClient? _dartMdnsClient;

  /// 扫描局域网中的 WLED 设备
  Stream<WledDevice> scanDevices({
    Duration duration = const Duration(seconds: 10),
  }) {
    // 停止之前的扫描
    stopScan();

    final controller = StreamController<WledDevice>();
    _currentScanController = controller;

    controller.onCancel = () {
      if (identical(_currentScanController, controller)) stopScan();
    };
    _startScan(controller, duration);
    return controller.stream;
  }

  bool _isCurrent(StreamController<WledDevice> controller) =>
      identical(_currentScanController, controller) && !controller.isClosed;

  void _fail(StreamController<WledDevice> controller, Object error) {
    if (!_isCurrent(controller)) return;
    controller.addError(error);
    stopScan();
  }

  Future<void> _startScan(
    StreamController<WledDevice> controller,
    Duration duration,
  ) async {
    Object? resolutionError;
    var found = false;
    _channel.setMethodCallHandler((call) async {
      if (!_isCurrent(controller)) return;
      if (call.method == 'onDeviceFound') {
        final args = call.arguments;
        if (args is Map &&
            args['ip'] is String &&
            (args['ip'] as String).isNotEmpty) {
          found = true;
        }
        _handleDeviceFound(call.arguments);
      } else if (call.method == 'onDiscoveryError') {
        final args = call.arguments;
        // 单个服务解析失败不终止其它服务的发现。
        if (args is Map && args['fatal'] == false) {
          resolutionError = PlatformException(
            code: 'resolution_failed',
            message: args.toString(),
          );
          return;
        }
        _fail(
          controller,
          PlatformException(code: 'discovery_failed', message: args.toString()),
        );
      }
    });
    _scanTimer = Timer(duration, () {
      if (!_isCurrent(controller)) return;
      if (resolutionError != null && !found) {
        _fail(controller, resolutionError!);
      } else {
        stopScan();
      }
    });
    try {
      if (Platform.isIOS || Platform.isMacOS) {
        await _channel.invokeMethod('startDiscovery');
      } else {
        await _scanUsingDartMdns(controller);
      }
    } catch (error) {
      _fail(controller, error);
    }
  }

  Future<void> _scanUsingDartMdns(
    StreamController<WledDevice> controller,
  ) async {
    final client = MDnsClient();
    _dartMdnsClient = client;
    try {
      await client.start();
      if (!_isCurrent(controller)) {
        client.stop();
        return;
      }
      final query = ResourceRecordQuery.serverPointer('_wled._tcp.local');
      await for (final ptr in client.lookup<PtrResourceRecord>(query)) {
        if (!_isCurrent(controller)) break;
        await for (final srv in client.lookup<SrvResourceRecord>(
          ResourceRecordQuery.service(ptr.domainName),
        )) {
          if (!_isCurrent(controller)) break;
          await for (final ip in client.lookup<IPAddressResourceRecord>(
            ResourceRecordQuery.addressIPv4(srv.target),
          )) {
            if (!_isCurrent(controller)) break;
            _handleDeviceFound({
              'name': ptr.domainName.split('.').first,
              'ip': ip.address.address,
              'port': srv.port,
            });
          }
        }
      }
    } catch (error) {
      _fail(controller, error);
    }
  }

  void _handleDeviceFound(dynamic arguments) {
    if (_currentScanController == null || _currentScanController!.isClosed) {
      return;
    }

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
    _scanTimer?.cancel();
    _scanTimer = null;
    final controller = _currentScanController;
    _currentScanController = null;
    if (controller != null && !controller.isClosed) controller.close();
    _channel.setMethodCallHandler(null);
    if (Platform.isIOS || Platform.isMacOS) {
      unawaited(
        _channel.invokeMethod<void>('stopDiscovery').catchError((Object _) {}),
      );
    }

    if (_dartMdnsClient != null) {
      _dartMdnsClient!.stop();
      _dartMdnsClient = null;
    }
  }

  /// 验证指定 IP 是否为 WLED 设备
  static Future<WledDevice?> verifyDevice(String ip, {int port = 80}) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      return await (() async {
        final request = await client.getUrl(
          Uri(scheme: 'http', host: ip, port: port, path: '/json/info'),
        );
        final response = await request.close();
        if (response.statusCode != 200) return null;
        final content = await response.transform(utf8.decoder).join();
        final json = jsonDecode(content) as Map<String, dynamic>;
        final name = json['name'] as String? ?? 'WLED $ip';
        // 与连接后读取设备信息使用同一解析契约，不能仅凭 HTTP 200
        // 和一个 name 就把普通 JSON 服务加入设备库。
        final info = WledInfo.fromJson({...json, 'name': name});
        if (info.ver.trim().isEmpty) return null;
        return WledDevice.manual(ip: ip, port: port, name: info.name);
      })().timeout(const Duration(seconds: 3));
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  void dispose() {
    stopScan();
  }
}
