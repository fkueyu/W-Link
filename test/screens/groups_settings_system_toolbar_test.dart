import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flux/core/l10n.dart';
import 'package:flux/models/duo_geometry.dart';
import 'package:flux/providers/providers.dart';
import 'package:flux/providers/app_info_provider.dart';
import 'package:flux/screens/groups_management_screen.dart';
import 'package:flux/screens/settings_screen.dart';
import 'package:flux/services/duo_toolbar_service.dart';

class _SupportedToolbar extends DuoToolbarService {
  _SupportedToolbar(MethodChannel channel) : super(channel: channel);

  @override
  bool get isSupported => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/groups_settings_toolbar');
  final calls = <MethodCall>[];
  final l10n = ZhStrings();

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'ensureAttached' ? {'attached': true} : true;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<SharedPreferences> host(
    WidgetTester tester,
    Widget page, {
    bool ready = true,
  }) async {
    tester.view.physicalSize = const Size(466, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'toolbar_test_sentinel': '保留'});
    final prefs = await SharedPreferences.getInstance();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          l10nProvider.overrideWithValue(l10n),
          appVersionProvider.overrideWith((ref) async => '1.0.0'),
          duoToolbarServiceProvider.overrideWithValue(
            _SupportedToolbar(channel),
          ),
          duoToolbarReadyProvider.overrideWith((ref) async => ready),
          duoGeometryProvider.overrideWith(
            (ref) => Stream.value(DuoGeometry.unsupported),
          ),
        ],
        child: MaterialApp(
          navigatorKey: navigator,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const Scaffold(body: Text('上一级')),
        ),
      ),
    );
    navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => page));
    await tester.pumpAndSettle();
    return prefs;
  }

  Future<void> nativeTap(WidgetTester tester, String method) async {
    tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(MethodCall(method)),
      (_) {},
    );
    await tester.pumpAndSettle();
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  Map<dynamic, dynamic> items() =>
      calls.lastWhere((call) => call.method == 'setItems').arguments as Map;

  testWidgets('分组系统栏独占返回和新建，原生新建实际保存分组', (tester) async {
    final prefs = await host(tester, const GroupsManagementScreen());
    expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
    expect(find.text('新建分组'), findsNothing);
    expect(find.text('设备分组'), findsOneWidget);
    expect(find.text('点击下方按钮开启高效管理'), findsNothing);
    expect(items()['backLabel'], '返回');
    expect(items()['addLabel'], '新建分组');
    expect(items()['addSymbol'], 'plus');
    await nativeTap(tester, 'onAddTap');
    expect(find.text('新建分组'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '  客厅  ');
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();
    expect(find.text('客厅'), findsOneWidget);
    final saved = jsonDecode(prefs.getStringList('wled_device_groups')!.single);
    expect(saved['name'], '客厅');
    await nativeTap(tester, 'onBackTap');
    expect(find.text('上一级'), findsOneWidget);
    expect(find.byType(GroupsManagementScreen), findsNothing);
    await dispose(tester);
  });

  testWidgets('设置系统重置仅打开确认，取消保留偏好并恢复系统返回', (tester) async {
    final prefs = await host(tester, const SettingsScreen());
    expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
    expect(find.text(l10n.resetData), findsNothing);
    expect(find.text(l10n.settings), findsOneWidget);
    expect(items()['addLabel'], l10n.resetData);
    expect(items()['addDestructive'], true);
    await nativeTap(tester, 'onAddTap');
    expect(find.text(l10n.resetConfirmTitle), findsOneWidget);
    expect(prefs.getString('toolbar_test_sentinel'), '保留');
    await tester.tap(find.text(l10n.cancel));
    await tester.pumpAndSettle();
    expect(find.text(l10n.resetConfirmTitle), findsNothing);
    expect(prefs.getString('toolbar_test_sentinel'), '保留');
    await nativeTap(tester, 'onBackTap');
    expect(find.byType(SettingsScreen), findsNothing);
    expect(find.text('上一级'), findsOneWidget);
    await dispose(tester);
  });

  testWidgets('系统栏未就绪时分组新建和返回仍可达', (tester) async {
    await host(tester, const GroupsManagementScreen(), ready: false);
    expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
    await tester.tap(find.text('新建分组'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.pumpAndSettle();
    expect(find.text('上一级'), findsOneWidget);
    await dispose(tester);
  });

  testWidgets('系统栏未就绪时设置重置和返回仍可达', (tester) async {
    final prefs = await host(tester, const SettingsScreen(), ready: false);
    expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
    await tester.ensureVisible(find.text(l10n.resetData));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.resetData));
    await tester.pumpAndSettle();
    expect(find.text(l10n.resetConfirmTitle), findsOneWidget);
    await tester.tap(find.text(l10n.cancel));
    await tester.pumpAndSettle();
    expect(prefs.getString('toolbar_test_sentinel'), '保留');
    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.pumpAndSettle();
    expect(find.text('上一级'), findsOneWidget);
    await dispose(tester);
  });
}
