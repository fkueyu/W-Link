import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flux/core/l10n.dart';
import 'package:flux/models/models.dart';
import 'package:flux/providers/common_providers.dart';
import 'package:flux/providers/device_providers.dart';
import 'package:flux/screens/device_control_screen.dart';
import 'package:flux/screens/device_list_screen.dart';
import 'package:flux/services/wled_api_service.dart';
import 'package:flux/widgets/device_settings_sheet.dart';

/// 动作摆放的判据：**每个动作在每种布局下都要可达，且只出现一次**。
///
/// 这一组守的是两个真缺陷（都在真机截图之前没人发现）：
///
/// 1. 设备列表的「加设备」原来是一个 `centerFloat` 浮动按钮，而双栏模式
///    下整个 `floatingActionButton` 被置成 `null` —— 宽屏上没有任何入口；
///    同时头部那个 `Icons.search_rounded` 的按钮语义是「搜索」，`onTap`
///    却去的是发现页（等于「加设备」）。
/// 2. 设备控制页的整条玻璃导航条写的是 `if (!widget.embedded)`，于是嵌入
///    模式连同「设备设置」的唯一入口一起被跳掉。
const WledDevice kDevice = WledDevice(
  id: 'device-1',
  name: '客厅灯带',
  originalName: 'WLED',
  ip: '10.0.0.9',
);

void main() {
  /// 外屏真实可用区（见 duo_postures_test 的注释）。
  const Size kNarrow = Size(382, 644);
  /// Duo 内屏。
  const Size kWide = Size(951, 669);

  Future<Override> preferencesOverride() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    return sharedPreferencesProvider.overrideWithValue(preferences);
  }

  Future<void> drain(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  void useViewport(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget listHost(Size size, {bool embedded = false}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          padding: const EdgeInsets.only(bottom: 34),
          disableAnimations: true,
        ),
        child: DeviceListScreen(
          onDeviceSelected: embedded ? (_) {} : null,
        ),
      ),
    );
  }

  group('设备列表的动作入口', () {
    testWidgets('窄屏：入口在头部动作条，且不再有底部浮动按钮', (tester) async {
      useViewport(tester, kNarrow);
      final preferences = await preferencesOverride();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [preferences, l10nProvider.overrideWithValue(ZhStrings())],
          child: listHost(kNarrow),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('device-list-add')), findsOneWidget);
      // 浮动按钮曾经承担这个入口；现在它必须彻底退场，
      // 否则「头+底」会出现两个做同一件事的按钮。
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).floatingActionButton,
        isNull,
      );

      await drain(tester);
    });

    testWidgets('双栏左栏：入口仍然可达（原来宽屏一个入口都没有）', (tester) async {
      useViewport(tester, kWide);
      final preferences = await preferencesOverride();
      // 有设备时也要能加设备：空列表由 EmptyState 兜底，会掩盖这个缺陷。
      final container = ProviderContainer(
        overrides: [
          preferences,
          // 设备卡片会 watch 会话 provider；不注入就会真的起 5 秒轮询，
          // 测试收尾时报「A Timer is still pending」。
          deviceSessionProvider.overrideWith(
            (ref, deviceId) => DeviceStateNotifier(
              null,
              ref,
              deviceId: deviceId,
              initialState: const WledState(on: true, bri: 128),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(deviceListProvider.notifier).addDevice(kDevice);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: listHost(kWide, embedded: true),
        ),
      );
      await tester.pump();

      expect(container.read(deviceListProvider), hasLength(1));
      expect(find.byKey(const ValueKey('device-list-add')), findsOneWidget);

      await drain(tester);
    });

    testWidgets('语义标签是「添加设备」，不是「搜索」', (tester) async {
      useViewport(tester, kNarrow);
      final preferences = await preferencesOverride();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [preferences, l10nProvider.overrideWithValue(ZhStrings())],
          child: listHost(kNarrow),
        ),
      );
      await tester.pump();

      // 读按钮内层 Semantics 的 label：`getSemantics(byKey)` 拿到的是
      // 最近的**祖先**节点，读不出按钮自己的标签。
      final button = tester.widget<Semantics>(
        find
            .descendant(
              of: find.byKey(const ValueKey('device-list-add')),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(button.properties.label, ZhStrings().addDevice);
      expect(button.properties.label, isNot(ZhStrings().search));

      await drain(tester);
    });
  });

  group('设备控制页的动作入口', () {
    Widget controlHost(
      Size size, {
      required bool embedded,
      required Override preferences,
    }) {
      return ProviderScope(
        overrides: [
          preferences,
          currentDeviceIdProvider.overrideWith((ref) => kDevice.id),
          deviceSessionProvider.overrideWith(
            (ref, deviceId) => DeviceStateNotifier(
              null,
              ref,
              deviceId: deviceId,
              initialState: const WledState(on: true, bri: 128),
            ),
          ),
          l10nProvider.overrideWithValue(ZhStrings()),
          // 设置面板要 `state` 和 `api` 都非空才肯打开；这里注入一个
          // 不联网的实例，只为了让入口可达性可断言。
          wledApiProvider.overrideWithValue(
            WledApiService(baseUrl: 'http://10.0.0.9'),
          ),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: size, disableAnimations: true),
            child: DeviceControlScreen(device: kDevice, embedded: embedded),
          ),
        ),
      );
    }

    testWidgets('嵌入模式：设置入口存在，且能打开设置面板', (tester) async {
      useViewport(tester, kWide);
      final preferences = await preferencesOverride();
      await tester.pumpWidget(
        controlHost(kWide, embedded: true, preferences: preferences),
      );
      await tester.pump();

      final entry = find.byKey(const ValueKey('device-settings-embedded'));
      expect(
        entry,
        findsOneWidget,
        reason: '嵌入模式原来连设置面板都打不开：玻璃条被整条跳过',
      );

      // 「贴右边缘、贴顶部」是这次改动的全部意义：动作条必须真的在右上，
      // 而不是随手放到内容里（那和没有 toolbar 一样）。
      final rect = tester.getRect(entry);
      expect(
        kWide.width - rect.right,
        lessThanOrEqualTo(40),
        reason: '动作条要贴右边缘：右边距 ${kWide.width - rect.right}pt',
      );
      expect(rect.top, lessThanOrEqualTo(80), reason: '动作条要贴顶部');

      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(find.byType(DeviceSettingsSheet), findsOneWidget);

      await drain(tester);
    });

    testWidgets('窄屏：不重复出现嵌入动作条', (tester) async {
      useViewport(tester, kNarrow);
      final preferences = await preferencesOverride();
      await tester.pumpWidget(
        controlHost(kNarrow, embedded: false, preferences: preferences),
      );
      await tester.pump();

      // 窄屏的设置入口在玻璃条里，已经有了；再来一条就是两个入口。
      expect(
        find.byKey(const ValueKey('device-settings-embedded')),
        findsNothing,
      );

      await drain(tester);
    });
  });
}
