import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flux/providers/common_providers.dart';
import 'package:flux/providers/device_providers.dart';
import 'package:flux/core/l10n.dart';
import 'package:flux/screens/adaptive_shell.dart';
import 'package:flux/screens/device_list_screen.dart';
import 'package:flux/widgets/animated_background.dart';
import 'package:flux/widgets/device_overview_bar.dart';

void main() {
  testWidgets('wide shell owns exactly one global animated background', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: AdaptiveShell(),
          ),
        ),
      ),
    );

    expect(find.byType(AnimatedBackground), findsOneWidget);
    final backgroundElement = tester.element(find.byType(AnimatedBackground));
    expect(
      backgroundElement.findAncestorWidgetOfExactType<DeviceListScreen>(),
      isNull,
    );

    final logoNode = tester.getSemantics(find.byType(Image).first);
    final logoFlags = logoNode.getSemanticsData().flagsCollection;
    expect(logoFlags.isImage, isTrue);
    expect(logoFlags.isButton, isFalse);
    expect(logoNode.label, contains('W-Link'));

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    semantics.dispose();
  });

  testWidgets('narrow shell keeps the device list global background', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(700, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: AdaptiveShell(),
          ),
        ),
      ),
    );

    expect(find.byType(AnimatedBackground), findsOneWidget);
    final backgroundElement = tester.element(find.byType(AnimatedBackground));
    expect(
      backgroundElement.findAncestorWidgetOfExactType<DeviceListScreen>(),
      isNotNull,
    );

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('embedded device list is transparent and owns no background', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          l10nProvider.overrideWithValue(ZhStrings()),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: DeviceListScreen(onDeviceSelected: (_) {}),
          ),
        ),
      ),
    );

    expect(find.byType(AnimatedBackground), findsNothing);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      Colors.transparent,
    );
    final sectionHeader = find.ancestor(
      of: find.byType(DeviceOverviewBar),
      matching: find.byType(Row),
    );
    expect(sectionHeader, findsOneWidget);
    expect(
      find.descendant(of: sectionHeader, matching: find.text('我的设备')),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('shows one localized toast when a device command fails', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: AdaptiveShell(),
          ),
        ),
      ),
    );
    final context = tester.element(find.byType(AdaptiveShell));
    final container = ProviderScope.containerOf(context);

    container
        .read(deviceCommandFailureProvider.notifier)
        .state = const DeviceCommandFailure(
      sequence: 1,
      deviceId: 'device-1',
      error: 'offline',
    );
    await tester.pump();

    expect(
      find.text('Control failed. Check the device connection.'),
      findsOneWidget,
    );
    expect(find.byType(SnackBar), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 1200));
    container
        .read(deviceCommandFailureProvider.notifier)
        .state = const DeviceCommandFailure(
      sequence: 1,
      deviceId: 'device-1',
      error: 'same failure delivered again',
    );
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text('Control failed. Check the device connection.'),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
