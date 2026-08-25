/// 串行发送异步值，并在发送期间只保留最后一次提交。
///
/// 适合色盘、连续滑杆等“本地反馈要即时、网络只需要最终值”的交互。
class LatestValueDispatcher<T> {
  final Future<void> Function(T value) _send;
  final void Function(Object error)? _onError;

  T? _pendingValue;
  bool _hasPendingValue = false;
  bool _acceptingValues = true;
  Future<void>? _draining;

  Object? lastError;

  LatestValueDispatcher(
    Future<void> Function(T value) send, {
    void Function(Object error)? onError,
  }) : _send = send,
       _onError = onError;

  void submit(T value) {
    if (!_acceptingValues) return;
    _pendingValue = value;
    _hasPendingValue = true;
    _draining ??= _drain();
  }

  Future<void> get idle => _draining ?? Future<void>.value();

  Future<void> _drain() async {
    try {
      while (_hasPendingValue) {
        final value = _pendingValue as T;
        _pendingValue = null;
        _hasPendingValue = false;
        try {
          await _send(value);
        } catch (error) {
          lastError = error;
          _onError?.call(error);
        }
      }
    } finally {
      _draining = null;
      if (_hasPendingValue) {
        _draining = _drain();
      }
    }
  }

  void dispose() {
    _acceptingValues = false;
  }
}
