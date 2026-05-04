// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:cf_waiting_room_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_teststs', () {
    testWidgets('renders gate page without crashing', (tester) async {
      await tester.pumpWidget(const ExampleApp());
      // The gate page uses a black Scaffold while the WebView loads.
      expect(find.byType(Scaffold), findsWidgets);
    });
  });

  group('WaitingRoomConfig constructor', () {
    test('fields are stored correctly', () {
      final config = WaitingRoomConfig(
        isEnable: true,
        queueUrl: 'https://example.com/',
        locale: 'zh-TW',
        defaultWaitingTitle: '排隊中',
        waitingRefreshMessage: '自動刷新',
        lastUpdatedPrefix: '更新：',
      );
      expect(config.isEnabled, isTrue);
      expect(config.queueUrl, 'https://example.com/');
      expect(config.locale, 'zh-TW');
      expect(config.defaultWaitingTitle, '排隊中');
      expect(config.waitingRefreshMessage, '自動刷新');
      expect(config.lastUpdatedPrefix, '更新：');
    });
  });

  group('CFWaitingRoomOverlayWidget', () {
    testWidgets('accepts overlayIcon and loadingIcon widgets', (tester) async {
      final config = WaitingRoomConfig(isEnable: false);

      // Build a minimal Stack host — the widget always returns Positioned
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                CFWaitingRoomOverlayWidget(
                  config: config,
                  isMock: true,
                  onQueueDone: () {},
                  overlayIcon: const Icon(Icons.business, key: Key('logo')),
                  loadingIcon: const CircularProgressIndicator(
                    key: Key('spinner'),
                  ),
                  overlayBackgroundColor: Colors.black,
                  titleStyle: const TextStyle(color: Colors.white),
                  refreshMessageStyle: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      );

      // Widget tree built without errors.
      expect(find.byType(CFWaitingRoomOverlayWidget), findsOneWidget);
    });
  });
}
