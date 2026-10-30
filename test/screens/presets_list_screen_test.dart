import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flux/core/l10n.dart';
import 'package:flux/models/models.dart';
import 'package:flux/providers/providers.dart';
import 'package:flux/screens/presets_list_screen.dart';
import 'package:flux/services/wled_api_service.dart';

class PresetNetwork {
  Map<String, dynamic> presets = {
    '1': {'n': '已有预设'},
  };
  Future<http.Response> Function()? read;
  Future<http.Response> Function(Map<String, dynamic>)? write;
  int reads = 0;
  final writes = <Map<String, dynamic>>[];
  late final api = WledApiService(
    baseUrl: 'http://10.0.0.9',
    timeout: const Duration(minutes: 2),
    client: MockClient((request) async {
      if (request.url.path == '/presets.json') {
        reads++;
        return read?.call() ??
            http.Response(
              jsonEncode(presets),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
      }
      final payload = jsonDecode(request.body) as Map<String, dynamic>;
      writes.add(payload);
      return write?.call(payload) ?? http.Response('{}', 200);
    }),
  );
}

Future<ProviderContainer> host(
  WidgetTester tester,
  PresetNetwork network, {
  bool hasApi = true,
}) async {
  tester.view.physicalSize = const Size(466, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(network.api.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        l10nProvider.overrideWithValue(ZhStrings()),
        currentDeviceIdProvider.overrideWith((ref) => 'a'),
        wledApiProvider.overrideWithValue(hasApi ? network.api : null),
        deviceStateProvider.overrideWith(
          (ref) => const AsyncData(WledState(on: true, bri: 128)),
        ),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const PresetsListScreen(),
      ),
    ),
  );
  await tick(tester);
  await tick(tester);
  return ProviderScope.containerOf(
    tester.element(find.byType(PresetsListScreen)),
  );
}

