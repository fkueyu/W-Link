import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/core.dart';
import '../models/models.dart';
import '../services/services.dart';
import 'common_providers.dart';

// ============================================================================
// 设备库管理 (全局列表)
// ============================================================================

final deviceListProvider =
    StateNotifierProvider<DeviceListNotifier, List<WledDevice>>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return DeviceListNotifier(prefs);
    });

class DeviceListNotifier extends StateNotifier<List<WledDevice>> {
  static const String _storageKey = AppConstants.keyDevices;
  final SharedPreferences _prefs;

  DeviceListNotifier(this._prefs) : super([]) {
    _loadDevices();
  }

  void _loadDevices() {
    try {
      final jsonStr = _prefs.getString(_storageKey);
      if (jsonStr != null) {
        final List<dynamic> list = jsonDecode(jsonStr);
        state = list
            .map((e) => WledDevice.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('[DeviceList] Error loading devices: $e');
    }
  }

  Future<void> _saveDevices() async {
    final jsonStr = jsonEncode(state.map((d) => d.toJson()).toList());
    await _prefs.setString(_storageKey, jsonStr);
  }

  Future<void> addDevice(WledDevice device) async {
    if (state.any((d) => d.id == device.id)) return;
    state = [...state, device];
    await _saveDevices();
  }

  Future<void> removeDevice(String deviceId) async {
    state = state.where((d) => d.id != deviceId).toList();
    await _saveDevices();
  }

  void updateOnlineStatus(String deviceId, bool isOnline, {String? realName}) {
    bool hasChanged = false;
    final now = DateTime.now();

    final newState = state.map((d) {
      if (d.id == deviceId) {
        final statusChanged = d.isOnline != isOnline;
        final nameUpdate =
            isOnline &&
            realName != null &&
            realName.isNotEmpty &&
            realName != d.originalName &&
            (d.originalName.startsWith('WLED ') || d.originalName == 'WLED');
        final timeUpdate =
            isOnline &&
            (d.lastSeen == null || now.difference(d.lastSeen!).inMinutes >= 1);

        if (!statusChanged && !nameUpdate && !timeUpdate) return d;
        hasChanged = true;
        return d.copyWith(
          isOnline: isOnline,
          lastSeen: timeUpdate ? now : d.lastSeen,
          originalName: nameUpdate ? realName : d.originalName,
        );
      }
      return d;
    }).toList();

    if (hasChanged) {
      state = newState;
      // 这里的逻辑已精简，必要时才保存
    }
  }

  Future<void> updateDeviceName(String deviceId, String newName) async {
    state = [
      for (final d in state)
        if (d.id == deviceId) d.copyWith(name: newName) else d,
    ];
    await _saveDevices();
  }
}

// ============================================================================
// 实时状态控制 (Notifier & Providers)
// ============================================================================

final currentDeviceIdProvider = StateProvider<String?>((ref) => null);

final currentDeviceProvider = Provider<WledDevice?>((ref) {
  final deviceId = ref.watch(currentDeviceIdProvider);
  if (deviceId == null) return null;
  final devices = ref.watch(deviceListProvider);
  final index = devices.indexWhere((d) => d.id == deviceId);
  return index != -1 ? devices[index] : null;
});

final wledApiProvider = Provider<WledApiService?>((ref) {
  final baseUrl = ref.watch(currentDeviceProvider.select((d) => d?.baseUrl));
  return baseUrl != null ? WledApiService(baseUrl: baseUrl) : null;
});

/// 当前聚焦设备的状态
final deviceStateProvider =
    StateNotifierProvider<DeviceStateNotifier, AsyncValue<WledState>>((ref) {
      final api = ref.watch(wledApiProvider);
      return DeviceStateNotifier(api, ref);
    });

/// ！！关键：设备列表卡片使用的 Family Provider ！！
final deviceFamilyStateProvider = StateNotifierProvider.family
    .autoDispose<DeviceStateNotifier, AsyncValue<WledState>, WledDevice>((
      ref,
      device,
    ) {
      final api = WledApiService(baseUrl: device.baseUrl);
      ref.onDispose(() => api.dispose());
      return DeviceStateNotifier(api, ref);
    });

class DeviceStateNotifier extends StateNotifier<AsyncValue<WledState>> {
  final WledApiService? _api;
  final Ref _ref;
  Timer? _refreshTimer;
  DateTime _lastUserActionTime = DateTime.fromMillisecondsSinceEpoch(0);

  static const _pollInterval = Duration(seconds: 5);
  static const _protectionSeconds = 8;
  int _failureCount = 0;

  DeviceStateNotifier(this._api, this._ref)
    : super(const AsyncValue.loading()) {
    if (_api != null) _startPolling();
  }

  void _startPolling() {
    _fetchState();
    _refreshTimer = Timer.periodic(_pollInterval, (_) => _fetchState());
  }

  Future<void> _fetchState() async {
    if (_api == null || !mounted) return;
    if (DateTime.now().difference(_lastUserActionTime).inSeconds <
        _protectionSeconds)
      return;

    try {
      final newState = await _api!.getState();
      if (!mounted) return;

      state = AsyncValue.data(newState);
      _failureCount = 0;

      final realName = newState.info.name;
      final ip = _api!.baseUrl.replaceAll('http://', '').split(':').first;
      _ref
          .read(deviceListProvider.notifier)
          .updateOnlineStatus(
            ip.replaceAll('.', '_'),
            true,
            realName: realName,
          );
    } catch (e, st) {
      if (!mounted) return;
      if (++_failureCount > 2) {
        if (e is TimeoutException || e.toString().contains('SocketException')) {
          state = AsyncValue.error('unreachable', st);
        } else {
          state = AsyncValue.error(e.toString(), st);
        }
      }
    }
  }

  Future<void> refresh() => _fetchState();

  Future<void> optimisticUpdate(
    WledState Function(WledState) updater,
    Future<WledState?> Function() apiCall,
  ) async {
    final current = state.valueOrNull;
    if (current == null) return;
    _lastUserActionTime = DateTime.now();
    state = AsyncValue.data(updater(current));
    try {
      await apiCall();
      _lastUserActionTime = DateTime.now();
    } catch (_) {}
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}

// ============================================================================
// 数据加载层 (效果集、调色板等)
// ============================================================================

final effectsProvider = FutureProvider<List<String>>(
  (ref) async => await ref.watch(wledApiProvider)?.getEffects() ?? [],
);
final effectMetadataProvider = FutureProvider<List<String>>(
  (ref) async => await ref.watch(wledApiProvider)?.getEffectMetadata() ?? [],
);
final palettesProvider = FutureProvider<List<String>>(
  (ref) async => await ref.watch(wledApiProvider)?.getPalettes() ?? [],
);
final deviceInfoProvider = FutureProvider<WledInfo?>(
  (ref) async => await ref.watch(wledApiProvider)?.getInfo(),
);

final presetsProvider = FutureProvider<List<WledPreset>>((ref) async {
  final api = ref.watch(wledApiProvider);
  if (api == null) return [];
  final presetsMap = await api.getPresets();
  final List<WledPreset> list = [];
  presetsMap.forEach((k, v) {
    final id = int.tryParse(k);
    if (id != null && id != 0 && v is Map<String, dynamic>)
      list.add(WledPreset.fromJson(id, v));
  });
  return list..sort((a, b) => a.id.compareTo(b.id));
});

final mdnsScanningProvider = StateProvider<bool>((ref) => false);
final discoveredDevicesProvider =
    StateNotifierProvider<DiscoveredDevicesNotifier, List<WledDevice>>(
      (ref) => DiscoveredDevicesNotifier(),
    );

class DiscoveredDevicesNotifier extends StateNotifier<List<WledDevice>> {
  DiscoveredDevicesNotifier() : super([]);
  void addDevice(WledDevice device) {
    if (!state.any((d) => d.id == device.id)) state = [...state, device];
  }

  void clear() => state = [];
}
