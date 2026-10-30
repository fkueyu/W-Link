import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flux/core/l10n.dart';
import 'package:flux/widgets/device_overview_bar.dart';

void main() {
  testWidgets('compact status capsule reports state and refreshes once', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final refresh = Completer<void>();
    var refreshCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: DeviceOverviewBar(
              totalDevices: 3,
              onlineDevices: 2,
              isWifiConnected: true,
              strings: ZhStrings(),
              onRefresh: () {
                refreshCount++;
                return refresh.future;
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('2 台在线'), findsOneWidget);
    expect(find.text('共 3 台'), findsOneWidget);
    expect(find.text('网络已连接'), findsNothing);
    expect(
      tester.getSemantics(find.byType(DeviceOverviewBar)).label,
      contains('网络已连接'),
    );

    await tester.tap(find.byType(DeviceOverviewBar));
    await tester.pump();
    await tester.tap(find.byType(DeviceOverviewBar));
    expect(refreshCount, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    refresh.complete();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('English status capsule fits beside the title at 340px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(340, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final strings = EnStrings();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    strings.myDevices,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                DeviceOverviewBar(
                  totalDevices: 12,
                  onlineDevices: 8,
                  isWifiConnected: true,
                  strings: strings,
                  onRefresh: () async {},
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('My Devices'), findsOneWidget);
    expect(find.text('8 online'), findsOneWidget);
    expect(find.text('12 total'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
