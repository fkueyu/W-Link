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

/// 每台设备唯一的实时会话。
///
/// 列表卡片、详情页与能力页都观察同一个 family 实例，避免重复创建
/// HTTP client、WebSocket、轮询器和彼此同步的状态副本。
typedef DeviceConnection = ({String ip, int port, String baseUrl});

/// 只暴露会影响网络会话身份的稳定字段。
///
/// 在线状态、显示名称和 lastSeen 的变化不会重建 WebSocket；只有地址或端口
/// 真正变化时才会让对应的 session provider 重建。
final deviceConnectionProvider = Provider.family<DeviceConnection?, String>((
  ref,
  deviceId,
) {
  return ref.watch(
    deviceListProvider.select((devices) {
      final index = devices.indexWhere((device) => device.id == deviceId);
      if (index == -1) return null;
      final device = devices[index];
      return (ip: device.ip, port: device.port, baseUrl: device.baseUrl);
    }),
  );
});

final deviceSessionProvider = StateNotifierProvider.family
    .autoDispose<DeviceStateNotifier, AsyncValue<WledState>, String>((
      ref,
      deviceId,
    ) {
      final connection = ref.watch(deviceConnectionProvider(deviceId));
      if (connection == null) {
        return DeviceStateNotifier(null, ref, deviceId: deviceId);
      }

      final ws = WledWebSocketService(
        host: connection.ip,
        port: connection.port,
      );
      final api = WledApiService(baseUrl: connection.baseUrl);

      ref.onDispose(() {
        api.dispose();
        ws.dispose();
      });

      return DeviceStateNotifier(api, ref, webSocket: ws, deviceId: deviceId);
    });

/// 兼容旧卡片调用；它与 [deviceSessionProvider] 是同一个 provider family。
final deviceFamilyStateProvider = deviceSessionProvider;

/// 当前详情页只是选中设备会话的只读投影，不再拥有独立网络连接。
final deviceStateProvider = Provider<AsyncValue<WledState>>((ref) {
  final deviceId = ref.watch(currentDeviceIdProvider);
  if (deviceId == null) return const AsyncValue.loading();
  return ref.watch(deviceSessionProvider(deviceId));
});

/// 当前详情页向唯一设备会话提交命令的入口。
final currentDeviceSessionNotifierProvider = Provider<DeviceStateNotifier>((
  ref,
) {
  final deviceId = ref.watch(currentDeviceIdProvider);
  if (deviceId == null) {
    throw StateError('没有选中的 WLED 设备');
  }
  return ref.watch(deviceSessionProvider(deviceId).notifier);
});

/// 兼容现有能力页面；复用当前设备会话已经持有的 HTTP client。
final wledApiProvider = Provider<WledApiService?>((ref) {
  final deviceId = ref.watch(currentDeviceIdProvider);
  if (deviceId == null) return null;
  return ref.watch(deviceSessionProvider(deviceId).notifier).api;
});

/// 当前聚焦设备会话持有的 WebSocket 服务。
final wledWebSocketProvider = Provider<WledWebSocketService?>((ref) {
  final deviceId = ref.watch(currentDeviceIdProvider);
  if (deviceId == null) return null;
  return ref.watch(deviceSessionProvider(deviceId).notifier).webSocket;
});

/// 一次设备命令的显式结果。
///
/// UI 可以选择 await 后展示错误；暂未迁移的 fire-and-forget 调用也不会产生
/// 未处理的异步异常。
class DeviceCommandResult {
  final WledState? state;
  final Object? error;

  const DeviceCommandResult._({this.state, this.error});

  const DeviceCommandResult.success(WledState state) : this._(state: state);

  const DeviceCommandResult.failure(Object error) : this._(error: error);

  bool get isSuccess => error == null;

  bool get isFailure => !isSuccess;
}

class DeviceCommandFailure {
  final int sequence;
  final String? deviceId;
  final Object error;

  const DeviceCommandFailure({
    required this.sequence,
    required this.deviceId,
    required this.error,
  });
}

/// 应用壳监听的唯一设备命令失败出口。
final deviceCommandFailureProvider = StateProvider<DeviceCommandFailure?>(
  (ref) => null,
);

class DeviceStateNotifier extends StateNotifier<AsyncValue<WledState>> {
  final WledApiService? _api;
  final Ref _ref;
  final WledWebSocketService? _ws;
  final String? _deviceId;

  Timer? _refreshTimer;
  StreamSubscription? _wsStateSubscription;
  StreamSubscription? _wsConnectionSubscription;
  int _commandSequence = 0;
  int _pendingCommandCount = 0;
  Future<void> _commandQueue = Future<void>.value();
  WledState? _commandBaseline;
  WledState? _lastConfirmedCommandState;
  Object? _lastCommandError;
  Future<void>? _fetchFuture;

  static const _pollInterval = Duration(seconds: 5);
  static const _slowPollInterval = Duration(seconds: 15);
  int _failureCount = 0;
  bool _wsConnected = false;

