import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

/// WLED API 服务
/// 负责与 WLED 设备的 HTTP 通信
class WledApiService {
  final String baseUrl;
  final http.Client _client;
  final Duration timeout;

  WledApiService({
    required this.baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 5),
  }) : _client = client ?? http.Client();

  /// 获取完整状态 (state + info + effects + palettes)
  Future<WledFullResponse> getFullState() async {
    final response = await _get('/json');
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return WledFullResponse.fromJson(json);
  }

  /// 获取设备状态 (包含 info 注入)
  Future<WledState> getState() async {
    final response = await _get('/json');
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final state = WledState.fromJson(json['state'] as Map<String, dynamic>);
    final info = WledInfo.fromJson(json['info'] as Map<String, dynamic>);
    return state.copyWith(info: info);
  }

  /// 获取设备信息

  /// 2D 起始 X
  Future<WledInfo> getInfo() async {
    final response = await _get('/json/info');
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return WledInfo.fromJson(json);
  }

  /// 获取效果列表
  Future<List<String>> getEffects() async {
    final response = await _get('/json/eff');
    final decoded = jsonDecode(response.body);
    if (decoded is List) {
      return decoded.cast<String>();
    } else if (decoded is Map<String, dynamic> &&
        decoded.containsKey('effects')) {
      // Fallback for some versions returning object with effects key
      return (decoded['effects'] as List).cast<String>();
    } else if (decoded is Map) {
      // Should not happen for standard WLED /json/eff
      return [];
    }
    return [];
  }

  /// 获取效果元数据 (WLED 0.14+)
  Future<List<String>> getEffectMetadata() async {
    try {
      final response = await _get('/json/fxdata');
      if (response.statusCode != 200) return [];
      final list = jsonDecode(response.body) as List;
      return list.cast<String>();
    } catch (e) {
      // 旧版本 WLED 可能没有此 API
      return [];
    }
  }

  /// 获取调色板列表
  Future<List<String>> getPalettes() async {
    final response = await _get('/json/pal');
    final list = jsonDecode(response.body) as List;
    return list.cast<String>();
  }

  /// 发送状态更新
  /// [payload] 是部分状态对象，如 {"on": true, "bri": 255}
  Future<WledState?> setState(Map<String, dynamic> payload) async {
    final response = await _post('/json/state', payload);
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return WledState.fromJson(json);
    }
    return null;
  }

  /// 开关控制
  Future<WledState?> setOn(bool on) => setState({'on': on});

  /// 设置亮度
  Future<WledState?> setBrightness(int bri) =>
      setState({'bri': bri.clamp(0, 255)});

  /// 设置主分段颜色
  Future<WledState?> setColor(List<int> rgb, {int segmentId = 0}) {
    return setState({
      'seg': [
        {
          'id': segmentId,
          'col': [rgb],
        },
      ],
    });
  }

  /// 设置效果
  Future<WledState?> setEffect(int effectId, {int segmentId = 0}) {
    return setState({
      'seg': [
        {'id': segmentId, 'fx': effectId},
      ],
    });
  }

  /// 设置效果速度
  Future<WledState?> setEffectSpeed(int speed, {int segmentId = 0}) {
    return setState({
      'seg': [
        {'id': segmentId, 'sx': speed.clamp(0, 255)},
      ],
    });
  }

  /// 设置效果强度
  Future<WledState?> setEffectIntensity(int intensity, {int segmentId = 0}) {
    return setState({
      'seg': [
        {'id': segmentId, 'ix': intensity.clamp(0, 255)},
      ],
    });
  }

  /// 设置自定义效果参数 (c1, c2, c3)
  /// [index] 应该是 1, 2, 或 3
  Future<WledState?> setEffectCustom(
    int index,
    int value, {
    int segmentId = 0,
  }) {
    if (index < 1 || index > 3) throw ArgumentError('Index must be 1, 2, or 3');
    final key = 'c$index';
    return setState({
      'seg': [
        {'id': segmentId, key: value.clamp(0, 255)},
      ],
    });
  }

  /// 设置调色板
  Future<WledState?> setPalette(int paletteId, {int segmentId = 0}) {
    return setState({
      'seg': [
        {'id': segmentId, 'pal': paletteId},
      ],
    });
  }

  /// 获取预设列表
  /// 返回 Map，key 是预设 ID（字符串），value 是预设信息
  Future<Map<String, dynamic>> getPresets() async {
    final response = await _get('/presets.json');
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    // 过滤掉非预设项（如 "0" 通常是空的）
    json.removeWhere((key, value) => value == null || value is! Map);
    return json;
  }

  /// 保存到预设
  Future<void> savePreset(int presetId, {String? name}) async {
    final payload = {'psave': presetId, 'n': name};
    await _post('/json/state', payload);
  }

  /// 加载预设
  Future<WledState?> loadPreset(int presetId) => setState({'ps': presetId});

  /// 删除预设
  /// WLED 通过设置预设为空对象来删除
  Future<void> deletePreset(int presetId) async {
    await _post('/json/state', {'pdel': presetId});
  }

  // ============================================================================
  // 分段管理
  // ============================================================================

  /// 设置分段开关
  Future<WledState?> setSegmentOn(int segmentId, bool on) {
    return setState({
      'seg': [
        {'id': segmentId, 'on': on},
      ],
    });
  }

  /// 添加新分段
  Future<WledState?> addSegment(int start, int stop) {
    return setState({
      'seg': [
        {'start': start, 'stop': stop, 'on': true},
      ],
    });
  }

  /// 更新分段范围
  Future<WledState?> updateSegment(int segmentId, {int? start, int? stop}) {
    return setState({
      'seg': [
        {'id': segmentId, 'start': start, 'stop': stop},
      ],
    });
  }

  /// 删除分段
  /// WLED 通过将 stop 设为 0 来删除分段
  Future<WledState?> deleteSegment(int segmentId) {
    return setState({
      'seg': [
        {'id': segmentId, 'stop': 0},
      ],
    });
  }

  /// 批量设置分段属性
  Future<WledState?> setSegmentState(
    int segmentId, {
    bool? on,
    int? bri,
    int? start,
    int? stop,
    int? grp,
    int? spc,
    String? n,
    int? startY,
    int? stopY,
    bool? rev,
    bool? mi,
    bool? rY,
    bool? mY,
    bool? tp,
    int? offset,
    bool? frz,
    bool? o1,
    bool? o2,
    bool? o3,
    int? cct,
    int? si,
    int? m12,
  }) {
    final seg = <String, dynamic>{'id': segmentId};
    if (on != null) seg['on'] = on;
    if (bri != null) seg['bri'] = bri;
    if (start != null) seg['start'] = start;
    if (stop != null) seg['stop'] = stop;
    if (grp != null) seg['grp'] = grp;
    if (spc != null) seg['spc'] = spc;
    if (n != null) seg['n'] = n;
    if (startY != null) seg['startY'] = startY;
    if (stopY != null) seg['stopY'] = stopY;
    if (rev != null) seg['rev'] = rev;
    if (mi != null) seg['mi'] = mi;
    if (rY != null) seg['rY'] = rY;
    if (mY != null) seg['mY'] = mY;
    if (tp != null) seg['tp'] = tp;
    if (offset != null) seg['of'] = offset;
    if (frz != null) seg['frz'] = frz;
    if (o1 != null) seg['o1'] = o1;
    if (o2 != null) seg['o2'] = o2;
    if (o3 != null) seg['o3'] = o3;
    if (cct != null) seg['cct'] = cct;
    if (si != null) seg['si'] = si;
    if (m12 != null) seg['m12'] = m12;

    return setState({
      'seg': [seg],
    });
  }

  // ============================================================================
  // 高级设置 (Settings)
  // ============================================================================

  /// 设置定时关机 (Nightlight)
  Future<WledState?> setNightlight({
    bool? on,
    int? duration,
    int? targetBrightness,
    int? mode,
  }) {
    final nl = <String, dynamic>{};
    if (on != null) nl['on'] = on;
    if (duration != null) nl['dur'] = duration;
    if (targetBrightness != null) nl['tbri'] = targetBrightness;
    if (mode != null) nl['mode'] = mode;

    return setState({'nl': nl});
  }

  /// 设置同步 (UDP Sync)
  Future<WledState?> setSync({
    bool? send,
    bool? receive,
    int? sgrp,
    int? rgrp,
  }) {
    final udpn = <String, dynamic>{};
    if (send != null) udpn['send'] = send;
    if (receive != null) udpn['recv'] = receive;
    if (sgrp != null) udpn['sgrp'] = sgrp;
    if (rgrp != null) udpn['rgrp'] = rgrp;

    return setState({'udpn': udpn});
  }

  /// 设置 LED 映射 ID
  Future<WledState?> setLedMap(int mapId) => setState({'ledmap': mapId});

  /// 设置实时覆盖模式
  /// [mode] 0=off, 1=until live ends, 2=until reboot
  Future<WledState?> setLiveOverride(int mode) =>
      setState({'lor': mode.clamp(0, 2)});

  /// 设置过渡时间
  /// [duration] 单位为 100ms，例如 7 = 700ms
  Future<WledState?> setTransition(int duration) =>
      setState({'transition': duration.clamp(0, 255)});

  /// 加载播放列表
  Future<WledState?> loadPlaylist(int playlistId) =>
      setState({'pl': playlistId});

  /// 停止播放列表 (pl = -1)
  Future<WledState?> stopPlaylist() => setState({'pl': -1});

  /// 设置分段镜像
  Future<WledState?> setSegmentMirror(int segmentId, bool mirror) {
    return setState({
      'seg': [
        {'id': segmentId, 'mi': mirror},
      ],
    });
  }

  /// 设置分段反向
  Future<WledState?> setSegmentReverse(int segmentId, bool reverse) {
    return setState({
      'seg': [
        {'id': segmentId, 'rev': reverse},
      ],
    });
  }

  /// 设置分段亮度
  Future<WledState?> setSegmentBrightness(int segmentId, int brightness) {
    return setState({
      'seg': [
        {'id': segmentId, 'bri': brightness.clamp(0, 255)},
      ],
    });
  }

  /// 重启设备
  Future<void> reboot() async {
    await _post('/json/state', {'rb': true});
  }

  /// 检查设备是否在线
  Future<bool> ping() async {
    try {
      final response = await _get('/json/info');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<http.Response> _get(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    return _client.get(uri).timeout(timeout);
  }

  Future<http.Response> _post(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$path');
    return _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(timeout);
  }

  void dispose() {
    _client.close();
  }
}

/// 完整 JSON 响应
class WledFullResponse {
  final WledState state;
  final WledInfo info;
  final List<String> effects;
  final List<String> palettes;

  const WledFullResponse({
    required this.state,
    required this.info,
    required this.effects,
    required this.palettes,
  });

  factory WledFullResponse.fromJson(Map<String, dynamic> json) {
    return WledFullResponse(
      state: WledState.fromJson(json['state'] as Map<String, dynamic>),
      info: WledInfo.fromJson(json['info'] as Map<String, dynamic>),
      effects: (json['effects'] as List?)?.cast<String>() ?? [],
      palettes: (json['palettes'] as List?)?.cast<String>() ?? [],
    );
  }
}
