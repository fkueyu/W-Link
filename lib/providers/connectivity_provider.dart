import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

final isWifiConnectedProvider = Provider<bool>((ref) {
  final connectivity = ref.watch(connectivityProvider).valueOrNull ?? [];
  return connectivity.contains(ConnectivityResult.wifi);
});
