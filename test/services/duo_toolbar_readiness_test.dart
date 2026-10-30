import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flux/models/duo_geometry.dart';
import 'package:flux/providers/duo_providers.dart';
import 'package:flux/services/duo_toolbar_service.dart';

class _IosService extends DuoToolbarService {
  _IosService(MethodChannel channel) : super(channel: channel);
  @override
  bool get isSupported => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/duo_ready');
  const foldable = DuoGeometry(
    supported: true,
    attached: true,
    hinge: DuoHinge(status: DuoHingeStatus.closed, angleRadians: 0),
  );

  Future<ProviderContainer> containerFor(DuoGeometry geometry) async {
    final container = ProviderContainer(
      overrides: [
        duoGeometryProvider.overrideWith((ref) => Stream.value(geometry)),
        duoToolbarServiceProvider.overrideWithValue(_IosService(channel)),
      ],
    );
    addTearDown(container.dispose);
    await container.read(duoGeometryProvider.future);
    return container;
  }

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test('同版本普通手机不会请求安装系统壳', () async {
    var calls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          calls++;
          return {'attached': true};
        });
    final container = await containerFor(
      const DuoGeometry(supported: true, attached: true),
    );
    expect(await container.read(duoToolbarReadyProvider.future), isFalse);
    expect(calls, 0);
  });

  test('折叠设备必须收到成功安装握手才 ready，失败后可重试', () async {
    var calls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'ensureAttached');
          calls++;
          if (calls == 1) throw PlatformException(code: 'not_attached');
          return {'attached': true};
        });
    final container = await containerFor(foldable);
    expect(await container.read(duoToolbarReadyProvider.future), isFalse);
    container.invalidate(duoToolbarReadyProvider);
    expect(await container.read(duoToolbarReadyProvider.future), isTrue);
    expect(calls, 2);
  });

  test('原生未附着时保持 Flutter 入口所需的 false', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => {'attached': false});
    final container = await containerFor(foldable);
    expect(await container.read(duoToolbarReadyProvider.future), isFalse);
  });
}
