import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 可替换连接源，页面与插件实例不直接耦合。
final connectivitySourceProvider = Provider<Connectivity>(
  (ref) => Connectivity(),
);

final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  final source = ref.watch(connectivitySourceProvider);
  final controller = StreamController<List<ConnectivityResult>>();
  var generation = 0;
  var disposed = false;
  Future<void> refresh() async {
    final request = ++generation;
    try {
      final result = await source.checkConnectivity();
      if (!disposed && request == generation) controller.add(result);
    } catch (error, stack) {
      if (!disposed && request == generation) controller.addError(error, stack);
    }
  }

  final subscription = source.onConnectivityChanged.listen(
    (result) {
      generation++;
      if (!disposed) controller.add(result);
    },
    onError: (Object error, StackTrace stack) {
      generation++;
      if (!disposed) controller.addError(error, stack);
    },
  );
  final observer = _ConnectivityObserver(refresh);
  WidgetsBinding.instance.addObserver(observer);
  unawaited(refresh());
  ref.onDispose(() {
    disposed = true;
    WidgetsBinding.instance.removeObserver(observer);
    unawaited(subscription.cancel());
    unawaited(controller.close());
  });
  return controller.stream;
});

class _ConnectivityObserver extends WidgetsBindingObserver {
  _ConnectivityObserver(this.refresh);
  final Future<void> Function() refresh;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }
}

final isWifiConnectedProvider = Provider<bool>((ref) {
  // macOS/桌面端网络检测不可靠，默认为已连接
  if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) return true;
  final connectivity = ref.watch(connectivityProvider).valueOrNull;
  if (connectivity == null) return true;
  return connectivity.contains(ConnectivityResult.wifi);
});
