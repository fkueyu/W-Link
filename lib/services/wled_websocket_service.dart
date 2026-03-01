import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/models.dart';

/// WebSocket 连接状态
enum WsConnectionState { disconnected, connecting, connected, error }

/// WLED WebSocket 服务
/// 管理与 WLED 设备的 WebSocket 长连接，接收实时状态推送
class WledWebSocketService {
  final String host;
  final int port;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _pingTimer;

  int _reconnectAttempts = 0;
  static const _maxReconnectDelay = Duration(seconds: 30);
  static const _pingInterval = Duration(seconds: 25);

  bool _disposed = false;
  bool _manualDisconnect = false;

  final _stateController = StreamController<WledState>.broadcast();
  final _connectionStateController =
      StreamController<WsConnectionState>.broadcast();

  WsConnectionState _currentConnectionState = WsConnectionState.disconnected;

  /// 实时设备状态流
  Stream<WledState> get stateStream => _stateController.stream;

  /// 连接状态流
  Stream<WsConnectionState> get connectionStream =>
      _connectionStateController.stream;

  /// 当前连接状态
  WsConnectionState get connectionState => _currentConnectionState;

  /// 是否已连接
  bool get isConnected =>
      _currentConnectionState == WsConnectionState.connected;

  WledWebSocketService({required this.host, this.port = 80});

  /// 建立 WebSocket 连接
  Future<void> connect() async {
    if (_disposed) return;
    _manualDisconnect = false;

    _setConnectionState(WsConnectionState.connecting);

    try {
      final uri = Uri.parse('ws://$host:$port/ws');
      _channel = WebSocketChannel.connect(uri);

      // 等待连接就绪
      await _channel!.ready;

      if (_disposed) {
        _channel?.sink.close();
        return;
      }

      _setConnectionState(WsConnectionState.connected);
      _reconnectAttempts = 0;

      debugPrint('[WS] Connected to $host:$port');

      // 启动 ping 保活
      _startPing();

      // 监听消息
      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('[WS] Connection failed: $e');
      _setConnectionState(WsConnectionState.error);
      _scheduleReconnect();
    }
  }

  /// 通过 WebSocket 发送状态更新
  /// 等价于 HTTP POST /json/state
  void sendState(Map<String, dynamic> payload) {
    if (!isConnected || _channel == null) return;
    try {
      _channel!.sink.add(jsonEncode(payload));
    } catch (e) {
      debugPrint('[WS] Send failed: $e');
    }
  }

  /// 请求完整状态
  void requestFullState() {
    sendState({'v': true});
  }

  /// 断开连接
  void disconnect() {
    _manualDisconnect = true;
    _cleanup();
    _setConnectionState(WsConnectionState.disconnected);
  }

  void _onMessage(dynamic data) {
    if (_disposed || data is! String) return;

    try {
      final json = jsonDecode(data) as Map<String, dynamic>;

      // WLED WebSocket 推送格式 = /json/si (state + info)
      if (json.containsKey('state') && json.containsKey('info')) {
        final state = WledState.fromJson(json['state'] as Map<String, dynamic>);
        final info = WledInfo.fromJson(json['info'] as Map<String, dynamic>);
        _stateController.add(state.copyWith(info: info));
      } else if (json.containsKey('on')) {
        // 某些版本直接返回 state 对象
        _stateController.add(WledState.fromJson(json));
      }
    } catch (e) {
      debugPrint('[WS] Parse error: $e');
    }
  }

  void _onError(dynamic error) {
    debugPrint('[WS] Error: $error');
    _setConnectionState(WsConnectionState.error);
    _cleanup(keepState: true);
    _scheduleReconnect();
  }

  void _onDone() {
    debugPrint('[WS] Connection closed');
    _cleanup(keepState: true);
    if (!_manualDisconnect && !_disposed) {
      _setConnectionState(WsConnectionState.disconnected);
      _scheduleReconnect();
    }
  }

  /// 指数退避重连
  void _scheduleReconnect() {
    if (_disposed || _manualDisconnect) return;

    _reconnectTimer?.cancel();
    final delay = Duration(
      seconds: (1 << _reconnectAttempts).clamp(1, _maxReconnectDelay.inSeconds),
    );
    _reconnectAttempts++;

    debugPrint(
      '[WS] Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts)',
    );

    _reconnectTimer = Timer(delay, () {
      if (!_disposed && !_manualDisconnect) connect();
    });
  }

  /// Ping 保活，防止连接空闲被断开
  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(_pingInterval, (_) {
      if (isConnected) {
        // 发送一个轻量请求保持连接活跃
        sendState({'v': true});
      }
    });
  }

  void _setConnectionState(WsConnectionState newState) {
    if (_currentConnectionState == newState) return;
    _currentConnectionState = newState;
    if (!_connectionStateController.isClosed) {
      _connectionStateController.add(newState);
    }
  }

  void _cleanup({bool keepState = false}) {
    _pingTimer?.cancel();
    _pingTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _subscription?.cancel();
    _subscription = null;

    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;

    if (!keepState) {
      _setConnectionState(WsConnectionState.disconnected);
    }
  }

  void dispose() {
    _disposed = true;
    _cleanup();
    _stateController.close();
    _connectionStateController.close();
    debugPrint('[WS] Disposed for $host');
  }
}
