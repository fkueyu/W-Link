import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flux/core/l10n.dart';
import 'package:flux/models/models.dart';
import 'package:flux/providers/common_providers.dart';
import 'package:flux/providers/device_providers.dart';
import 'package:flux/screens/device_control_screen.dart';
import 'package:flux/widgets/color_picker_sheet.dart';
import 'package:flux/widgets/flux_dialog.dart';

/// iPhone Duo 姿态档（宽度取自实测：内屏 951×669pt、中央折痕 40pt、分屏 50%）。
///
/// 这里刻意用**约束**驱动，而不是新增一套「Duo 专用布局」：Apple 的折叠屏
/// 指引明确要求按尺寸类别与约束设计，禁止按具体屏幕/断点写死度量。
const Map<String, Size> kDuoPostures = <String, Size>{
  // 2026-10-24 在真 Duo 模拟器（iOS 27.1）上量到的外屏：窗口 466×678，
  // 但 `MediaQuery.padding` 是 `EdgeInsets(0, 0, 84, 34)`——**右侧 84pt 是
  // 竖排状态栏 + 摄像头保留区**。App 真正能用的内容区只有 382×644，
  // 比下面那档 393×600 还窄 11pt。这一档就是按实测内容区补的。
  '外屏-真实可用 382x644': Size(382, 644),
  '外屏-窄 393x600': Size(393, 600),
  '外屏-宽而矮 480x600': Size(480, 600),
  '内屏 951x669': Size(951, 669),
  '半折 911x669': Size(911, 669),
  '分屏50% 475x669': Size(475, 669),
};

/// 折叠内屏顶部摄像头保留区（模拟器实测 `padding.top` 量级）。
const double kReservedTop = 59;

/// 底部 home indicator 安全区（iPhone / 折叠屏一致）。
const double kHomeIndicator = 34;

/// 色盘弹窗里色盘之外固定占用的高度，与 `ColorPickerSheet` 内的预算保持一致。
const double kSheetChrome = 200;

const WledDevice kTestDevice = WledDevice(
  id: 'device-1',
  name: '客厅灯带',
  originalName: 'WLED',
  ip: '10.0.0.9',
);

