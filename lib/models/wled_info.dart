import 'package:json_annotation/json_annotation.dart';

part 'wled_info.g.dart';

/// WLED 设备元信息
/// 对应 /json/info API 响应
@JsonSerializable()
class WledInfo {
  /// 固件版本
  final String ver;

  /// 版本 ID
  final int vid;

  /// LED 信息
  final WledLedInfo leds;

  /// 设备名称
  final String name;

  /// UDP 端口
  @JsonKey(name: 'udpport')
  final int udpPort;

  /// 是否正在接收实时数据
  final bool live;

  /// 效果数量
  @JsonKey(name: 'fxcount')
  final int fxCount;

  /// 调色板数量
  @JsonKey(name: 'palcount')
  final int palCount;

  /// 架构 (esp8266 / esp32)
  final String arch;

  /// 可用堆内存
  @JsonKey(name: 'freeheap')
  final int freeHeap;

  /// 运行时间 (秒)
  final int uptime;

  /// 品牌
  final String brand;

  /// 产品名
  final String product;

  /// MAC 地址
  final String mac;

  /// WiFi 信号强度
  @JsonKey(name: 'wifi')
  final WledWifiInfo? wifi;

  const WledInfo({
    required this.ver,
    required this.vid,
    required this.leds,
    required this.name,
    this.udpPort = 21324,
    this.live = false,
    this.fxCount = 0,
    this.palCount = 0,
    this.arch = '',
    this.freeHeap = 0,
    this.uptime = 0,
    this.brand = 'WLED',
    this.product = 'DIY light',
    this.mac = '',
    this.wifi,
  });

  factory WledInfo.fromJson(Map<String, dynamic> json) =>
      _$WledInfoFromJson(json);

  Map<String, dynamic> toJson() => _$WledInfoToJson(this);
}

/// LED 配置信息
@JsonSerializable()
class WledLedInfo {
  /// LED 数量
  final int count;

  /// 是否为 RGBW 灯带
  @JsonKey(fromJson: _boolFromJson)
  final bool rgbw;

  /// 最大功率 (mW)
  @JsonKey(name: 'maxpwr')
  final int maxPower;

  /// 当前功率 (mW)
  final int pwr;

  /// 最大分段数
  @JsonKey(name: 'maxseg')
  final int maxSeg;

  /// 是否支持 CCT
  @JsonKey(fromJson: _boolFromJson)
  final bool cct;

  /// 矩阵配置 (如果有)
  final WledMatrixInfo? matrix;

  /// 当前帧率
  @JsonKey(defaultValue: 0)
  final int fps;

  /// 启动预设 ID
  @JsonKey(defaultValue: 0)
  final int bootps;

  /// 并行输出数量
  @JsonKey(defaultValue: 1)
  final int lc;

  /// 白平衡版本
  @JsonKey(defaultValue: 0)
  final int wv;

  /// 各分段 LED 计数
  @JsonKey(defaultValue: [])
  final List<int> seglc;

  const WledLedInfo({
    this.count = 0,
    this.rgbw = false,
    this.maxPower = 0,
    this.pwr = 0,
    this.maxSeg = 1,
    this.cct = false,
    this.matrix,
    this.fps = 0,
    this.bootps = 0,
    this.lc = 1,
    this.wv = 0,
    this.seglc = const [],
  });

  factory WledLedInfo.fromJson(Map<String, dynamic> json) =>
      _$WledLedInfoFromJson(json);

  Map<String, dynamic> toJson() => _$WledLedInfoToJson(this);
}

/// Helper: WLED API 返回 bool 时可能是 int (0/1)
bool _boolFromJson(dynamic value) {
  if (value is bool) return value;
  if (value is int) return value != 0;
  return false;
}

/// WiFi 信息
@JsonSerializable()
class WledWifiInfo {
  /// SSID
  @JsonKey(name: 'ssid')
  final String ssid;

  /// 信号强度 (dBm)
  @JsonKey(name: 'rssi')
  final int rssi;

  /// 信号质量 0-100
  @JsonKey(name: 'signal')
  final int signal;

  /// 频道
  @JsonKey(name: 'channel')
  final int channel;

  const WledWifiInfo({
    this.ssid = '',
    this.rssi = 0,
    this.signal = 0,
    this.channel = 0,
  });

  factory WledWifiInfo.fromJson(Map<String, dynamic> json) =>
      _$WledWifiInfoFromJson(json);

  Map<String, dynamic> toJson() => _$WledWifiInfoToJson(this);
}

/// 矩阵配置信息
@JsonSerializable()
class WledMatrixInfo {
  /// 宽度
  @JsonKey(name: 'w')
  final int width;

  /// 高度
  @JsonKey(name: 'h')
  final int height;

  const WledMatrixInfo({this.width = 0, this.height = 0});

  factory WledMatrixInfo.fromJson(Map<String, dynamic> json) =>
      _$WledMatrixInfoFromJson(json);

  Map<String, dynamic> toJson() => _$WledMatrixInfoToJson(this);
}