Future<void> tick(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

Future<void> openSave(WidgetTester tester, [String name = '新预设']) async {
  await tester.tap(find.text(ZhStrings().savePreset));
  await tick(tester);
  if (find.byType(TextField).evaluate().length > 1) {
    await tester.enterText(find.byType(TextField).last, name);
  }
}

Future<void> save(WidgetTester tester) async {
  if (find.widgetWithText(FilledButton, '保存').evaluate().isNotEmpty) {
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tick(tester);
  }
}

Future<void> openDelete(WidgetTester tester) async {
  await tester.longPress(find.text('已有预设'));
  await tick(tester);
  await tester.tap(find.text('删除预设'));
  await tick(tester);
}

void main() {
  for (final status in ['loading', 'error', 'no-api']) {
    testWidgets('$status 时禁止新建，不能盲写槽位1', (tester) async {
      final network = PresetNetwork();
      final pending = Completer<http.Response>();
      if (status == 'loading') network.read = () => pending.future;
      if (status == 'error') network.read = () async => http.Response('', 500);
      await host(tester, network, hasApi: status != 'no-api');
      await openSave(tester);
      expect(find.byType(TextField), findsOneWidget);
      await save(tester);
      expect(network.writes, isEmpty);
      expect(find.byType(TextField), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      if (!pending.isCompleted) pending.complete(http.Response('{}', 200));
      await tick(tester);
    });
  }

  testWidgets('保存前重新确认槽位，已有1号分配2号', (tester) async {
    final network = PresetNetwork()..presets = {};
    await host(tester, network);
    await openSave(tester);
    network.presets = {
      '1': {'n': '外部新增'},
    };
    await save(tester);
    expect(network.writes.single['psave'], 2);
  });

  testWidgets('请求未完成重复保存只写一次并保留进度弹窗', (tester) async {
    final network = PresetNetwork();
    final pending = Completer<http.Response>();
    network.write = (_) => pending.future;
    await host(tester, network);
    await openSave(tester);
    await save(tester);
    await save(tester);
    expect(network.writes.length, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    pending.complete(http.Response('{}', 200));
    await tick(tester);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('连续保存即使设备读取暂未反映前次写入也不覆盖', (tester) async {
    final network = PresetNetwork();
    await host(tester, network);
    await openSave(tester, '第一次');
    await save(tester);
    await openSave(tester, '第二次');
    await save(tester);
    expect(network.writes.map((p) => p['psave']), [2, 3]);
  });

  testWidgets('刷新期间不能复用旧列表新建', (tester) async {
    final network = PresetNetwork();
    final container = await host(tester, network);
    final pending = Completer<http.Response>();
    network.read = () => pending.future;
    container.invalidate(presetsProvider);
    await tick(tester);
    await openSave(tester);
    await save(tester);
    expect(network.writes, isEmpty);
    expect(find.byType(TextField), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete(http.Response('{}', 200));
    await tick(tester);
  });

  testWidgets('保存成功后缓存刷新未完成时禁止新建，刷新后继续使用新槽位', (tester) async {
    final network = PresetNetwork();
    final pending = Completer<http.Response>();
    await host(tester, network);
    await openSave(tester, '第一次');
    network.write = (_) async {
      network.read = () => pending.future;
      return http.Response('{}', 200);
    };
    await save(tester);
    await openSave(tester, '刷新中');
    expect(find.byType(TextField), findsOneWidget);
    expect(network.writes.length, 1);
    network.read = null;
    network.write = null;
    pending.complete(http.Response('{"1":{"n":"Existing"}}', 200));
    await tick(tester);
    await openSave(tester, '第二次');
    await save(tester);
    expect(network.writes.map((p) => p['psave']), [2, 3]);
  });

  testWidgets('保存前确认槽位请求去重，读取失败保留输入可重试', (tester) async {
    final network = PresetNetwork();
    await host(tester, network);
    await openSave(tester, '确认后保存');
    final pending = Completer<http.Response>();
    network.read = () => pending.future;
    await save(tester);
    await save(tester);
    expect(network.reads, 2);
    expect(network.writes, isEmpty);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete(http.Response('', 500));
    await tick(tester);
    expect(find.text('确认后保存'), findsOneWidget);
    expect(find.textContaining('失败'), findsOneWidget);
    network.read = null;
    await save(tester);
    expect(network.writes.single['psave'], 2);
  });

  testWidgets('250个槽位已满时提示且不写入越界ID', (tester) async {
    final network = PresetNetwork()
      ..presets = {
        for (var i = 1; i <= 250; i++) '$i': {'n': '预设$i'},
      };
    await host(tester, network);
    await openSave(tester);
    await save(tester);
    expect(network.writes, isEmpty);
    expect(find.textContaining('已满'), findsOneWidget);
  });

  testWidgets('保存失败保留输入，重试成功才关闭', (tester) async {
    final network = PresetNetwork();
    network.write = (_) async => http.Response('', 500);
    await host(tester, network);
    await openSave(tester, '保留此名称');
    await save(tester);
    expect(find.text('保留此名称'), findsOneWidget);
    expect(find.textContaining('失败'), findsOneWidget);
    network.write = null;
    await save(tester);
    expect(network.writes.length, 2);
    expect(network.writes.last['n'], '保留此名称');
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('删除失败保留目标并可重试，期间显示进度', (tester) async {
    final network = PresetNetwork();
    final pending = Completer<http.Response>();
    network.write = (_) => pending.future;
    await host(tester, network);
    await openDelete(tester);
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tick(tester);
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tick(tester);
    expect(network.writes.length, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete(http.Response('', 500));
    await tick(tester);
    expect(find.textContaining('已有预设'), findsWidgets);
    expect(find.textContaining('失败'), findsOneWidget);
    network.write = null;
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tick(tester);
    expect(network.writes.map((p) => p['pdel']), [1, 1]);
    expect(find.text('确定删除？'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final deleting in [false, true]) {
    testWidgets('${deleting ? '删除' : '保存'}请求中离开页面，完成后不访问销毁的ref', (
      tester,
    ) async {
      final network = PresetNetwork();
      final pending = Completer<http.Response>();
      network.write = (_) => pending.future;
      await host(tester, network);
      if (deleting) {
        await openDelete(tester);
        await tester.tap(find.widgetWithText(FilledButton, '删除'));
        await tick(tester);
      } else {
        await openSave(tester);
        await save(tester);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      pending.complete(http.Response('{}', 200));
      await tick(tester);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('保存确认槽位期间切换设备，取消旧操作而不向新设备写入', (tester) async {
    final network = PresetNetwork();
    final container = await host(tester, network);
    await openSave(tester);
    final pending = Completer<http.Response>();
    network.read = () => pending.future;
    await save(tester);
    container.read(currentDeviceIdProvider.notifier).state = 'b';
    await tick(tester);
    pending.complete(http.Response('{}', 200));
    await tick(tester);
    expect(network.writes, isEmpty);
    expect(find.textContaining('设备'), findsWidgets);
  });
}
