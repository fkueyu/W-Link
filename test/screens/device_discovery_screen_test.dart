import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flux/core/l10n.dart';
import 'package:flux/providers/common_providers.dart';
import 'package:flux/providers/device_providers.dart';
import 'package:flux/screens/device_discovery_screen.dart';
import 'package:flux/services/mdns_discovery_service.dart';

class DelayedHttp extends HttpOverrides {
  var response = Completer<HttpClientResponse>();
  Uri? requested;
  bool closed = false;
  int requests = 0;
  bool responseRead = false;
  String payload =
      '{"name":"延迟响应灯具","ver":"0.14.4","vid":2310160,"leds":{"count":60,"wv":false}}';
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      AuditHttpClient(this);
}

class AuditHttpClient implements HttpClient {
  AuditHttpClient(this.owner);
  final DelayedHttp owner;
  @override
  set connectionTimeout(Duration? value) {}
  @override
  void close({bool force = false}) {
    owner.closed = true;
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    owner.requests++;
    owner.requested = url;
    return AuditRequest(owner);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class AuditRequest implements HttpClientRequest {
  AuditRequest(this.owner);
  final DelayedHttp owner;
  @override
  Future<HttpClientResponse> close() => owner.response.future;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class AuditResponse extends Stream<List<int>> implements HttpClientResponse {
  AuditResponse(this.owner);
  final DelayedHttp owner;
  @override
  int get statusCode => 200;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    owner.responseRead = true;
    return Stream.value(utf8.encode(owner.payload)).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<ProviderContainer> host(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        l10nProvider.overrideWithValue(ZhStrings()),
      ],
      child: const MaterialApp(home: DeviceDiscoveryScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
  return ProviderScope.containerOf(
    tester.element(find.byType(DeviceDiscoveryScreen)),
  );
}

Future<void> open(WidgetTester tester) async {
  await tester.tap(find.text(ZhStrings().manualAdd));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.enterText(find.byType(TextField), '10.0.0.88');
  await tester.tap(find.widgetWithText(FilledButton, ZhStrings().addDevice));
  await tester.pump();
}

void main() {
  late DelayedHttp network;
  tearDown(() {
    HttpOverrides.global = null;
  });
  testWidgets('延迟验证保留输入、防止重复提交，成功持久化后关闭', (tester) async {
    network = DelayedHttp();
    HttpOverrides.global = network;
    final container = await host(tester);
    await open(tester);
    expect(find.byType(TextField), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).keyboardType,
      TextInputType.url,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(network.requests, 1);
    network.response.complete(AuditResponse(network));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(container.read(deviceListProvider).single.ip, '10.0.0.88');
    expect(find.byType(TextField), findsNothing);
    expect(network.closed, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 11));
  });
  testWidgets('验证失败保留输入并允许重试', (tester) async {
    network = DelayedHttp();
    HttpOverrides.global = network;
    final container = await host(tester);
    await open(tester);
    network.response.completeError(const SocketException('offline'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(TextField), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '10.0.0.88',
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    expect(find.text(ZhStrings().connectionFailed), findsOneWidget);
    network.response = Completer<HttpClientResponse>();
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    network.response.complete(AuditResponse(network));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(container.read(deviceListProvider).single.ip, '10.0.0.88');
    expect(network.requests, 2);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 11));
  });
  testWidgets('普通JSON服务不能冒充WLED被添加，输入保留以便修正', (tester) async {
    network = DelayedHttp()..payload = '{"name":"网络存储设备"}';
    HttpOverrides.global = network;
    final container = await host(tester);
    await open(tester);
    network.response.complete(AuditResponse(network));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(container.read(deviceListProvider), isEmpty);
    expect(find.text(ZhStrings().connectionFailed), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '10.0.0.88',
    );
    expect(network.closed, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 11));
  });
  testWidgets('验证期间取消后晚到成功不添加设备', (tester) async {
    network = DelayedHttp();
    HttpOverrides.global = network;
    final container = await host(tester);
    await open(tester);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text(ZhStrings().cancel));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    network.response.complete(AuditResponse(network));
    await tester.pump();
    expect(container.read(deviceListProvider), isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 11));
  });
  testWidgets('请求连接后仍有完整超时并关闭客户端', (tester) async {
    network = DelayedHttp();
    HttpOverrides.global = network;
    var completed = false;
    final future = MdnsDiscoveryService.verifyDevice('10.0.0.88').then((value) {
      completed = true;
      return value;
    });
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(completed, isTrue);
    expect(await future, isNull);
    expect(network.closed, isTrue);
  });
  testWidgets('验证期间页面销毁后不访问已销毁状态', (tester) async {
    network = DelayedHttp();
    HttpOverrides.global = network;
    await host(tester);
    await open(tester);
    await tester.pumpWidget(const SizedBox());
    network.response.complete(AuditResponse(network));
    await tester.pump();
    await tester.pump(const Duration(seconds: 11));
    expect(tester.takeException(), isNull);
    expect(network.closed, isTrue);
  });
  testWidgets('扫描错误显示失败并能重试', (tester) async {
    const channel = MethodChannel('flux/mdns_discovery');
    var starts = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method == 'startDiscovery' && ++starts == 1) {
        throw PlatformException(code: 'permission');
      }
      return null;
    });
    await host(tester);
    expect(find.text('扫描失败'), findsOneWidget);
    expect(find.text(ZhStrings().scanComplete), findsNothing);
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pump();
    expect(find.text(ZhStrings().scanningNetwork), findsOneWidget);
    await tester.pump(const Duration(seconds: 11));
    expect(find.text(ZhStrings().scanComplete), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    );
  });
}
