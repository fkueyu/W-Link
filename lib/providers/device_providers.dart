import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/core.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../services/app_groups_service.dart';
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
        // 初始同步到 App Groups
        AppGroupsService.syncDevices(state);
      }
    } catch (e) {
      debugPrint('[DeviceList] Error loading devices: $e');
    }
  }

  Future<void> _saveDevices() async {
    final jsonStr = jsonEncode(state.map((d) => d.toJson()).toList());
    await _prefs.setString(_storageKey, jsonStr);
    // 同步到 App Groups，供 iOS 快捷指令使用
    AppGroupsService.syncDevices(state);
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
  final ws = ref.watch(wledWebSocketProvider);
  return baseUrl != null ? WledApiService(baseUrl: baseUrl, ws: ws) : null;
});

/// 当前聚焦设备的 WebSocket 服务
final wledWebSocketProvider = Provider<WledWebSocketService?>((ref) {
  final device = ref.watch(currentDeviceProvider);
  if (device == null) return null;
  final ws = WledWebSocketService(host: device.ip, port: device.port);
  ref.onDispose(() => ws.dispose());
  return ws;
});

/// 当前聚焦设备的状态
final deviceStateProvider =
    StateNotifierProvider<DeviceStateNotifier, AsyncValue<WledState>>((ref) {
      final api = ref.watch(wledApiProvider);
      final ws = ref.watch(wledWebSocketProvider);
      return DeviceStateNotifier(api, ref, webSocket: ws);
    });

/// ！！关键：设备列表卡片使用的 Family Provider ！！
/// 现已全面接入 WebSocket 实时通信 + HTTP 轮询降级
final deviceFamilyStateProvider = StateNotifierProvider.family
    .autoDispose<DeviceStateNotifier, AsyncValue<WledState>, String>((
      ref,
      deviceId,
    ) {
      final devices = ref.read(deviceListProvider);
      final device = devices.firstWhere(
        (d) => d.id == deviceId,
        orElse: () =>
            WledDevice(id: deviceId, name: '', originalName: '', ip: '0.0.0.0'),
      );

      final ws = WledWebSocketService(host: device.ip, port: device.port);
      final api = WledApiService(baseUrl: device.baseUrl, ws: ws);

      ref.onDispose(() {
        api.dispose();
        ws.dispose();
      });

      return DeviceStateNotifier(api, ref, webSocket: ws, deviceId: deviceId);
    });

class DeviceStateNotifier extends StateNotifier<AsyncValue<WledState>> {
  final WledApiService? _api;
  final Ref _ref;
  final WledWebSocketService? _ws;
  final String? _deviceId; // 非 null 表示来自 family provider

  Timer? _refreshTimer;
  StreamSubscription? _wsStateSubscription;
  StreamSubscription? _wsConnectionSubscription;
  DateTime _lastUserActionTime = DateTime.fromMillisecondsSinceEpoch(0);

  static const _pollInterval = Duration(seconds: 5);
  static const _protectionSeconds = 8;
  int _failureCount = 0;
  bool _wsConnected = false;

  /// [deviceId] 非 null → family provider；null → detail provider
  DeviceStateNotifier(
    this._api,
    this._ref, {
    WledWebSocketService? webSocket,
    String? deviceId,
  }) : _ws = webSocket,
       _deviceId = deviceId,
       super(const AsyncValue.loading()) {
    if (_api != null) {
      if (_ws != null) {
        _initWebSocket();
      } else {
        _startPolling();
      }
    }
  }

  bool get _isFamily => _deviceId != null;
  bool get _isDetail => !_isFamily;

  // ===========================================================================
  // WebSocket
  // ===========================================================================

