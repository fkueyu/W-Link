import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flux/widgets/smart_slider.dart';
import 'package:flux/widgets/skeleton_card.dart';
import 'package:flux/widgets/radar_ripple.dart';

void main() {
  testWidgets('滑块读屏提供名称和格式化单位，拖动只在结束发送一次', (tester) async {
    final ended = <double>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SmartSlider(
            label: '过渡时间',
            value: 15,
            min: 0,
            max: 255,
            valueFormatter: (v) => '${(v * 0.1).toStringAsFixed(1)}秒',
            onChangeEnd: ended.add,
          ),
        ),
      ),
    );
    final data = tester.getSemantics(find.byType(Slider)).getSemanticsData();
    expect(data.label, '过渡时间');
    expect(data.value, '1.5秒');
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(Slider)),
    );
    await gesture.moveBy(const Offset(70, 0));
    await tester.pump();
    expect(ended, isEmpty);
    await gesture.up();
    await tester.pump();
    expect(ended, hasLength(1));
  });

  testWidgets('滑块后缀也是读屏值的一部分', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SmartSlider(
            label: '亮度',
            value: 75,
            max: 100,
            valueSuffix: '%',
            onChanged: null,
          ),
        ),
      ),
    );
    final data = tester.getSemantics(find.byType(Slider)).getSemanticsData();
    expect(data.label, '亮度');
    expect(data.value, '75%');
  });

  testWidgets('窄屏两倍字的长滑块名称和数值可完整换行', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 240,
                child: SmartSlider(
                  label: '动画切换的过渡时间参数',
                  value: 255,
                  max: 255,
                  valueFormatter: (_) => '25.5 秒',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('动画切换的过渡时间参数'), findsOneWidget);
    expect(find.text('25.5 秒'), findsOneWidget);
  });

  for (final child in [
    const SkeletonCard(),
    const RadarRipple(color: Colors.blue),
  ]) {
    testWidgets('${child.runtimeType} 在减少动态时没有循环帧，设置变化后停止', (tester) async {
      Future<void> host(bool reduced) => tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: Scaffold(body: child),
          ),
        ),
      );
      await host(true);
      await tester.pump(const Duration(seconds: 2));
      expect(tester.binding.transientCallbackCount, 0);
      await host(false);
      await tester.pump(const Duration(seconds: 2));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await host(true);
      await tester.pump(const Duration(seconds: 2));
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
