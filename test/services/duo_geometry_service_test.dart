import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flux/services/duo_geometry_service.dart';

class _TrackingBinding extends AutomatedTestWidgetsFlutterBinding {
  final observed = <WidgetsBindingObserver>{};
  @override
  void addObserver(WidgetsBindingObserver observer) {
    observed.add(observer);
    super.addObserver(observer);
  }

  @override
  bool removeObserver(WidgetsBindingObserver observer) {
    observed.remove(observer);
    return super.removeObserver(observer);
  }
}

void main() {
  final binding = _TrackingBinding();
  const channel = MethodChannel('test/duo_geometry_lifecycle');

  testWidgets('销毁服务时移除几何观察者，后续尺寸变化不再调用通道', (tester) async {
    var reads = 0;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (_) async {
      reads++;
      return {'supported': false};
    });
    final before = Set<WidgetsBindingObserver>.of(binding.observed);
    final service = DuoGeometryService(channel: channel);
    final subscription = service.watch().listen((_) {});
    await tester.pump();
    expect(binding.observed.length, before.length + 1);
    service.dispose();
    subscription.cancel();
    expect(binding.observed, before);
    final readCount = reads;
    binding.handleMetricsChanged();
    await tester.pump();
    expect(reads, readCount);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });
}
