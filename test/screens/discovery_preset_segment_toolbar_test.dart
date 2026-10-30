import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flux/core/l10n.dart';
import 'package:flux/models/models.dart';
import 'package:flux/providers/providers.dart';
import 'package:flux/screens/device_discovery_screen.dart';
import 'package:flux/screens/presets_list_screen.dart';
import 'package:flux/screens/segments_list_screen.dart';
import 'package:flux/services/duo_toolbar_service.dart';
import 'package:flux/services/wled_api_service.dart';

class _IosToolbar extends DuoToolbarService {
  _IosToolbar(MethodChannel channel) : super(channel: channel);
  @override
  bool get isSupported => true;
}

class _Network {
  int reads = 0;
  Future<http.Response> Function()? read;
  Future<http.Response> Function()? write;
  final writes = <Map<String, dynamic>>[];
  late final api = WledApiService(
    baseUrl: 'http://toolbar.invalid',
    client: MockClient((request) async {
      if (request.url.path == '/presets.json') {
        reads++;
        return read?.call() ??
            http.Response(
              '{"1":{"n":"已有预设"}}',
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
      }
      writes.add(jsonDecode(request.body) as Map<String, dynamic>);
      return write?.call() ??
          http.Response('{"on":true,"bri":128,"seg":[]}', 200);
    }),
  );
}

const _state = WledState(
  on: true,
  bri: 128,
  info: WledInfo(ver: '1', vid: 1, leds: WledLedInfo(count: 60), name: '替身'),
);

void main() {
  const channel = MethodChannel('test/discovery_preset_segment_toolbar');
  const mdns = MethodChannel('flux/mdns_discovery');
  final calls = <MethodCall>[];
  var scans = 0;
  setUp(() {
    calls.clear();
    scans = 0;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'ensureAttached' ? {'attached': true} : true;
    });
    messenger.setMockMethodCallHandler(mdns, (call) async {
      if (call.method == 'startDiscovery') scans++;
      return null;
    });
  });
  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(mdns, null);
  });

  Future<void> tick(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
  }

  Future<_IosToolbar> host(
    WidgetTester tester,
    Widget page, {
    bool ready = true,
    bool hasApi = true,
    _Network? network,
  }) async {
    tester.view.physicalSize = const Size(466, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final toolbar = _IosToolbar(channel);
    network ??= _Network();
    addTearDown(network.api.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          l10nProvider.overrideWithValue(ZhStrings()),
          duoToolbarServiceProvider.overrideWithValue(toolbar),
          duoToolbarReadyProvider.overrideWith((ref) async => ready),
          currentDeviceIdProvider.overrideWith((ref) => 'toolbar-test'),
          wledApiProvider.overrideWithValue(hasApi ? network.api : null),
          deviceStateProvider.overrideWithValue(const AsyncData(_state)),
          deviceSessionProvider.overrideWith(
            (ref, id) => DeviceStateNotifier(
              null,
              ref,
              deviceId: id,
              initialState: _state,
            ),
          ),
          isWifiConnectedProvider.overrideWithValue(true),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute<void>(builder: (_) => page)),
                child: const Text('进入'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('进入'));
    await tick(tester);
    await tick(tester);
    return toolbar;
  }

  Map items() =>
      calls.lastWhere((call) => call.method == 'setItems').arguments as Map;
  Map refreshItem() => (items()['menu'] as List).cast<Map>().single;

  Future<void> native(
    WidgetTester tester,
    String method, [
    Object? arguments,
  ]) async {
    tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall(method, arguments),
      ),
      (_) {},
    );
    await tick(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 11));
    expect(tester.takeException(), isNull);
  }

  testWidgets('发现系统栏去重，扫描禁用刷新，原生手动添加打开真实弹窗', (tester) async {
    await host(tester, const DeviceDiscoveryScreen());
    expect(items()['backLabel'], '返回');
    expect(items()['addLabel'], ZhStrings().manualAdd);
    expect(items()['addSymbol'], 'plus');
    expect(refreshItem()['enabled'], false);
    expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
    expect(find.byIcon(Icons.refresh_rounded), findsNothing);
    expect(find.text(ZhStrings().manualAdd), findsNothing);
    await native(tester, 'onMenuSelect', {'id': refreshItem()['id']});
    expect(scans, 1);
    await native(tester, 'onAddTap');
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text(ZhStrings().manualAdd), findsOneWidget);
    await tester.tap(find.text(ZhStrings().cancel));
    await tick(tester);
    await tester.pump(const Duration(seconds: 11));
    await tick(tester);
    expect(refreshItem()['enabled'], true);
    await native(tester, 'onMenuSelect', {'id': refreshItem()['id']});
    expect(scans, 2);
    await native(tester, 'onBackTap');
    // maybePop 异步完成后，再等待路由退场动画。
    await tick(tester);
    expect(find.byType(DeviceDiscoveryScreen), findsNothing);
    await close(tester);
  });

  testWidgets('预设系统保存保留槽位分配并能菜单刷新，搜索和正文保留', (tester) async {
    final network = _Network();
    await host(tester, const PresetsListScreen(), network: network);
    expect(items()['addSymbol'], 'square.and.arrow.down');
    expect(items()['addEnabled'], true);
    expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
    expect(find.byIcon(Icons.refresh_rounded), findsNothing);
    expect(find.text(ZhStrings().savePreset), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('已有预设'), findsOneWidget);
    final reads = network.reads;
    await native(tester, 'onMenuSelect', {'id': refreshItem()['id']});
    expect(network.reads, greaterThan(reads));
    await native(tester, 'onAddTap');
    expect(find.byType(TextField), findsNWidgets(2));
    await tester.enterText(find.byType(TextField).last, '系统栏保存');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tick(tester);
    expect(network.writes.single['psave'], 2);
    expect(network.writes.single['n'], '系统栏保存');
    await close(tester);
  });

  testWidgets('预设原生保存串行且失败保留输入恢复重试', (tester) async {
    final network = _Network();
    final pending = Completer<http.Response>();
    network.write = () => pending.future;
    await host(tester, const PresetsListScreen(), network: network);
    await native(tester, 'onAddTap');
    await tester.enterText(find.byType(TextField).last, '失败后重试');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tick(tester);
    expect(network.writes, hasLength(1));
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await native(tester, 'onAddTap');
    expect(network.writes, hasLength(1));
    pending.complete(http.Response('', 500));
    await tick(tester);
    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller!.text,
      '失败后重试',
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    network.write = null;
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tick(tester);
    expect(network.writes, hasLength(2));
    expect(network.writes.map((entry) => entry['psave']), [2, 2]);
    expect(find.byType(TextField), findsOneWidget);
    await close(tester);
  });

  for (final status in ['loading', 'error', 'no-api']) {
    testWidgets('预设系统保存保持$status禁用，原生回调不能盲写', (tester) async {
      final network = _Network();
      final pending = Completer<http.Response>();
      if (status == 'loading') network.read = () => pending.future;
      if (status == 'error') network.read = () async => http.Response('', 500);
      await host(
        tester,
        const PresetsListScreen(),
        network: network,
        hasApi: status != 'no-api',
      );
      expect(items()['addEnabled'], false);
      await native(tester, 'onAddTap');
      expect(find.byType(TextField), findsOneWidget);
      expect(network.writes, isEmpty);
      await close(tester);
      if (!pending.isCompleted) pending.complete(http.Response('{}', 200));
      await tick(tester);
    });
  }

  testWidgets('分段系统新增真实提交且无重复顶部按钮', (tester) async {
    final network = _Network();
    await host(tester, const SegmentsListScreen(), network: network);
    expect(items()['addLabel'], ZhStrings().addSegment);
    expect(items()['addEnabled'], true);
    expect(items()['showMenu'], false);
    expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
    expect(find.bySemanticsLabel(ZhStrings().addSegment), findsNothing);
    await native(tester, 'onAddTap');
    final segments = network.writes.single['seg'] as List;
    expect(segments.single, containsPair('id', 0));
    expect(segments.single, containsPair('start', 0));
    expect(segments.single, containsPair('stop', 60));
    await close(tester);
  });

  testWidgets('分段无API保持系统新增禁用', (tester) async {
    final network = _Network();
    await host(
      tester,
      const SegmentsListScreen(),
      network: network,
      hasApi: false,
    );
    expect(items()['addEnabled'], false);
    await native(tester, 'onAddTap');
    expect(network.writes, isEmpty);
    await close(tester);
  });

  for (final entry in <(Widget, String)>[
    (const DeviceDiscoveryScreen(), 'discovery'),
    (const PresetsListScreen(), 'preset'),
    (const SegmentsListScreen(), 'segment'),
  ]) {
    testWidgets('${entry.$2}原生不可用保留返回及原动作入口', (tester) async {
      await host(tester, entry.$1, ready: false);
      expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
      if (entry.$2 == 'discovery') {
        expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
        await tester.tap(find.text(ZhStrings().manualAdd));
        await tick(tester);
        expect(find.byType(TextField), findsOneWidget);
      } else if (entry.$2 == 'preset') {
        expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
        await tester.tap(find.text(ZhStrings().savePreset));
        await tick(tester);
        expect(find.byType(TextField), findsNWidgets(2));
      } else {
        expect(find.bySemanticsLabel(ZhStrings().addSegment), findsOneWidget);
      }
      await close(tester);
    });
  }
}
