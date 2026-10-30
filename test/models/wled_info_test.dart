import 'package:flutter_test/flutter_test.dart';
import 'package:flux/models/wled_info.dart';

void main() {
  for (final entry in <Object?, int>{
    false: 0,
    true: 1,
    0: 0,
    1: 1,
    null: 0,
  }.entries) {
    test('设备信息兼容白光能力字段 ${entry.key}', () {
      final leds = <String, dynamic>{'count': 120, 'wv': entry.key};
      final info = WledInfo.fromJson({
        'ver': '0.14.4',
        'vid': 2310160,
        'name': 'WLED Studio',
        'leds': leds,
        'mac': 'aabbcc112233',
      });

      expect(info.leds.wv, entry.value);
      expect(info.leds.count, 120);
      expect(info.mac, 'aabbcc112233');
      expect(leds['wv'], entry.key); // 不修改调用方响应。
    });
  }

  test('设备信息兼容未返回白光能力的固件', () {
    final info = WledLedInfo.fromJson({'count': 60});
    expect(info.wv, 0);
    expect(info.count, 60);
  });
}