  DeviceStateNotifier(
    this._api,
    this._ref, {
    WledWebSocketService? webSocket,
    String? deviceId,
    WledState? initialState,
  }) : _ws = webSocket,
       _deviceId = deviceId,
       super(
         initialState == null
             ? const AsyncValue.loading()
             : AsyncValue.data(initialState),
       ) {
    if (_api != null) {
      if (_ws != null) {
        _initWebSocket();
      } else {
        _startPolling();
      }
    }
  }

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
      if (_pendingCommandCount > 0) return;
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
        // WS 连接成功 → 切换到慢速轮询作为兜底
        // (某些环境如 Android 模拟器的 WS 接收不可靠)
        debugPrint('[DeviceState] WS connected, switching to slow polling');
        _startSlowPolling();
      } else if (!_wsConnected && wasConnected) {
        // WS 断连 → 恢复快速 HTTP 轮询
        debugPrint('[DeviceState] WS disconnected, resuming fast HTTP polling');
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

  void _startSlowPolling() {
    _stopPolling();
    _refreshTimer = Timer.periodic(_slowPollInterval, (_) => _fetchState());
  }

  void _stopPolling() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<void> _fetchState() {
    final api = _api;
    if (api == null || !mounted) return Future<void>.value();
    if (_pendingCommandCount > 0) return Future<void>.value();
    return _fetchFuture ??= _performFetch(api);
  }

  Future<void> _performFetch(WledApiService api) async {
    final fetchCommandSequence = _commandSequence;

    try {
      final newState = await api.getState();
      if (!mounted) return;
      if (fetchCommandSequence != _commandSequence ||
          _pendingCommandCount > 0) {
        return;
      }

      state = AsyncValue.data(newState);
      _failureCount = 0;

      _updateOnlineStatus(true, realName: newState.info.name);
    } catch (e, st) {
      if (!mounted) return;
      if (fetchCommandSequence != _commandSequence ||
          _pendingCommandCount > 0) {
        return;
      }
      if (++_failureCount > 2) {
        _updateOnlineStatus(false);
        if (e is TimeoutException || e.toString().contains('SocketException')) {
          state = AsyncValue.error('unreachable', st);
        } else {
          state = AsyncValue.error(e.toString(), st);
        }
      }
    } finally {
      _fetchFuture = null;
    }
  }

  void _updateOnlineStatus(bool isOnline, {String? realName}) {
    final deviceId = _deviceId;
    if (deviceId == null) return;
    _ref
        .read(deviceListProvider.notifier)
        .updateOnlineStatus(deviceId, isOnline, realName: realName);
  }

  // ===========================================================================
  // 公共 API
  // ===========================================================================

  Future<void> refresh() => _fetchState();

  /// 用户主动刷新；命令提交期间仍遵守顺序保护，避免旧 GET 覆盖新状态。
  Future<void> forceRefresh() => _fetchState();

  /// 是否通过 WebSocket 连接
  bool get isWebSocketConnected => _wsConnected;

  WledApiService? get api => _api;

  WledWebSocketService? get webSocket => _ws;

  /// 最近一次由当前命令产生的错误；下一次命令成功后清空。
  Object? get lastCommandError => _lastCommandError;

  void _publishCommandFailure(Object error) {
    final notifier = _ref.read(deviceCommandFailureProvider.notifier);
    final sequence = (notifier.state?.sequence ?? 0) + 1;
    notifier.state = DeviceCommandFailure(
      sequence: sequence,
      deviceId: _deviceId,
      error: error,
    );
  }

  Future<DeviceCommandResult> updateNightlight(WledNightlight next) {
    final api = _api;
    return optimisticUpdate(
      (current) => current.copyWith(nl: next),
      () async => api?.setNightlight(next),
    );
  }

  Future<DeviceCommandResult> optimisticUpdate(
    WledState Function(WledState) updater,
    Future<WledState?> Function() apiCall,
  ) {
    if (!mounted) {
      return Future.value(DeviceCommandResult.failure(StateError('设备会话已经结束')));
    }
    final current = state.valueOrNull;
    if (current == null) {
      final error = StateError('设备状态尚未就绪');
      _lastCommandError = error;
      _publishCommandFailure(error);
      return Future.value(DeviceCommandResult.failure(error));
    }
    final commandSequence = ++_commandSequence;
    if (_pendingCommandCount == 0) {
      _commandBaseline = current;
      _lastConfirmedCommandState = current;
    }
    _pendingCommandCount++;
    _lastCommandError = null;
    var newState = updater(current);

    // Automatically clear preset selection when visual state properties are modified
    if (newState.ps == current.ps && current.ps > 0) {
      if (newState.on != current.on ||
          newState.bri != current.bri ||
          newState.seg != current.seg) {
        newState = newState.copyWith(ps: -1);
      }
    }

    state = AsyncValue.data(newState);
    final result = Completer<DeviceCommandResult>();

    _commandQueue = _commandQueue.then((_) async {
      try {
        final authoritativeState = await apiCall();
        if (authoritativeState == null) {
          throw StateError('设备没有返回更新后的状态');
        }
        final confirmedState = authoritativeState.copyWith(info: current.info);
        _lastConfirmedCommandState = confirmedState;
        if (mounted && commandSequence == _commandSequence) {
          state = AsyncValue.data(confirmedState);
        }
        result.complete(DeviceCommandResult.success(authoritativeState));
      } catch (error) {
        if (mounted && commandSequence == _commandSequence) {
          state = AsyncValue.data(
            _lastConfirmedCommandState ?? _commandBaseline ?? current,
          );
          _lastCommandError = error;
          _publishCommandFailure(error);
        }
        debugPrint('[DeviceState] Optimistic update API call failed: $error');
        result.complete(DeviceCommandResult.failure(error));
      } finally {
        _pendingCommandCount--;
        if (_pendingCommandCount == 0) {
          _commandBaseline = null;
          _lastConfirmedCommandState = null;
        }
      }
    });

    return result.future;
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
