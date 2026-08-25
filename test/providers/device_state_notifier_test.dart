import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flux/models/wled_device.dart';
import 'package:flux/models/wled_state.dart';
import 'package:flux/providers/common_providers.dart';
import 'package:flux/providers/device_providers.dart';
import 'package:flux/services/wled_api_service.dart';

void main() {
  late ProviderContainer container;
  late StateNotifierProvider<DeviceStateNotifier, AsyncValue<WledState>>
  provider;

  setUp(() {
    provider =
        StateNotifierProvider<DeviceStateNotifier, AsyncValue<WledState>>(
          (ref) => DeviceStateNotifier(
            null,
            ref,
            deviceId: 'device-1',
            initialState: const WledState(on: true, bri: 10),
          ),
        );
    container = ProviderContainer();
  });

  tearDown(() => container.dispose());

  test(
    'successful optimistic update adopts the authoritative response',
    () async {
      final notifier = container.read(provider.notifier);

      final result = await notifier.optimisticUpdate(
        (state) => state.copyWith(bri: 20),
        () async => const WledState(on: true, bri: 18),
      );

      expect(container.read(provider).requireValue.bri, 18);
      expect(result.isSuccess, isTrue);
      expect(notifier.lastCommandError, isNull);
    },
  );

  test(
    'nightlight command updates immediately then adopts authoritative state',
    () async {
      final response = Completer<http.Response>();
      final api = WledApiService(
        baseUrl: 'http://wled.local',
        client: MockClient((_) => response.future),
      );
      addTearDown(api.dispose);
      final nightlightProvider =
          StateNotifierProvider<DeviceStateNotifier, AsyncValue<WledState>>(
            (ref) => DeviceStateNotifier(
              api,
              ref,
              deviceId: 'device-1',
              initialState: const WledState(
                on: true,
                bri: 120,
                nl: WledNightlight(on: false, dur: 60, mode: 1, tbri: 0),
              ),
            ),
          );
      final nightlightContainer = ProviderContainer();
      addTearDown(nightlightContainer.dispose);
      final notifier = nightlightContainer.read(nightlightProvider.notifier);
      const requested = WledNightlight(on: true, dur: 45, mode: 2, tbri: 32);

      final command = notifier.updateNightlight(requested);

      expect(
        nightlightContainer.read(nightlightProvider).requireValue.nl.on,
        isTrue,
      );
      expect(
        nightlightContainer.read(nightlightProvider).requireValue.nl.dur,
        45,
      );

      response.complete(
        http.Response(
          jsonEncode({
            'on': true,
            'bri': 120,
            'nl': {'on': true, 'dur': 44, 'mode': 2, 'tbri': 32, 'rem': 90},
          }),
          200,
        ),
      );
      final result = await command;

      expect(result.isSuccess, isTrue);
      expect(
        nightlightContainer.read(nightlightProvider).requireValue.nl.dur,
        44,
      );
      expect(
        nightlightContainer.read(nightlightProvider).requireValue.nl.rem,
        90,
      );
    },
  );

  test(
    'failed nightlight command restores its value and publishes once',
    () async {
      final api = WledApiService(
        baseUrl: 'http://wled.local',
        client: MockClient((_) async => http.Response('busy', 503)),
      );
      addTearDown(api.dispose);
      const original = WledNightlight(on: false, dur: 60, mode: 1, tbri: 0);
      final nightlightProvider =
          StateNotifierProvider<DeviceStateNotifier, AsyncValue<WledState>>(
            (ref) => DeviceStateNotifier(
              api,
              ref,
              deviceId: 'device-1',
              initialState: const WledState(on: true, bri: 120, nl: original),
            ),
          );
      final nightlightContainer = ProviderContainer();
      addTearDown(nightlightContainer.dispose);
      final failures = <DeviceCommandFailure>[];
      final subscription = nightlightContainer.listen(
        deviceCommandFailureProvider,
        (_, next) {
          if (next != null) failures.add(next);
        },
      );
      addTearDown(subscription.close);

      final result = await nightlightContainer
          .read(nightlightProvider.notifier)
          .updateNightlight(
            const WledNightlight(on: true, dur: 30, mode: 2, tbri: 16),
          );

      expect(result.isFailure, isTrue);
      final restored = nightlightContainer
          .read(nightlightProvider)
          .requireValue
          .nl;
      expect(restored.on, isFalse);
      expect(restored.dur, 60);
      expect(restored.mode, 1);
      expect(restored.tbri, 0);
      expect(failures, hasLength(1));
      expect(failures.single.deviceId, 'device-1');
    },
  );

  test('an in-flight GET cannot overwrite a newer command result', () async {
    final getStarted = Completer<void>();
    final staleGetResponse = Completer<http.Response>();
    final api = WledApiService(
      baseUrl: 'http://wled.local',
      client: MockClient((request) async {
        if (request.method == 'GET') {
          getStarted.complete();
          return staleGetResponse.future;
        }
        return http.Response(
          jsonEncode({
            'on': true,
            'bri': 120,
            'nl': {'on': true, 'dur': 30, 'mode': 2, 'tbri': 16},
          }),
          200,
        );
      }),
    );
    addTearDown(api.dispose);
    final staleFetchProvider =
        StateNotifierProvider<DeviceStateNotifier, AsyncValue<WledState>>(
          (ref) => DeviceStateNotifier(
            api,
            ref,
            initialState: const WledState(
              on: true,
              bri: 120,
              nl: WledNightlight(on: false, dur: 60, mode: 1, tbri: 0),
            ),
          ),
        );
    final staleFetchContainer = ProviderContainer();
    addTearDown(staleFetchContainer.dispose);
    final notifier = staleFetchContainer.read(staleFetchProvider.notifier);
    await getStarted.future;

    await notifier.updateNightlight(
      const WledNightlight(on: true, dur: 30, mode: 2, tbri: 16),
    );
    staleGetResponse.complete(
      http.Response(
        jsonEncode({
          'state': {
            'on': true,
            'bri': 120,
            'nl': {'on': false, 'dur': 60, 'mode': 1, 'tbri': 0},
          },
          'info': {'ver': '0.15.0', 'vid': 2401010, 'leds': {}, 'name': 'WLED'},
        }),
        200,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final nightlight = staleFetchContainer
        .read(staleFetchProvider)
        .requireValue
        .nl;
    expect(nightlight.on, isTrue);
    expect(nightlight.dur, 30);
  });

  test('a stale GET failure cannot replace a newer command result', () async {
    final thirdGetStarted = Completer<void>();
    final staleFailureResponse = Completer<http.Response>();
    var getCount = 0;
    final api = WledApiService(
      baseUrl: 'http://wled.local',
      client: MockClient((request) async {
        if (request.method == 'GET') {
          getCount++;
          if (getCount < 3) return http.Response('offline', 503);
          thirdGetStarted.complete();
          return staleFailureResponse.future;
        }
        return http.Response(
          jsonEncode({
            'on': true,
            'bri': 120,
            'nl': {'on': true, 'dur': 30, 'mode': 2, 'tbri': 16},
          }),
          200,
        );
      }),
    );
    addTearDown(api.dispose);
    final staleFailureProvider =
        StateNotifierProvider<DeviceStateNotifier, AsyncValue<WledState>>(
          (ref) => DeviceStateNotifier(
            api,
            ref,
            initialState: const WledState(
              on: true,
              bri: 120,
              nl: WledNightlight(on: false, dur: 60, mode: 1, tbri: 0),
            ),
          ),
        );
    final staleFailureContainer = ProviderContainer();
    addTearDown(staleFailureContainer.dispose);
    final notifier = staleFailureContainer.read(staleFailureProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await notifier.forceRefresh();

    final staleFetch = notifier.forceRefresh();
    await thirdGetStarted.future;
    await notifier.updateNightlight(
      const WledNightlight(on: true, dur: 30, mode: 2, tbri: 16),
    );
    staleFailureResponse.complete(http.Response('offline', 503));
    await staleFetch;

    final result = staleFailureContainer.read(staleFailureProvider);
    expect(result.hasError, isFalse);
    expect(result.requireValue.nl.on, isTrue);
    expect(result.requireValue.nl.dur, 30);
  });

  test(
    'overlapping force refresh calls await the same in-flight GET',
    () async {
      final getStarted = Completer<void>();
      final response = Completer<http.Response>();
      var getCount = 0;
      final api = WledApiService(
        baseUrl: 'http://wled.local',
        client: MockClient((request) {
          getCount++;
          getStarted.complete();
          return response.future;
        }),
      );
      addTearDown(api.dispose);
      final refreshProvider =
          StateNotifierProvider<DeviceStateNotifier, AsyncValue<WledState>>(
            (ref) => DeviceStateNotifier(
              api,
              ref,
              initialState: const WledState(on: true, bri: 120),
            ),
          );
      final refreshContainer = ProviderContainer();
      addTearDown(refreshContainer.dispose);
      final notifier = refreshContainer.read(refreshProvider.notifier);
      await getStarted.future;

      var firstCompleted = false;
      var secondCompleted = false;
      final first = notifier.forceRefresh().then((_) => firstCompleted = true);
      final second = notifier.forceRefresh().then(
        (_) => secondCompleted = true,
      );
      await Future<void>.delayed(Duration.zero);

      expect(getCount, 1);
      expect(firstCompleted, isFalse);
      expect(secondCompleted, isFalse);

      response.complete(
        http.Response(
          jsonEncode({
            'state': {'on': true, 'bri': 118},
            'info': {
              'ver': '0.15.0',
              'vid': 2401010,
              'leds': {},
              'name': 'WLED',
            },
          }),
          200,
        ),
      );
      await Future.wait([first, second]);
      expect(refreshContainer.read(refreshProvider).requireValue.bri, 118);
    },
  );

  test('device writes are invoked serially', () async {
    final firstStarted = Completer<void>();
    final secondStarted = Completer<void>();
    final firstResponse = Completer<http.Response>();
    final secondResponse = Completer<http.Response>();
    var postCount = 0;
    final api = WledApiService(
      baseUrl: 'http://wled.local',
      client: MockClient((request) {
        if (request.method == 'GET') return Completer<http.Response>().future;
        postCount++;
        if (postCount == 1) {
          firstStarted.complete();
          return firstResponse.future;
        }
        secondStarted.complete();
        return secondResponse.future;
      }),
    );
    addTearDown(api.dispose);
    final serialProvider =
        StateNotifierProvider<DeviceStateNotifier, AsyncValue<WledState>>(
          (ref) => DeviceStateNotifier(
            api,
            ref,
            initialState: const WledState(
              on: true,
              bri: 120,
              nl: WledNightlight(on: false, dur: 60, mode: 1, tbri: 0),
            ),
          ),
        );
    final serialContainer = ProviderContainer();
    addTearDown(serialContainer.dispose);
    final notifier = serialContainer.read(serialProvider.notifier);

    final first = notifier.updateNightlight(
      const WledNightlight(on: true, dur: 30, mode: 1, tbri: 0),
    );
    final second = notifier.updateNightlight(
      const WledNightlight(on: true, dur: 15, mode: 2, tbri: 16),
    );
    await firstStarted.future;
    expect(postCount, 1);

    firstResponse.complete(
      http.Response(
        jsonEncode({
          'on': true,
          'bri': 120,
          'nl': {'on': true, 'dur': 30, 'mode': 1, 'tbri': 0},
        }),
        200,
      ),
    );
    await secondStarted.future;
    expect(postCount, 2);
    secondResponse.complete(
      http.Response(
        jsonEncode({
          'on': true,
          'bri': 120,
          'nl': {'on': true, 'dur': 15, 'mode': 2, 'tbri': 16},
        }),
        200,
      ),
    );

    expect((await first).isSuccess, isTrue);
    expect((await second).isSuccess, isTrue);
    expect(serialContainer.read(serialProvider).requireValue.nl.dur, 15);
  });

  test(
    'two failed overlapping commands restore the confirmed baseline',
    () async {
      final responses = <Completer<http.Response>>[
        Completer<http.Response>(),
        Completer<http.Response>(),
      ];
      var postCount = 0;
      final api = WledApiService(
        baseUrl: 'http://wled.local',
        client: MockClient((request) {
          if (request.method == 'GET') return Completer<http.Response>().future;
          return responses[postCount++].future;
        }),
      );
      addTearDown(api.dispose);
      const original = WledNightlight(on: false, dur: 60, mode: 1, tbri: 0);
      final rollbackProvider =
          StateNotifierProvider<DeviceStateNotifier, AsyncValue<WledState>>(
            (ref) => DeviceStateNotifier(
              api,
              ref,
              initialState: const WledState(on: true, bri: 120, nl: original),
            ),
          );
      final rollbackContainer = ProviderContainer();
      addTearDown(rollbackContainer.dispose);
      final notifier = rollbackContainer.read(rollbackProvider.notifier);

      final first = notifier.updateNightlight(
        const WledNightlight(on: true, dur: 30, mode: 1, tbri: 0),
      );
      final second = notifier.updateNightlight(
        const WledNightlight(on: true, dur: 15, mode: 2, tbri: 16),
      );
      await Future<void>.delayed(Duration.zero);
      responses[0].complete(http.Response('busy', 503));
      await Future<void>.delayed(Duration.zero);
      responses[1].complete(http.Response('busy', 503));
      await Future.wait([first, second]);

      final restored = rollbackContainer.read(rollbackProvider).requireValue.nl;
      expect(restored.on, isFalse);
      expect(restored.dur, 60);
      expect(restored.mode, 1);
      expect(restored.tbri, 0);
    },
  );

  test(
    'failed optimistic update restores its snapshot and exposes error',
    () async {
      final notifier = container.read(provider.notifier);
      final failures = <DeviceCommandFailure>[];
      final subscription = container.listen(deviceCommandFailureProvider, (
        _,
        next,
      ) {
        if (next != null) failures.add(next);
      });
      addTearDown(subscription.close);

      final result = await notifier.optimisticUpdate(
        (state) => state.copyWith(bri: 20),
        () async => throw StateError('offline'),
      );

      expect(container.read(provider).requireValue.bri, 10);
      expect(result.isFailure, isTrue);
      expect(result.error, isA<StateError>());
      expect(notifier.lastCommandError, isA<StateError>());
      expect(failures, hasLength(1));
      expect(failures.single.sequence, 1);
      expect(failures.single.deviceId, 'device-1');
      expect(failures.single.error, isA<StateError>());
    },
  );

  test('an older response cannot overwrite a newer command', () async {
    final notifier = container.read(provider.notifier);
    final firstCompleter = Completer<WledState>();

    final first = notifier.optimisticUpdate(
      (state) => state.copyWith(bri: 20),
      () => firstCompleter.future,
    );
    final second = notifier.optimisticUpdate(
      (state) => state.copyWith(bri: 30),
      () async => const WledState(on: true, bri: 28),
    );
    firstCompleter.complete(const WledState(on: true, bri: 19));
    await first;
    await second;

    expect(container.read(provider).requireValue.bri, 28);
  });

  test(
    'detail projection observes the same session used by a device card',
    () async {
      final sessionProvider = deviceSessionProvider.overrideWith(
        (ref, deviceId) => DeviceStateNotifier(
          null,
          ref,
          deviceId: deviceId,
          initialState: const WledState(on: true, bri: 10),
        ),
      );
      final sessionContainer = ProviderContainer(
        overrides: [
          currentDeviceIdProvider.overrideWith((ref) => 'device-1'),
          sessionProvider,
        ],
      );
      addTearDown(sessionContainer.dispose);

      final cardSession = sessionContainer.read(
        deviceSessionProvider('device-1').notifier,
      );
      await cardSession.optimisticUpdate(
        (state) => state.copyWith(bri: 42),
        () async => const WledState(on: true, bri: 40),
      );

      expect(sessionContainer.read(deviceStateProvider).requireValue.bri, 40);
      expect(
        identical(
          cardSession,
          sessionContainer.read(currentDeviceSessionNotifierProvider),
        ),
        isTrue,
      );
    },
  );

  test(
    'online status changes do not change device connection identity',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final deviceContainer = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      );
      addTearDown(deviceContainer.dispose);
      const device = WledDevice(
        id: 'device-1',
        name: 'Desk',
        originalName: 'WLED',
        ip: '192.168.1.20',
        port: 81,
      );
      await deviceContainer.read(deviceListProvider.notifier).addDevice(device);
      final changes = <Object?>[];
      final subscription = deviceContainer.listen(
        deviceConnectionProvider(device.id),
        (_, next) => changes.add(next),
      );
      addTearDown(subscription.close);

      deviceContainer
          .read(deviceListProvider.notifier)
          .updateOnlineStatus(device.id, true, realName: 'Desk WLED');

      expect(changes, isEmpty);
      expect(deviceContainer.read(deviceConnectionProvider(device.id)), (
        ip: '192.168.1.20',
        port: 81,
        baseUrl: 'http://192.168.1.20:81',
      ));
    },
  );

  test('a disposed session safely rejects a delayed command', () async {
    final delayedProvider =
        StateNotifierProvider<DeviceStateNotifier, AsyncValue<WledState>>(
          (ref) => DeviceStateNotifier(
            null,
            ref,
            deviceId: 'old-device',
            initialState: const WledState(on: true, bri: 10),
          ),
        );
    final delayedContainer = ProviderContainer();
    final notifier = delayedContainer.read(delayedProvider.notifier);
    delayedContainer.dispose();

    final result = await notifier.optimisticUpdate(
      (state) => state.copyWith(bri: 20),
      () async => const WledState(on: true, bri: 20),
    );

    expect(result.isFailure, isTrue);
    expect(result.error, isA<StateError>());
  });

  test(
    'a captured session remains bound to its device after selection changes',
    () async {
      final sessionProvider = deviceSessionProvider.overrideWith(
        (ref, deviceId) => DeviceStateNotifier(
          null,
          ref,
          deviceId: deviceId,
          initialState: const WledState(on: true, bri: 10),
        ),
      );
      final selectionContainer = ProviderContainer(
        overrides: [
          currentDeviceIdProvider.overrideWith((ref) => 'device-1'),
          sessionProvider,
        ],
      );
      addTearDown(selectionContainer.dispose);
      final captured = selectionContainer.read(
        currentDeviceSessionNotifierProvider,
      );

      selectionContainer.read(currentDeviceIdProvider.notifier).state =
          'device-2';
      await captured.optimisticUpdate(
        (state) => state.copyWith(bri: 42),
        () async => const WledState(on: true, bri: 40),
      );

      expect(
        selectionContainer
            .read(deviceSessionProvider('device-1'))
            .requireValue
            .bri,
        40,
      );
      expect(
        selectionContainer
            .read(deviceSessionProvider('device-2'))
            .requireValue
            .bri,
        10,
      );
    },
  );
}
