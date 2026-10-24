// 视觉验收用的临时入口（不参与发布构建）。
//
// 用途：Xcode 27 这套机器上没有 GUI 版 Simulator，无法用鼠标驱动；本入口跑真正的
// [FluxApp]，并从 App 沙盒 `Documents/shots_cmd.txt` 读取「点击/滑动」指令，用
// `GestureBinding.handlePointerEvent` 注入指针事件——与真人点击走同一条命中测试
// 与手势管线，因此截出来的每一屏都是真实交互结果，不是静态拼图。
//
// 主机侧：`xcrun simctl io booted screenshot` 取图；指令用 `echo "1 tap 200 400" >>
// <container>/Documents/shots_cmd.txt` 追加；`shots_ack.txt` 回报已执行到第几条。
//
// 运行：flutter run -t tool/shots/main.dart -d <sim-udid>
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flux/core/core.dart';
import 'package:flux/models/models.dart';
import 'package:flux/providers/providers.dart';
import 'package:flux/services/duo_geometry_service.dart';
import 'package:flux/main.dart';

/// 假设备指向主机上的 WLED mock（模拟器与主机共用网络栈，127.0.0.1 即主机）。
const String _mockHost = '127.0.0.1';
const int _mockPort = 8099;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  // 种子设备：只在该键为空时写入，避免覆盖手工添加的设备。
  final seeded = prefs.getString(AppConstants.keyDevices);
  if (seeded == null || seeded.isEmpty) {
    const device = WledDevice(
      id: 'mock-studio',
      name: 'WLED Studio',
      originalName: 'WLED Studio',
      ip: _mockHost,
      port: _mockPort,
      isOnline: true,
    );
    await prefs.setString(
      AppConstants.keyDevices,
      jsonEncode([device.toJson()]),
    );
  }

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const FluxApp(),
    ),
  );

  _ShotDriver().start();
}

/// 从沙盒 Documents 读指令文件并注入指针事件。
class _ShotDriver {
  static const String _cmdName = 'shots_cmd.txt';
  static const String _ackName = 'shots_ack.txt';

  int _lastSeq = 0;
  int _pointer = 1;
  bool _busy = false;

  Directory? _dir;

  Directory _documents() {
    if (_dir != null) return _dir!;
    // iOS 沙盒默认不建 Documents，必须自己建；建不出来才退回沙盒根。
    final home = Platform.environment['HOME'];
    if (home != null) {
      final docs = Directory('$home/Documents');
      if (!docs.existsSync()) {
        try {
          docs.createSync(recursive: true);
        } catch (_) {}
      }
      if (docs.existsSync()) return _dir = docs;
      final root = Directory(home);
      if (root.existsSync()) return _dir = root;
    }
    return _dir = Directory.systemTemp;
  }

  void start() {
    _writeAck('booted pid=$pid dir=${_documents().path}');
    Timer.periodic(const Duration(milliseconds: 400), (_) => _poll());
  }

