import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flux/widgets/device_ambient_background.dart';

void main() {
  testWidgets('active device color adds an ambient glow behind content', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DeviceAmbientBackground(
          color: Color(0xFF00AAFF),
          isActive: true,
          child: Text('controls'),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('device-ambient-glow')), findsOneWidget);
    expect(find.text('controls'), findsOneWidget);
  });

  testWidgets('inactive device removes the colored glow but keeps content', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DeviceAmbientBackground(
          color: Color(0xFF00AAFF),
          isActive: false,
          child: Text('controls'),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('device-ambient-glow')), findsNothing);
    expect(find.text('controls'), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
  });
}
