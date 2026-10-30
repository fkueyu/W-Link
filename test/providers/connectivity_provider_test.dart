// ignore_for_file: depend_on_referenced_packages
import 'dart:async';
import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flux/providers/connectivity_provider.dart';

class Network extends ConnectivityPlatform {
  final events = StreamController<List<ConnectivityResult>>.broadcast(
    sync: true,
  );
  final checks = <Completer<List<ConnectivityResult>>>[];
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => events.stream;
  @override
  Future<List<ConnectivityResult>> checkConnectivity() {
    final pending = Completer<List<ConnectivityResult>>();
    checks.add(pending);
    return pending.future;
  }
}

void main() {
  testWidgets('初始检查、恢复检查且迟到检查不覆盖新事件，销毁移除观察者', (tester) async {
    final previous = ConnectivityPlatform.instance;
    final network = Network();
    ConnectivityPlatform.instance = network;
    final container = ProviderContainer();
    final sub = container.listen(connectivityProvider, (_, _) {});
    var disposed = false;
    addTearDown(() {
      if (!disposed) {
        sub.close();
        container.dispose();
      }
      ConnectivityPlatform.instance = previous;
      network.events.close();
    });
    await tester.pump();
    expect(network.checks.length, 1);
    network.events.add([ConnectivityResult.wifi]);
    await tester.pump();
    network.checks.first.complete([ConnectivityResult.none]);
    await tester.pump();
    expect(container.read(connectivityProvider).value, [
      ConnectivityResult.wifi,
    ]);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(network.checks.length, 2);
    network.checks.last.complete([ConnectivityResult.none]);
    await tester.pump();
    expect(container.read(connectivityProvider).value, [
      ConnectivityResult.none,
    ]);
    sub.close();
    container.dispose();
    disposed = true;
    await tester.pump();
    expect(network.events.hasListener, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(network.checks.length, 2);
  });
}