  Future<void> _poll() async {
    if (_busy) return;
    _busy = true;
    try {
      final file = File('${_documents().path}/$_cmdName');
      if (!file.existsSync()) return;
      final lines = await file.readAsLines();
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        final parts = trimmed.split(RegExp(r'\s+'));
        final seq = int.tryParse(parts.first);
        if (seq == null || seq <= _lastSeq) continue;
        _lastSeq = seq;
        await _run(parts.skip(1).toList());
        _writeAck('seq=$seq cmd=${parts.skip(1).join(' ')}');
      }
    } catch (e) {
      _writeAck('error=$e');
    } finally {
      _busy = false;
    }
  }

  Future<void> _run(List<String> argv) async {
    if (argv.isEmpty) return;
    switch (argv.first) {
      case 'tap':
        final x = double.parse(argv[1]);
        final y = double.parse(argv[2]);
        await _tap(Offset(x, y));
        break;
      case 'longpress':
        final x = double.parse(argv[1]);
        final y = double.parse(argv[2]);
        final ms = argv.length > 3 ? int.parse(argv[3]) : 700;
        await _tap(Offset(x, y), hold: Duration(milliseconds: ms));
        break;
      case 'swipe':
        final from = Offset(double.parse(argv[1]), double.parse(argv[2]));
        final to = Offset(double.parse(argv[3]), double.parse(argv[4]));
        final ms = argv.length > 5 ? int.parse(argv[5]) : 300;
        await _swipe(from, to, Duration(milliseconds: ms));
        break;
      case 'sleep':
        await Future<void>.delayed(Duration(milliseconds: int.parse(argv[1])));
        break;
      case 'log':
        stdout.writeln('[shots] ${argv.skip(1).join(' ')}');
        break;
      case 'probe':
        await _dumpViewMetrics();
        break;
      default:
        stdout.writeln('[shots] unknown cmd ${argv.first}');
    }
  }

  Future<void> _tap(
    Offset at, {
    Duration hold = const Duration(milliseconds: 60),
  }) async {
    final id = _pointer++;
    final binding = GestureBinding.instance;
    final start = DateTime.now();
    binding.handlePointerEvent(
      PointerDownEvent(
        pointer: id,
        position: at,
        kind: PointerDeviceKind.touch,
        timeStamp: Duration.zero,
      ),
    );
    await Future<void>.delayed(hold);
    binding.handlePointerEvent(
      PointerUpEvent(
        pointer: id,
        position: at,
        kind: PointerDeviceKind.touch,
        timeStamp: DateTime.now().difference(start),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 120));
  }

  Future<void> _swipe(Offset from, Offset to, Duration duration) async {
    final id = _pointer++;
    final binding = GestureBinding.instance;
    const steps = 18;
    // 每步位移必须写进 `delta`：手势识别器靠 delta 累积位移、靠相邻事件的
    // 时间戳差算速度。少任一项，drag-to-dismiss 会因为「速度为 0」不触发
    // （表现为弹层纹丝不动）。
    final stepDelta = Offset(
      (to.dx - from.dx) / steps,
      (to.dy - from.dy) / steps,
    );
    final stepDelay = Duration(
      microseconds: (duration.inMicroseconds / steps).round(),
    );
    binding.handlePointerEvent(
      PointerDownEvent(
        pointer: id,
        position: from,
        kind: PointerDeviceKind.touch,
        timeStamp: Duration.zero,
      ),
    );
    var elapsed = Duration.zero;
    var position = from;
    for (var i = 1; i <= steps; i++) {
      await Future<void>.delayed(stepDelay);
      elapsed += stepDelay;
      position += stepDelta;
      binding.handlePointerEvent(
        PointerMoveEvent(
          pointer: id,
          position: position,
          delta: stepDelta,
          kind: PointerDeviceKind.touch,
          timeStamp: elapsed,
        ),
      );
    }
    binding.handlePointerEvent(
      PointerUpEvent(
        pointer: id,
        position: position,
        kind: PointerDeviceKind.touch,
        timeStamp: elapsed,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }

  /// 把引擎层视图指标落盘，用来回答「Flutter 到底能拿到 Duo 的哪些信息」。
  ///
  /// 全部取自 `PlatformDispatcher.views`（引擎直传，不经过任何我们自己的布局代码），
  /// 所以这里没有的，Flutter 侧就真的拿不到。
  ///
  /// 末尾追加原生桥（`flux/duo`）的快照——引擎拿不到、UIKit 拿得到的那部分。
  Future<void> _dumpViewMetrics() async {
    final buf = StringBuffer();
    final views = ui.PlatformDispatcher.instance.views.toList();
    buf.writeln('views=${views.length}');
    for (var i = 0; i < views.length; i++) {
      final v = views[i];
      final logical = v.physicalSize / v.devicePixelRatio;
      buf.writeln(
        'view[$i] logical=${logical.width}x${logical.height} '
        'physical=${v.physicalSize.width}x${v.physicalSize.height} '
        'dpr=${v.devicePixelRatio}',
      );
      buf.writeln('view[$i] padding=${v.padding}');
      buf.writeln('view[$i] viewPadding=${v.viewPadding}');
      buf.writeln('view[$i] viewInsets=${v.viewInsets}');
      buf.writeln('view[$i] systemGestureInsets=${v.systemGestureInsets}');
      final features = v.displayFeatures;
      buf.writeln('view[$i] displayFeatures=${features.length}');
      for (final f in features) {
        buf.writeln('view[$i]   type=${f.type} bounds=${f.bounds}');
      }
    }

    final duo = await DuoGeometryService().read();
    buf.writeln('duo supported=${duo.supported} attached=${duo.attached}');
    buf.writeln(
      'duo view=${duo.viewSize.width}x${duo.viewSize.height} '
      'scale=${duo.scale}',
    );
    buf.writeln('duo hinge=${duo.hinge}');
    buf.writeln(
      'duo verticalFoldX=${duo.verticalFoldX} '
      'horizontalFoldY=${duo.horizontalFoldY} '
      'needsSinglePane=${duo.needsSinglePane}',
    );
    buf.writeln(
      'duo divisions=${duo.divisionRegions.length} '
      '${duo.divisionRegions}',
    );
    buf.writeln(
      'duo occlusions=${duo.occlusionRegions.length} '
      '${duo.occlusionRegions}',
    );

    try {
      File('${_documents().path}/probe.txt').writeAsStringSync(buf.toString());
    } catch (e) {
      stdout.writeln('[probe] write failed: $e');
    }
    stdout.writeln('[probe] written');
  }

  void _writeAck(String message) {
    try {
      File('${_documents().path}/$_ackName').writeAsStringSync('$message\n');
    } catch (_) {}
  }
}
