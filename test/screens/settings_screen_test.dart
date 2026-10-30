import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flux/core/l10n.dart';
import 'package:flux/providers/common_providers.dart';
import 'package:flux/screens/settings_screen.dart';

void main() {
  const channel = MethodChannel('flux/app_info');
  Future<void> mount(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          l10nProvider.overrideWithValue(ZhStrings()),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
  }

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  testWidgets('版本显示来自当前安装包，覆盖构建版本也不显示旧常量', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => call.method == 'getAppVersion' ? '9.8.7' : null,
        );
    await mount(tester);
    expect(find.text('v9.8.7'), findsOneWidget);
    expect(find.text('v2.4.4'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('取不到安装版本时不显示错误版本号', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => throw PlatformException(code: 'not_available'),
        );
    await mount(tester);
    expect(find.text('—'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
