import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flux/widgets/animated_background.dart';

void main() {
  testWidgets('reduced motion does not leave a repeating frame callback', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: AnimatedBackground(child: Text('content')),
        ),
      ),
    );
    await tester.pump();

    expect(tester.binding.transientCallbackCount, 0);
    expect(find.text('content'), findsOneWidget);
  });
}
