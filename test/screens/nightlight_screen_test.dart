import 'package:flux/core/l10n.dart';
import 'package:flux/models/wled_state.dart';
import 'package:flux/providers/device_providers.dart';
import 'package:flux/screens/nightlight_screen.dart';
import 'package:flux/widgets/nightlight_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'nightlight screen binds the shared editor to the device session',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final strings = ZhStrings();
      final sessionOverride = deviceSessionProvider.overrideWith(
        (ref, deviceId) => DeviceStateNotifier(
          null,
          ref,
          deviceId: deviceId,
          initialState: const WledState(
            on: true,
            bri: 120,
            nl: WledNightlight(on: false, dur: 45, mode: 1, tbri: 0),
          ),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentDeviceIdProvider.overrideWith((ref) => 'device-1'),
            sessionOverride,
            l10nProvider.overrideWithValue(strings),
          ],
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: true),
              child: NightlightScreen(),
            ),
          ),
        ),
      );
      final context = tester.element(find.byType(NightlightScreen));
      final container = ProviderScope.containerOf(context);

      expect(find.byType(NightlightEditor), findsOneWidget);
      expect(find.text(strings.nightlight), findsNWidgets(2));

      await tester.tap(find.byType(Switch));
      await tester.pump();

      expect(container.read(deviceCommandFailureProvider), isNotNull);
      expect(container.read(deviceStateProvider).requireValue.nl.on, isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
