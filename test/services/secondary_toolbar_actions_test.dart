import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flux/services/duo_toolbar_service.dart';

class IosToolbar extends DuoToolbarService {
  IosToolbar(MethodChannel channel) : super(channel: channel);
  @override
  bool get isSupported => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/secondary_toolbar_actions');
  late Map payload;
  late IosToolbar service;
  setUp(() {
    service = IosToolbar(channel);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          payload = call.arguments as Map;
          return true;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test('菜单项默认启用且未选中', () {
    final entry = const DuoToolbarMenuEntry(id: 'refresh', title: '刷新').toMap();
    expect(entry['enabled'], true);
    expect(entry['selected'], false);
  });

  test('页面动作默认保持现有按钮且非危险非忙碌', () async {
    await service.setItems(addLabel: '新建', moreLabel: '更多', menu: []);
    expect(payload['showPrimary'], true);
    expect(payload['addDestructive'], false);
    expect(payload['addBusy'], false);
  });

  test('危险、忙碌、无主动作及菜单选中变化完整下发', () async {
    await service.setItems(
      addLabel: '重置',
      moreLabel: '更多',
      menu: const [
        DuoToolbarMenuEntry(
          id: 'slot',
          title: '槽位',
          enabled: false,
          selected: true,
        ),
      ],
      showPrimary: false,
      addDestructive: true,
      addBusy: true,
    );
    expect(payload['showPrimary'], false);
    expect(payload['addDestructive'], true);
    expect(payload['addBusy'], true);
    expect((payload['menu'] as List).single['enabled'], false);
    expect((payload['menu'] as List).single['selected'], true);
    await service.setItems(
      addLabel: '重置',
      moreLabel: '更多',
      menu: const [
        DuoToolbarMenuEntry(
          id: 'slot',
          title: '槽位',
          enabled: true,
          selected: false,
        ),
      ],
      showPrimary: false,
      addDestructive: true,
      addBusy: true,
    );
    expect((payload['menu'] as List).single['enabled'], true);
    expect((payload['menu'] as List).single['selected'], false);
  });
}
