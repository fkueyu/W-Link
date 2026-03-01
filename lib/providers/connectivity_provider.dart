import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

final isWifiConnectedProvider = Provider<bool>((ref) {
  // macOS/桌面端网络检测不可靠，默认为已连接
  if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) return true;
  final connectivity = ref.watch(connectivityProvider).valueOrNull ?? [];
  return connectivity.contains(ConnectivityResult.wifi);
});
