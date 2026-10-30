import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flux/models/duo_geometry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flux/providers/duo_providers.dart';
import 'package:flux/services/duo_toolbar_service.dart';
import 'package:flux/widgets/duo_system_toolbar.dart';

class _DelayedToolbarService extends DuoToolbarService {
  final items = Completer<bool>();
  final visibility = <bool>[];
  Completer<bool>? nextShow;
  @override
  bool get isSupported => true;
  @override
  Future<bool> setItems({
    required String addLabel,
    required String moreLabel,
    required List<DuoToolbarMenuEntry> menu,
    String? backLabel,
    String addSymbol = 'plus',
    bool addEnabled = true,
    bool showMenu = true,
    bool showPrimary = true,
    bool addDestructive = false,
    bool addBusy = false,
  }) => items.future;
  @override
  Future<bool> setVisible(bool visible) async {
    visibility.add(visible);
    if (visible && nextShow != null) {
      final pending = nextShow!;
      nextShow = null;
      return pending.future;
    }
    return true;
  }
}

class _IosChannelToolbarService extends DuoToolbarService {
  _IosChannelToolbarService(MethodChannel channel) : super(channel: channel);
  @override
  bool get isSupported => true;
}

Widget _toolbar(_DelayedToolbarService service, {bool visible = true}) =>
    ProviderScope(
      overrides: [duoToolbarServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
        home: DuoSystemToolbar(
          visible: visible,
          addLabel: '添加',
          moreLabel: '更多',
          menu: const [],
          onAdd: () {},
          onMenuSelected: (_) {},
        ),
      ),
    );

void main() {
  testWidgets('下发按钮期间销毁组件，完成后不能重新显示系统栏', (tester) async {
    final service = _DelayedToolbarService();
    await tester.pumpWidget(_toolbar(service));
    await tester.pumpWidget(const SizedBox.shrink());
    service.items.complete(false);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(service.visibility, isNot(contains(true)));
  });

  testWidgets('下发期间隐藏页面，旧同步不能再显示', (tester) async {
    final service = _DelayedToolbarService();
    await tester.pumpWidget(_toolbar(service));
    await tester.pumpWidget(_toolbar(service, visible: false));
    service.items.complete(false);
    await tester.pump();
    expect(service.visibility, isNot(contains(true)));
    expect(service.visibility.last, isFalse);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DuoSystemToolbar)),
    );
    expect(container.read(duoToolbarFallbackProvider), isFalse);
  });
  testWidgets('隐藏旧页面不抢回调，销毁旧实例不收走新页面工具栏', (tester) async {
    final service = _DelayedToolbarService();
    service.items.complete(true);
    var oldAdds = 0;
    var newAdds = 0;
    Widget pages({required bool includeOld, required bool oldVisible}) =>
        ProviderScope(
          overrides: [duoToolbarServiceProvider.overrideWithValue(service)],
          child: MaterialApp(
            home: Column(
              children: [
                if (includeOld)
                  DuoSystemToolbar(
                    key: const ValueKey('old'),
                    visible: oldVisible,
                    addLabel: '旧添加',
                    moreLabel: '更多',
                    menu: const [],
                    onAdd: () => oldAdds++,
                    onMenuSelected: (_) {},
                  ),
                DuoSystemToolbar(
                  key: const ValueKey('new'),
                  visible: !oldVisible,
                  addLabel: '新添加',
                  moreLabel: '更多',
                  menu: const [],
                  onAdd: () => newAdds++,
                  onMenuSelected: (_) {},
                ),
              ],
            ),
          ),
        );
    await tester.pumpWidget(pages(includeOld: true, oldVisible: true));
    await tester.pump();
    service.onAddTap?.call();
    expect(oldAdds, 1);
    expect(newAdds, 0);
    await tester.pumpWidget(pages(includeOld: true, oldVisible: false));
    await tester.pump();
    await tester.pumpWidget(pages(includeOld: false, oldVisible: false));
    await tester.pump();
    service.onAddTap?.call();
    expect(newAdds, 1);
    expect(service.visibility.last, isTrue);
  });
  for (final failingMethod in ['setItems', 'setVisible']) {
    testWidgets('握手成功后 $failingMethod 失败立即恢复Flutter入口，延迟重试成功', (tester) async {
      final channel = MethodChannel('test/toolbar_fallback/$failingMethod');
      var failedOnce = false;
      var handshakes = 0;
      var successfulShows = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'ensureAttached') {
              handshakes++;
              return {'attached': true};
            }
            final isShow =
                call.method == 'setVisible' &&
                (call.arguments as Map)['visible'] == true;
            if (call.method == failingMethod &&
                !failedOnce &&
                (failingMethod != 'setVisible' || isShow)) {
              failedOnce = true;
              if (failingMethod == 'setVisible') {
                throw PlatformException(code: 'show_failed');
              }
              return false;
            }
            if (isShow) successfulShows++;
            return true;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            duoGeometryProvider.overrideWith(
              (ref) => Stream.value(
                const DuoGeometry(
                  supported: true,
                  attached: true,
                  hinge: DuoHinge(
                    status: DuoHingeStatus.closed,
                    angleRadians: 0,
                  ),
                ),
              ),
            ),
            duoToolbarServiceProvider.overrideWithValue(
              _IosChannelToolbarService(channel),
            ),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, child) {
                if (ref.watch(duoToolbarReadyProvider).valueOrNull != true) {
                  return const Text('Flutter添加入口');
                }
                return DuoSystemToolbar(
                  visible: true,
                  addLabel: '添加',
                  moreLabel: '更多',
                  menu: const [],
                  onAdd: () {},
                  onMenuSelected: (_) {},
                );
              },
            ),
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump();
      }
      expect(failedOnce, isTrue);
      expect(find.text('Flutter添加入口'), findsOneWidget);
      expect(successfulShows, 0);
      expect(handshakes, 1);
      await tester.pump(const Duration(milliseconds: 499));
      expect(find.text('Flutter添加入口'), findsOneWidget);
      expect(handshakes, 1);
      await tester.pump(const Duration(milliseconds: 1));
      for (var i = 0; i < 6; i++) {
        await tester.pump();
      }
      expect(handshakes, 2);
      expect(successfulShows, 1);
      expect(find.text('Flutter添加入口'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }

  testWidgets('旧页面迟到的显示失败不触发新owner回退', (tester) async {
    final service = _DelayedToolbarService();
    service.items.complete(true);
    final oldShow = Completer<bool>();
    service.nextShow = oldShow;
    Widget pages(bool oldVisible) => ProviderScope(
      overrides: [duoToolbarServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
        home: Column(
          children: [
            DuoSystemToolbar(
              key: const ValueKey('old'),
              visible: oldVisible,
              addLabel: '旧添加',
              moreLabel: '更多',
              menu: const [],
              onAdd: () {},
              onMenuSelected: (_) {},
            ),
            DuoSystemToolbar(
              key: const ValueKey('new'),
              visible: !oldVisible,
              addLabel: '新添加',
              moreLabel: '更多',
              menu: const [],
              onAdd: () {},
              onMenuSelected: (_) {},
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(pages(true));
    await tester.pump();
    await tester.pumpWidget(pages(false));
    await tester.pump();
    oldShow.complete(false);
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DuoSystemToolbar).first),
    );
    expect(container.read(duoToolbarFallbackProvider), isFalse);
    expect(service.visibility.last, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
