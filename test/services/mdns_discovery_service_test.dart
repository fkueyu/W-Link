import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flux/services/mdns_discovery_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flux/mdns_discovery');
  testWidgets('原生启动失败通过流传播', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'startDiscovery') {
            throw PlatformException(code: 'permission');
          }
          return null;
        });
    final service = MdnsDiscoveryService();
    final errors = <Object>[];
    service.scanDevices().listen((_) {}, onError: errors.add);
    await tester.pump();
    expect(errors, hasLength(1));
    service.dispose();
  });
  testWidgets('旧扫描定时器和订阅取消不关闭新扫描', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
    final service = MdnsDiscoveryService();
    final old = service
        .scanDevices(duration: const Duration(seconds: 1))
        .listen((_) {});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    var done = false;
    service
        .scanDevices(duration: const Duration(seconds: 3))
        .listen((_) {}, onDone: () => done = true);
    old.cancel();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(done, isFalse);
    service.dispose();
    await tester.pump();
    expect(done, isTrue);
  });
  Future<void> emit(
    WidgetTester tester,
    String method,
    Map<String, Object> args,
  ) async {
    tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(MethodCall(method, args)),
      (_) {},
    );
    await tester.pump();
  }

  testWidgets('全部解析失败显示错误，部分失败仍保留可发现设备', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
    final service = MdnsDiscoveryService();
    final errors = <Object>[];
    final devices = <Object>[];
    service
        .scanDevices(duration: const Duration(seconds: 1))
        .listen(devices.add, onError: errors.add);
    await tester.pump();
    await emit(tester, 'onDiscoveryError', {
      'fatal': false,
      'stage': 'resolve',
    });
    expect(errors, isEmpty);
    await tester.pump(const Duration(seconds: 1));
    expect(errors, hasLength(1));
    errors.clear();
    service
        .scanDevices(duration: const Duration(seconds: 1))
        .listen(devices.add, onError: errors.add);
    await tester.pump();
    await emit(tester, 'onDiscoveryError', {
      'fatal': false,
      'stage': 'resolve',
    });
    await emit(tester, 'onDeviceFound', {
      'ip': '10.0.0.9',
      'name': 'WLED',
      'port': 80,
    });
    await tester.pump(const Duration(seconds: 1));
    expect(devices, hasLength(1));
    expect(errors, isEmpty);
    service.dispose();
  });
  testWidgets('原生搜索失败立即传播并结束扫描', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
    final service = MdnsDiscoveryService();
    final errors = <Object>[];
    var done = false;
    service.scanDevices().listen(
      (_) {},
      onError: errors.add,
      onDone: () => done = true,
    );
    await tester.pump();
    await emit(tester, 'onDiscoveryError', {'fatal': true, 'stage': 'search'});
    expect(errors, hasLength(1));
    expect(done, isTrue);
    service.dispose();
    await tester.pump();
    await emit(tester, 'onDeviceFound', {'ip': '10.0.0.9'});
    expect(tester.takeException(), isNull);
  });
}
