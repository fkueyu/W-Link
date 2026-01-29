// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wled_segment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WledSegment _$WledSegmentFromJson(Map<String, dynamic> json) => WledSegment(
  id: (json['id'] as num).toInt(),
  start: (json['start'] as num?)?.toInt() ?? 0,
  stop: (json['stop'] as num?)?.toInt() ?? 0,
  len: (json['len'] as num?)?.toInt() ?? 0,
  col:
      (json['col'] as List<dynamic>?)
          ?.map(
            (e) => (e as List<dynamic>).map((e) => (e as num).toInt()).toList(),
          )
          .toList() ??
      const [],
  fx: (json['fx'] as num?)?.toInt() ?? 0,
  sx: (json['sx'] as num?)?.toInt() ?? 128,
  ix: (json['ix'] as num?)?.toInt() ?? 128,
  pal: (json['pal'] as num?)?.toInt() ?? 0,
  c1: (json['c1'] as num?)?.toInt() ?? 128,
  c2: (json['c2'] as num?)?.toInt() ?? 128,
  c3: (json['c3'] as num?)?.toInt() ?? 128,
  on: json['on'] as bool? ?? true,
  sel: json['sel'] as bool? ?? true,
  rev: json['rev'] as bool? ?? false,
  mi: json['mi'] as bool? ?? false,
  bri: (json['bri'] as num?)?.toInt(),
  n: json['n'] as String? ?? '',
  grp: (json['grp'] as num?)?.toInt() ?? 1,
  spc: (json['spc'] as num?)?.toInt() ?? 0,
  startY: (json['startY'] as num?)?.toInt() ?? 0,
  stopY: (json['stopY'] as num?)?.toInt() ?? 0,
  rY: json['rY'] as bool? ?? false,
  mY: json['mY'] as bool? ?? false,
  tp: json['tp'] as bool? ?? false,
  offset: (json['of'] as num?)?.toInt() ?? 0,
  frz: json['frz'] as bool? ?? false,
  o1: json['o1'] as bool? ?? false,
  o2: json['o2'] as bool? ?? false,
  o3: json['o3'] as bool? ?? false,
  cct: (json['cct'] as num?)?.toInt() ?? 127,
  setId: (json['set'] as num?)?.toInt() ?? 0,
  si: (json['si'] as num?)?.toInt() ?? 0,
  m12: (json['m12'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$WledSegmentToJson(WledSegment instance) =>
    <String, dynamic>{
      'id': instance.id,
      'start': instance.start,
      'stop': instance.stop,
      'len': instance.len,
      'col': instance.col,
      'fx': instance.fx,
      'sx': instance.sx,
      'ix': instance.ix,
      'pal': instance.pal,
      'c1': instance.c1,
      'c2': instance.c2,
      'c3': instance.c3,
      'on': instance.on,
      'sel': instance.sel,
      'rev': instance.rev,
      'mi': instance.mi,
      'bri': instance.bri,
      'n': instance.n,
      'grp': instance.grp,
      'spc': instance.spc,
      'startY': instance.startY,
      'stopY': instance.stopY,
      'rY': instance.rY,
      'mY': instance.mY,
      'tp': instance.tp,
      'of': instance.offset,
      'frz': instance.frz,
      'o1': instance.o1,
      'o2': instance.o2,
      'o3': instance.o3,
      'cct': instance.cct,
      'set': instance.setId,
      'si': instance.si,
      'm12': instance.m12,
    };
