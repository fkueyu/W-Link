import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flux/core/constants.dart';
import 'package:flux/core/l10n.dart';
import 'package:flux/models/models.dart';
import 'package:flux/providers/providers.dart';
import 'package:flux/screens/custom_palette_editor_screen.dart';
import 'package:flux/screens/effects_list_screen.dart';
import 'package:flux/screens/palettes_list_screen.dart';
import 'package:flux/services/duo_toolbar_service.dart';

class _IosToolbar extends DuoToolbarService {
  _IosToolbar(MethodChannel channel) : super(channel: channel);
  @override
  bool get isSupported => true;
}

void main() {
  const channel = MethodChannel('test/palette_effect_toolbar');
  const device = WledDevice(
    id: 'palette-target',
    name: '灯带',
    originalName: 'WLED',
    ip: '10.0.0.8',
    port: 8088,
  );
  final calls = <MethodCall>[];
  var attached = true;

  setUp(() {
    calls.clear();
    attached = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'ensureAttached'
              ? {'attached': attached}
              : true;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Map items() =>
      calls.lastWhere((call) => call.method == 'setItems').arguments as Map;
  List<Map> menu() => (items()['menu'] as List).cast<Map>();

  Future<void> native(WidgetTester tester, String method, [String? id]) async {
    tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall(method, id == null ? null : {'id': id}),
      ),
      (_) {},
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> host(
    WidgetTester tester,
    Widget screen, {
    bool selected = true,
  }) async {
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      AppConstants.keyDevices: jsonEncode([device.toJson()]),
      'fav_effects': ['1'],
      'fav_palettes': ['1'],
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          l10nProvider.overrideWithValue(ZhStrings()),
          currentDeviceIdProvider.overrideWith(
            (ref) => selected ? device.id : null,
          ),
          duoToolbarServiceProvider.overrideWithValue(_IosToolbar(channel)),
          duoToolbarReadyProvider.overrideWith((ref) async => attached),
          wledApiProvider.overrideWithValue(null),
          deviceStateProvider.overrideWithValue(
            const AsyncData(WledState(on: true, bri: 128)),
          ),
          effectsProvider.overrideWith(
            (ref) async => ['Toolbar Unfav', 'Toolbar Fav'],
          ),
          palettesProvider.overrideWith(
            (ref) async => ['Toolbar Unfav', 'Toolbar Fav'],
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute<void>(builder: (_) => screen)),
                child: const Text('进入页面'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('进入页面'));
    await tester.pumpAndSettle();
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  for (final screen in [
    const EffectsListScreen(),
    const PalettesListScreen(),
  ]) {
    testWidgets('${screen.runtimeType} 系统返回和收藏筛选生效且无重复入口', (tester) async {
      await host(tester, screen);
      expect(calls.where((call) => call.method == 'setItems'), isNotEmpty);
      expect(items()['backLabel'], '返回');
      expect(items()['addSymbol'], 'star');
      expect(items()['addLabel'], '仅显示收藏');
      expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
      expect(find.bySemanticsLabel('仅显示收藏'), findsNothing);
      expect(find.text('Toolbar Unfav'), findsWidgets);
      await native(tester, 'onAddTap');
      expect(find.text('Toolbar Unfav'), findsNothing);
      expect(find.text('Toolbar Fav'), findsWidgets);
      expect(items()['addSymbol'], 'star.fill');
      expect(items()['addLabel'], '显示全部');
      await native(tester, 'onAddTap');
      expect(find.text('Toolbar Unfav'), findsWidgets);
      await native(tester, 'onBackTap');
      expect(find.byType(screen.runtimeType), findsNothing);
      expect(find.text('进入页面'), findsOneWidget);
      await dispose(tester);
    });
  }

  testWidgets('调色板系统菜单打开编辑器，返回后恢复收藏栏', (tester) async {
    await host(tester, const PalettesListScreen());
    expect(calls.where((call) => call.method == 'setItems'), isNotEmpty);
    expect(menu().single['id'], 'custom_palette');
    expect(find.text(ZhStrings().customPalette), findsNothing);
    await native(tester, 'onMenuSelect', 'custom_palette');
    expect(find.byType(CustomPaletteEditorScreen), findsOneWidget);
    expect(items()['addSymbol'], 'square.and.arrow.up');
    expect(find.text(ZhStrings().uploadPalette), findsNothing);
    expect(find.byType(PopupMenuButton<int>), findsNothing);
    await native(tester, 'onBackTap');
    expect(find.byType(CustomPaletteEditorScreen), findsNothing);
    expect(items()['addSymbol'], 'star');
    await dispose(tester);
  });

  testWidgets('编辑器系统槽位决定上传文件并保留端口，忙碌时禁用和去重', (tester) async {
    final response = Completer<http.Response>();
    final requests = <http.Request>[];
    await http.runWithClient(
      () async {
        await host(tester, const CustomPaletteEditorScreen());
        expect(calls.where((call) => call.method == 'setItems'), isNotEmpty);
        expect(items()['addEnabled'], true);
        expect(menu(), hasLength(10));
        expect(menu().first['selected'], true);
        await native(tester, 'onMenuSelect', 'slot_7');
        expect(find.text('${ZhStrings().paletteSlot} 7'), findsOneWidget);
        expect(
          menu().singleWhere((entry) => entry['id'] == 'slot_7')['selected'],
          true,
        );
        await native(tester, 'onAddTap');
        expect(requests, hasLength(1));
        expect(requests.single.url, Uri.parse('http://10.0.0.8:8088/upload'));
        expect(requests.single.body, contains('/palette7.json'));
        expect(items()['addEnabled'], false);
        expect(items()['addBusy'], true);
        expect(menu().every((entry) => entry['enabled'] == false), true);
        await native(tester, 'onMenuSelect', 'slot_2');
        await native(tester, 'onAddTap');
        expect(requests, hasLength(1));
        expect(find.text('${ZhStrings().paletteSlot} 7'), findsOneWidget);
        response.complete(http.Response('', 200));
        await tester.pumpAndSettle();
        expect(items()['addEnabled'], true);
        expect(items()['addBusy'], false);
        await dispose(tester);
      },
      () => MockClient((request) async {
        requests.add(request);
        return response.future;
      }),
    );
  });

  testWidgets('编辑器无设备及不足两个色标时禁用系统上传', (tester) async {
    final requests = <http.Request>[];
    await http.runWithClient(
      () async {
        await host(tester, const CustomPaletteEditorScreen(), selected: false);
        expect(calls.where((call) => call.method == 'setItems'), isNotEmpty);
        expect(items()['addEnabled'], false);
        await native(tester, 'onAddTap');
        expect(requests, isEmpty);
        await dispose(tester);
        await host(tester, const CustomPaletteEditorScreen());
        expect(items()['addEnabled'], true);
        for (var index = 0; index < 2; index++) {
          await tester.tap(find.byIcon(Icons.delete_outline_rounded).first);
          await tester.pumpAndSettle();
        }
        expect(items()['addEnabled'], false);
        await native(tester, 'onAddTap');
        expect(requests, isEmpty);
        await dispose(tester);
      },
      () => MockClient((request) async {
        requests.add(request);
        return http.Response('', 200);
      }),
    );
  });

  testWidgets('原生不可用时列表和编辑器保留原返回、收藏、槽位及上传入口', (tester) async {
    attached = false;
    await host(tester, const PalettesListScreen());
    expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
    expect(find.bySemanticsLabel('仅显示收藏'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('仅显示收藏'));
    await tester.pumpAndSettle();
    expect(find.text('Toolbar Unfav'), findsNothing);
    await tester.tap(find.text(ZhStrings().customPalette));
    await tester.pumpAndSettle();
    expect(find.byType(CustomPaletteEditorScreen), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
    expect(find.byType(PopupMenuButton<int>), findsOneWidget);
    expect(find.text(ZhStrings().uploadPalette), findsOneWidget);
    await dispose(tester);
  });
}
