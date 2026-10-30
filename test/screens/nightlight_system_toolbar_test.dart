import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flux/core/l10n.dart';
import 'package:flux/models/wled_state.dart';
import 'package:flux/providers/providers.dart';
import 'package:flux/screens/nightlight_screen.dart';
import 'package:flux/services/duo_toolbar_service.dart';
import 'package:flux/widgets/nightlight_editor.dart';

class IosToolbar extends DuoToolbarService {
  IosToolbar(MethodChannel channel) : super(channel: channel);
  @override
  bool get isSupported => true;
}

void main() {
  const channel = MethodChannel('test/nightlight_toolbar');
  for (final native in [true, false]) {
    testWidgets('定时渐暗系统栏仅返回且保持编辑器，native=$native', (tester) async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return true;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            duoToolbarReadyProvider.overrideWith((ref) async => native),
            duoToolbarServiceProvider.overrideWithValue(IosToolbar(channel)),
            l10nProvider.overrideWithValue(ZhStrings()),
            currentDeviceIdProvider.overrideWith((ref) => 'nightlight'),
            deviceSessionProvider.overrideWith(
              (ref, id) => DeviceStateNotifier(
                null,
                ref,
                deviceId: id,
                initialState: const WledState(on: true, bri: 128),
              ),
            ),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const NightlightScreen(),
                  ),
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      expect(find.byType(NightlightEditor), findsOneWidget);
      if (native) {
        final items =
            calls.lastWhere((call) => call.method == 'setItems').arguments
                as Map;
        expect(items['backLabel'], '返回');
        expect(items['showPrimary'], false);
        expect(items['showMenu'], false);
        expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
        tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('onBackTap'),
          ),
          (_) {},
        );
      } else {
        await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      }
      await tester.pumpAndSettle();
      expect(find.byType(NightlightScreen), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
