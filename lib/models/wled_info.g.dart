// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wled_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WledInfo _$WledInfoFromJson(Map<String, dynamic> json) => WledInfo(
  ver: json['ver'] as String,
  vid: (json['vid'] as num).toInt(),
  leds: WledLedInfo.fromJson(json['leds'] as Map<String, dynamic>),
  name: json['name'] as String,
  udpPort: (json['udpport'] as num?)?.toInt() ?? 21324,
  live: json['live'] as bool? ?? false,
  fxCount: (json['fxcount'] as num?)?.toInt() ?? 0,
  palCount: (json['palcount'] as num?)?.toInt() ?? 0,
  arch: json['arch'] as String? ?? '',
  freeHeap: (json['freeheap'] as num?)?.toInt() ?? 0,
  uptime: (json['uptime'] as num?)?.toInt() ?? 0,
  brand: json['brand'] as String? ?? 'WLED',
  product: json['product'] as String? ?? 'DIY light',
  mac: json['mac'] as String? ?? '',
  wifi: json['wifi'] == null
      ? null
      : WledWifiInfo.fromJson(json['wifi'] as Map<String, dynamic>),
);

Map<String, dynamic> _$WledInfoToJson(WledInfo instance) => <String, dynamic>{
  'ver': instance.ver,
  'vid': instance.vid,
  'leds': instance.leds,
  'name': instance.name,
  'udpport': instance.udpPort,
  'live': instance.live,
  'fxcount': instance.fxCount,
  'palcount': instance.palCount,
  'arch': instance.arch,
  'freeheap': instance.freeHeap,
  'uptime': instance.uptime,
  'brand': instance.brand,
  'product': instance.product,
  'mac': instance.mac,
  'wifi': instance.wifi,
};

WledLedInfo _$WledLedInfoFromJson(Map<String, dynamic> json) => WledLedInfo(
  count: (json['count'] as num?)?.toInt() ?? 0,
  rgbw: json['rgbw'] == null ? false : _boolFromJson(json['rgbw']),
  maxPower: (json['maxpwr'] as num?)?.toInt() ?? 0,
  pwr: (json['pwr'] as num?)?.toInt() ?? 0,
  maxSeg: (json['maxseg'] as num?)?.toInt() ?? 1,
  cct: json['cct'] == null ? false : _boolFromJson(json['cct']),
  matrix: json['matrix'] == null
      ? null
      : WledMatrixInfo.fromJson(json['matrix'] as Map<String, dynamic>),
  fps: (json['fps'] as num?)?.toInt() ?? 0,
  bootps: (json['bootps'] as num?)?.toInt() ?? 0,
  lc: (json['lc'] as num?)?.toInt() ?? 1,
  wv: (json['wv'] as num?)?.toInt() ?? 0,
  seglc:
      (json['seglc'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      [],
);

Map<String, dynamic> _$WledLedInfoToJson(WledLedInfo instance) =>
    <String, dynamic>{
      'count': instance.count,
      'rgbw': instance.rgbw,
      'maxpwr': instance.maxPower,
      'pwr': instance.pwr,
      'maxseg': instance.maxSeg,
      'cct': instance.cct,
      'matrix': instance.matrix,
      'fps': instance.fps,
      'bootps': instance.bootps,
      'lc': instance.lc,
      'wv': instance.wv,
      'seglc': instance.seglc,
    };

WledWifiInfo _$WledWifiInfoFromJson(Map<String, dynamic> json) => WledWifiInfo(
  ssid: json['ssid'] as String? ?? '',
  rssi: (json['rssi'] as num?)?.toInt() ?? 0,
  signal: (json['signal'] as num?)?.toInt() ?? 0,
  channel: (json['channel'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$WledWifiInfoToJson(WledWifiInfo instance) =>
    <String, dynamic>{
      'ssid': instance.ssid,
      'rssi': instance.rssi,
      'signal': instance.signal,
      'channel': instance.channel,
    };

WledMatrixInfo _$WledMatrixInfoFromJson(Map<String, dynamic> json) =>
    WledMatrixInfo(
      width: (json['w'] as num?)?.toInt() ?? 0,
      height: (json['h'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$WledMatrixInfoToJson(WledMatrixInfo instance) =>
    <String, dynamic>{'w': instance.width, 'h': instance.height};