  void _initWebSocket() {
    final ws = _ws;
    if (ws == null) return;

    // 先启动 HTTP 轮询获取初始状态，WS 连接成功后停止
    _startPolling();

    // 监听 WS 状态推送
    _wsStateSubscription = ws.stateStream.listen((wsState) {
      if (!mounted) return;
      if (DateTime.now().difference(_lastUserActionTime).inSeconds <
          _protectionSeconds) {
        return; // 用户操作保护期内忽略 WS 推送
      }
      state = AsyncValue.data(wsState);
      _failureCount = 0;

      // 更新在线状态
      final realName = wsState.info.name;
      _updateOnlineStatus(true, realName: realName);
    });

    // 监听 WS 连接状态
    _wsConnectionSubscription = ws.connectionStream.listen((connState) {
      if (!mounted) return;
      final wasConnected = _wsConnected;
      _wsConnected = connState == WsConnectionState.connected;

      if (_wsConnected && !wasConnected) {
        // WS 连接成功 → 停止 HTTP 轮询
        debugPrint('[DeviceState] WS connected, stopping HTTP polling');
        _stopPolling();
      } else if (!_wsConnected && wasConnected) {
        // WS 断连 → 恢复 HTTP 轮询
        debugPrint('[DeviceState] WS disconnected, resuming HTTP polling');
        _startPolling();
      }
    });

    // 发起 WS 连接
    ws.connect();
  }

  // ===========================================================================
  // HTTP 轮询（降级方案）
  // ===========================================================================

  void _startPolling() {
    _stopPolling();
    _fetchState();
    _refreshTimer = Timer.periodic(_pollInterval, (_) => _fetchState());
  }

  void _stopPolling() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<void> _fetchState() async {
    if (_api == null || !mounted) return;
    if (DateTime.now().difference(_lastUserActionTime).inSeconds <
        _protectionSeconds) {
      return;
    }

    try {
      final newState = await _api.getState();
      if (!mounted) return;

      state = AsyncValue.data(newState);
      _failureCount = 0;

      _updateOnlineStatus(true, realName: newState.info.name);
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

  void _updateOnlineStatus(bool isOnline, {String? realName}) {
    if (_api == null) return;
    final ip = _api.baseUrl.replaceAll('http://', '').split(':').first;
    _ref
        .read(deviceListProvider.notifier)
        .updateOnlineStatus(
          ip.replaceAll('.', '_'),
          isOnline,
          realName: realName,
        );
  }

  // ===========================================================================
  // 公共 API
  // ===========================================================================

  Future<void> refresh() => _fetchState();

  /// 强制刷新，跳过保护窗口（用于删除分段等结构变更操作）
  Future<void> forceRefresh() {
    _lastUserActionTime = DateTime.fromMillisecondsSinceEpoch(0);
    return _fetchState();
  }

  /// 是否通过 WebSocket 连接
  bool get isWebSocketConnected => _wsConnected;

  Future<void> optimisticUpdate(
    WledState Function(WledState) updater,
    Future<WledState?> Function() apiCall,
  ) async {
    final current = state.valueOrNull;
    if (current == null) return;
    _lastUserActionTime = DateTime.now();
    final newState = updater(current);
    state = AsyncValue.data(newState);

    // 双向同步
    _syncToPeer(newState);

    try {
      await apiCall();
      _lastUserActionTime = DateTime.now();
    } catch (_) {}
  }

  /// 双向同步：detail ↔ family
  void _syncToPeer(WledState newState) {
    try {
      if (_isDetail) {
        // detail → family：找到当前聚焦设备的 family notifier
        final device = _ref.read(currentDeviceProvider);
        if (device == null) return;
        _ref
            .read(deviceFamilyStateProvider(device.id).notifier)
            .syncState(newState);
      } else {
        // family → detail：如果当前聚焦的正好是同一设备
        final currentId = _ref.read(currentDeviceIdProvider);
        if (currentId == _deviceId) {
          _ref.read(deviceStateProvider.notifier).syncState(newState);
        }
      }
    } catch (_) {
      // 对端 provider 可能已 dispose，静默忽略
    }
  }

  /// 外部同步状态（不触发 API 调用，不再反向同步）
  void syncState(WledState newState) {
    if (!mounted) return;
    _lastUserActionTime = DateTime.now();
    state = AsyncValue.data(newState);
  }

  @override
  void dispose() {
    _stopPolling();
    _wsStateSubscription?.cancel();
    _wsConnectionSubscription?.cancel();
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
    if (id != null && id != 0 && v is Map<String, dynamic>) {
      list.add(WledPreset.fromJson(id, v));
    }
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
