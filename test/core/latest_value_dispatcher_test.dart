import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flux/core/latest_value_dispatcher.dart';

void main() {
  test('keeps only the latest value while one send is in flight', () async {
    final firstSend = Completer<void>();
    final sent = <int>[];
    final dispatcher = LatestValueDispatcher<int>((value) async {
      sent.add(value);
      if (value == 1) await firstSend.future;
    });

    dispatcher.submit(1);
    dispatcher.submit(2);
    dispatcher.submit(3);

    expect(sent, [1]);
    firstSend.complete();
    await dispatcher.idle;
    expect(sent, [1, 3]);

    dispatcher.submit(4);
    expect(sent, [1, 3, 4]);
    await dispatcher.idle;
  });

  test(
    'dispose delivers the pending latest value but ignores later submissions',
    () async {
      final firstSend = Completer<void>();
      final sent = <int>[];
      final dispatcher = LatestValueDispatcher<int>((value) async {
        sent.add(value);
        if (value == 1) await firstSend.future;
      });

      dispatcher.submit(1);
      dispatcher.submit(2);
      dispatcher.dispose();
      dispatcher.submit(3);
      firstSend.complete();
      await dispatcher.idle;

      expect(sent, [1, 2]);
    },
  );

  test(
    'reports send errors and continues with the pending latest value',
    () async {
      final errors = <Object>[];
      final sent = <int>[];
      final dispatcher = LatestValueDispatcher<int>((value) async {
        sent.add(value);
        if (value == 1) throw StateError('offline');
      }, onError: errors.add);

      dispatcher.submit(1);
      dispatcher.submit(2);
      await dispatcher.idle;

      expect(sent, [1, 2]);
      expect(errors, hasLength(1));
      expect(errors.single, isA<StateError>());
    },
  );
}