void main() {
  /// 设备控制页里的 flutter_animate 会留下延迟计时器；测试收尾必须清掉，
  /// 否则报「A Timer is still pending even after the widget tree was disposed」。
  Future<void> drainTimers(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  void usePosture(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget mediaHost(
    Widget child,
    Size size, {
    double top = 0,
    double bottom = 0,
    double keyboard = 0,
    double textScale = 1.0,
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          padding: EdgeInsets.only(top: top, bottom: bottom),
          viewInsets: EdgeInsets.only(bottom: keyboard),
          textScaler: TextScaler.linear(textScale),
          disableAnimations: true,
        ),
        child: child,
      ),
    );
  }

  Widget controlHost(
    Size size, {
    bool embedded = false,
    double top = 0,
    double textScale = 1.0,
    required Override preferences,
  }) {
    return ProviderScope(
      overrides: [
        preferences,
        currentDeviceIdProvider.overrideWith((ref) => 'device-1'),
        deviceSessionProvider.overrideWith(
          (ref, deviceId) => DeviceStateNotifier(
            null,
            ref,
            deviceId: deviceId,
            initialState: const WledState(on: true, bri: 128),
          ),
        ),
        l10nProvider.overrideWithValue(ZhStrings()),
      ],
      child: mediaHost(
        DeviceControlScreen(device: kTestDevice, embedded: embedded),
        size,
        top: top,
        textScale: textScale,
      ),
    );
  }

  Future<Override> preferencesOverride() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    return sharedPreferencesProvider.overrideWithValue(preferences);
  }

  // ── R2：色盘弹窗 ────────────────────────────────────────────────────────
  group('色盘弹窗（R2：宽而矮的外屏曾按宽度取正方形而溢出）', () {
    for (final posture in kDuoPostures.entries) {
      testWidgets('不溢出且内容完整：${posture.key}', (tester) async {
        usePosture(tester, posture.value);
        SharedPreferences.setMockInitialValues({});
        final preferences = await SharedPreferences.getInstance();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(preferences),
            ],
            child: mediaHost(
              Scaffold(
                body: Align(
                  alignment: Alignment.bottomCenter,
                  child: ColorPickerSheet(
                    initialColor: Colors.black,
                    onColorChanged: (color) async {},
                  ),
                ),
              ),
              posture.value,
              bottom: kHomeIndicator,
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        // 色盘 + 其余内容必须**一屏放得下**（不需要滚动）：
        // 只按宽度取正方形时，宽而矮的外屏会把快捷颜色挤到屏幕外。
        final wheel = tester.getSize(find.byKey(const ValueKey('color-wheel')));
        expect(wheel.width, wheel.height);
        expect(
          wheel.height + kSheetChrome + kHomeIndicator,
          lessThanOrEqualTo(posture.value.height),
        );
        // 内容完整：手柄、色盘、快捷颜色都在
        expect(find.byKey(const ValueKey('quick-color-0')), findsOneWidget);
        expect(find.byType(ListView), findsWidgets);
      });
    }
  });

  // ── R1：弹窗卡片 ────────────────────────────────────────────────────────
  group('弹窗卡片（R1：曾是无滚动无高度上限的 Column）', () {
    Widget tallCard() => FluxDialogCard(
      isDark: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [for (int i = 0; i < 30; i++) Text('内容行 $i')],
      ),
    );

    for (final posture in kDuoPostures.entries) {
      testWidgets('超长内容改为滚动而不溢出：${posture.key}', (tester) async {
        usePosture(tester, posture.value);
        await tester.pumpWidget(mediaHost(tallCard(), posture.value));
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byType(SingleChildScrollView), findsOneWidget);
        expect(
          tester
              .getSize(find.byKey(const ValueKey('flux-dialog-surface')))
              .height,
          lessThanOrEqualTo(posture.value.height),
        );
      });
    }

    testWidgets('键盘弹出时卡片上移，不落在键盘后面', (tester) async {
      const size = Size(951, 669);
      const keyboard = 300.0;
      usePosture(tester, size);
      await tester.pumpWidget(
        mediaHost(
          FluxDialogCard(
            isDark: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [const TextField(autofocus: true)],
            ),
          ),
          size,
          keyboard: keyboard,
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.byType(TextField)).bottom,
        lessThanOrEqualTo(size.height - keyboard),
      );
    });
  });

  // ── R3 / R5：设备控制页 ─────────────────────────────────────────────────
  group('设备控制页（R3 顶部条与内容偏移同源 / R5 瓦片固定高度）', () {
    testWidgets('内容偏移由顶部条实际高度推导，而不是写死 80', (tester) async {
      const size = Size(393, 600);
      usePosture(tester, size);
      await tester.pumpWidget(
        controlHost(
          size,
          top: kReservedTop,
          preferences: await preferencesOverride(),
        ),
      );
      await tester.pump();

      final spacer = tester.widget<SizedBox>(
        find
            .descendant(
              of: find.byType(SliverToBoxAdapter).first,
              matching: find.byType(SizedBox),
            )
            .first,
      );
      // 顶部玻璃条 = 64 + padding.top，内容再留 16 的间距
      expect(spacer.height, kReservedTop + 64 + 16);
      await drainTimers(tester);
    });

    /// 高度必须留够「两行中文标题」的余量。
    ///
    /// 真机上「定时关闭与渐暗」在 2 列布局里折成两行，按 PingFang 行高内容约
    /// 88.6pt；此前的 84 在真机溢出 4.6pt，而用例全绿——因为测试字体是等宽方块、
    /// 行高比中文小。所以这条用例守的是「余量 ≥ 92 且随字号增长」，不是形状。
    testWidgets('快速操作瓦片高度留够两行中文标题的余量', (tester) async {
      const size = Size(393, 600);
      usePosture(tester, size);
      await tester.pumpWidget(
        controlHost(size, preferences: await preferencesOverride()),
      );
      await tester.pump();

      final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 2);
      expect(
        delegate.mainAxisExtent,
        greaterThanOrEqualTo(92),
        reason: '两行中文标题 + 副标题实测约 88.6pt，留 3pt 余量',
      );
      await drainTimers(tester);
    });

    testWidgets('瓦片高度随字号缩放，不在大字号下溢出', (tester) async {
      const size = Size(393, 600);
      usePosture(tester, size);
      await tester.pumpWidget(
        controlHost(
          size,
          textScale: 1.6,
          preferences: await preferencesOverride(),
        ),
      );
      await tester.pump();

      final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(
        delegate.mainAxisExtent,
        greaterThan(92 * 1.5),
        reason: '字号放大 1.6 倍时固定 92 必然溢出',
      );
      expect(tester.takeException(), isNull);
      await drainTimers(tester);
    });

    testWidgets('瓦片标题最多两行且超长省略（不再靠内容撑高）', (tester) async {
      const size = Size(393, 600);
      usePosture(tester, size);
      await tester.pumpWidget(
        controlHost(size, preferences: await preferencesOverride()),
      );
      await tester.pump();

      final title = tester.widget<Text>(find.text(ZhStrings().nightlight));
      expect(title.maxLines, 2);
      expect(title.overflow, TextOverflow.ellipsis);
      await drainTimers(tester);
    });

    for (final posture in kDuoPostures.entries) {
      testWidgets('不溢出：${posture.key}', (tester) async {
        usePosture(tester, posture.value);
        await tester.pumpWidget(
          controlHost(
            posture.value,
            top: kReservedTop,
            preferences: await preferencesOverride(),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        await drainTimers(tester);
      });
    }
  });

  // ── R1 回归守卫：新增弹窗不能再回到「无滚动 Column」 ─────────────────────
  test('每个 showDialog 都走统一外壳或 AlertDialog（R1 回归守卫）', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!lines[i].contains('showDialog')) continue;
        final window = lines.skip(i).take(12).join('\n');
        // 真实不变量：弹窗要么走统一外壳，要么自己带了滚动容器
        // （groups/presets/device_discovery 的 4 处玻璃拟态弹窗就是后者）。
        // 裸 Center>Material>Container>Column 没有高度上限，折叠/键盘下必溢出。
        const bounded = [
          'FluxDialogCard',
          'AlertDialog',
          'SingleChildScrollView',
          'ListView',
          'CustomScrollView',
        ];
        if (bounded.any(window.contains)) continue;
        offenders.add('${entity.path}:${i + 1}');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          '弹窗必须用 FluxDialogCard（有高度上限 + 可滚动）或 AlertDialog；'
          '回到裸 Center>Material>Container>Column 会在折叠/键盘下溢出',
    );
  });

  // ── R6 回归守卫：手写标题行必须可收缩 ────────────────────────────────────
  test('手写标题行必须是 Expanded + ellipsis（R6 回归守卫）', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!lines[i].contains('chevron_left_rounded')) continue;
        final window = lines.skip(i).take(22).join('\n');
        final shrinkable =
            window.contains('Expanded(') &&
            window.contains('TextOverflow.ellipsis') &&
            !window.contains('Spacer()');
        if (!shrinkable) offenders.add('${entity.path}:${i + 1}');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          '标题行要照 nightlight_screen 写成 Expanded + ellipsis；'
          '固定宽度标题在窄屏/侧栏下会撑破整行',
    );
  });

  // ── R7 回归守卫：弹窗/sheet 高度要由约束推导 ─────────────────────────────
  test('弹窗与底部弹层的高度不得直接取整窗口高度（R7 回归守卫）', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (!line.contains('MediaQuery.sizeOf(context).height') &&
            !line.contains('MediaQuery.of(context).size.height')) {
          continue;
        }
        // 允许「约束拿不到时」的兜底：上文必须出现 isFinite 判断
        final from = i >= 5 ? i - 5 : 0;
        final before = lines.sublist(from, i).join('\n');
        if (!before.contains('isFinite')) {
          offenders.add('${entity.path}:${i + 1}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          '高度要从 constraints.maxHeight 推导（折叠/分屏/键盘都会改变可用高度），'
          '整窗口高度只能作为 isFinite 兜底',
    );
  });
}
