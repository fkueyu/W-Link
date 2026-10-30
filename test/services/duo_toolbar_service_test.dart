import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flux/services/duo_toolbar_service.dart';

class _IosToolbarService extends DuoToolbarService {
  _IosToolbarService(MethodChannel channel) : super(channel: channel);
  @override
  bool get isSupported => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/duo_toolbar');
  late DuoToolbarService service;
  setUp(() => service = _IosToolbarService(channel));
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('按钮下发失败后，相同内容仍能重试', () async {
    var attempts = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          attempts++;
          if (attempts == 1) throw PlatformException(code: 'not_attached');
          return true;
        });
    for (var i = 0; i < 2; i++) {
      await service.setItems(addLabel: '添加', moreLabel: '更多', menu: []);
    }
    expect(attempts, 2);
  });

  test('显隐失败后，相同状态仍能重试', () async {
    var attempts = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          attempts++;
          if (attempts == 1) throw PlatformException(code: 'not_attached');
          return true;
        });
    await service.setVisible(true);
    await service.setVisible(true);
    expect(attempts, 2);
  });
}
