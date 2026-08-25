import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flux/models/wled_state.dart';
import 'package:flux/services/wled_api_service.dart';

void main() {
  group('WledApiService', () {
    test('setNightlight sends only writable nightlight fields', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/json/state');
        expect(jsonDecode(request.body), {
          'nl': {'on': true, 'dur': 45, 'mode': 2, 'tbri': 32},
          'v': true,
        });
        return http.Response(
          jsonEncode({
            'on': true,
            'bri': 128,
            'nl': {'on': true, 'dur': 45, 'mode': 2, 'tbri': 32, 'rem': 90},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final api = WledApiService(baseUrl: 'http://wled.local', client: client);

      final state = await api.setNightlight(
        const WledNightlight(on: true, dur: 45, mode: 2, tbri: 32, rem: 100),
      );

      expect(state?.nl.rem, 90);
      api.dispose();
    });

    test('setState returns the authoritative state from WLED', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/json/state');
        expect(jsonDecode(request.body), {'on': true, 'v': true});
        return http.Response(
          jsonEncode({'on': true, 'bri': 73, 'seg': <Object>[]}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final api = WledApiService(baseUrl: 'http://wled.local', client: client);

      final state = await api.setState({'on': true});

      expect(state.on, isTrue);
      expect(state.bri, 73);
      api.dispose();
    });

    test('setState throws a typed error for a non-success response', () async {
      final client = MockClient((_) async => http.Response('device busy', 503));
      final api = WledApiService(baseUrl: 'http://wled.local', client: client);

      await expectLater(
        api.setState({'bri': 120}),
        throwsA(
          isA<WledApiException>()
              .having((error) => error.statusCode, 'statusCode', 503)
              .having((error) => error.path, 'path', '/json/state'),
        ),
      );
      api.dispose();
    });

    test('getState throws a typed error before parsing a failed response', () {
      final client = MockClient(
        (_) async => http.Response('<html>no</html>', 404),
      );
      final api = WledApiService(baseUrl: 'http://wled.local', client: client);

      expect(
        api.getState(),
        throwsA(
          isA<WledApiException>()
              .having((error) => error.statusCode, 'statusCode', 404)
              .having((error) => error.path, 'path', '/json'),
        ),
      );
      api.dispose();
    });

    test('setState wraps malformed success payloads in a typed error', () {
      final client = MockClient((_) async => http.Response('{broken', 200));
      final api = WledApiService(baseUrl: 'http://wled.local', client: client);

      expect(
        api.setState({'on': true}),
        throwsA(
          isA<WledApiException>()
              .having((error) => error.statusCode, 'statusCode', 200)
              .having((error) => error.path, 'path', '/json/state'),
        ),
      );
      api.dispose();
    });

    test('getState wraps transport failures in the same typed contract', () {
      final client = MockClient(
        (_) async => throw TimeoutException('device did not answer'),
      );
      final api = WledApiService(baseUrl: 'http://wled.local', client: client);

      expect(
        api.getState(),
        throwsA(
          isA<WledApiException>()
              .having((error) => error.statusCode, 'statusCode', isNull)
              .having((error) => error.path, 'path', '/json')
              .having((error) => error.cause, 'cause', isA<TimeoutException>()),
        ),
      );
      api.dispose();
    });
  });
}
