// ignore_for_file: avoid_print
import 'package:cf_waiting_room/cf_waiting_room.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Fake WebView platform
// ─────────────────────────────────────────────────────────────────────────────

/// A fake [WebViewPlatform] that records the last created controller/delegate
/// and makes them available for test assertions.
class FakeWebViewPlatform extends WebViewPlatform {
  FakeWebViewController? latestController;
  FakeNavigationDelegate? latestDelegate;

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    latestController = FakeWebViewController(params);
    return latestController!;
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) {
    latestDelegate = FakeNavigationDelegate(params);
    return latestDelegate!;
  }

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) =>
      FakeWebViewWidget(params);

  @override
  PlatformWebViewCookieManager createPlatformCookieManager(
    PlatformWebViewCookieManagerCreationParams params,
  ) =>
      FakeCookieManager(params);
}

// ── Fake navigation delegate ─────────────────────────────────────────────────

class FakeNavigationDelegate extends PlatformNavigationDelegate {
  FakeNavigationDelegate(super.params) : super.implementation();

  PageEventCallback? onPageFinishedCallback;
  PageEventCallback? onPageStartedCallback;
  NavigationRequestCallback? onNavigationRequestCallback;
  WebResourceErrorCallback? onWebResourceErrorCallback;

  @override
  Future<void> setOnPageFinished(PageEventCallback handler) async =>
      onPageFinishedCallback = handler;

  @override
  Future<void> setOnPageStarted(PageEventCallback handler) async =>
      onPageStartedCallback = handler;

  @override
  Future<void> setOnNavigationRequest(
          NavigationRequestCallback handler) async =>
      onNavigationRequestCallback = handler;

  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback handler) async =>
      onWebResourceErrorCallback = handler;
}

// ── Fake controller ──────────────────────────────────────────────────────────

class FakeWebViewController extends PlatformWebViewController {
  FakeWebViewController(super.params) : super.implementation();

  String? _currentTitle;
  FakeNavigationDelegate? _navDelegate;

  /// Drive a page-load event from a test.
  Future<void> simulatePageLoad(
    String title, {
    String url = 'https://test/',
  }) async {
    _currentTitle = title;
    await Future<void>.microtask(
      () => _navDelegate?.onPageFinishedCallback?.call(url),
    );
  }

  @override
  Future<String?> getTitle() async => _currentTitle;

  @override
  Future<void> loadHtmlString(String html, {String? baseUrl}) async {
    final match = RegExp(r'<title>(.*?)</title>').firstMatch(html);
    _currentTitle = match?.group(1) ?? '';
    await Future<void>.microtask(
      () => _navDelegate?.onPageFinishedCallback?.call(baseUrl ?? ''),
    );
  }

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    // In tests: does not auto-fire; call simulatePageLoad() from the test.
    _currentTitle = '';
  }

  @override
  Future<void> reload() async {
    await Future<void>.microtask(
      () => _navDelegate?.onPageFinishedCallback?.call('https://reload/'),
    );
  }

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {
    _navDelegate = handler as FakeNavigationDelegate;
  }

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> addJavaScriptChannel(
      JavaScriptChannelParams javaScriptChannelParams) async {}

  @override
  Future<void> clearCache() async {}

  @override
  Future<void> clearLocalStorage() async {}

  @override
  Future<Object> runJavaScriptReturningResult(String javaScript) async => '';

  @override
  Future<void> runJavaScript(String javaScript) async {}
}

// ── Fake WebView widget (just a placeholder) ─────────────────────────────────

class FakeWebViewWidget extends PlatformWebViewWidget {
  FakeWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) =>
      const SizedBox.shrink(key: Key('fake_webview'));
}

// ── Fake cookie manager ──────────────────────────────────────────────────────

class FakeCookieManager extends PlatformWebViewCookieManager {
  FakeCookieManager(super.params) : super.implementation();

  @override
  Future<bool> clearCookies() async => true;

  @override
  Future<void> setCookie(WebViewCookie cookie) async {}
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Pumps a [CFWaitingRoomOverlayWidget] inside a [MaterialApp] + [Stack] and
/// returns the fake platform so tests can drive events.
Future<FakeWebViewPlatform> _pumpWidget(
  WidgetTester tester, {
  required WaitingRoomConfig config,
  required VoidCallback onQueueDone,
  VoidCallback? onSessionTimeout,
  VoidCallback? onNeedReQueue,
  MockConfig? mockConfig,
}) async {
  final platform = FakeWebViewPlatform();
  WebViewPlatform.instance = platform;

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            CFWaitingRoomOverlayWidget(
              config: config,
              onQueueDone: onQueueDone,
              onSessionTimeout: onSessionTimeout,
              onNeedReQueue: onNeedReQueue,
              mockConfig: mockConfig,
            ),
          ],
        ),
      ),
    ),
  );

  // Let initState complete (async _initWebView / _restorePersistedSession).
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));

  return platform;
}

// ─────────────────────────────────────────────────────────────────────────────
// Phase 1 tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    // Provide an empty shared_preferences store for each test.
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 1 — Flow 1: no queue', () {
    testWidgets(
      '1.1  passKeyWord match fires onQueueDone immediately',
      (tester) async {
        bool queueDone = false;

        final platform = await _pumpWidget(
          tester,
          config: WaitingRoomConfig(
            isEnable: true,
            queueUrl: 'https://test/',
            passKeyWord: ['myapp'],
          ),
          onQueueDone: () => queueDone = true,
        );

        // Simulate the page that passes the waiting room.
        await platform.latestController!.simulatePageLoad('MyApp Home');
        await tester.pump();

        expect(queueDone, isTrue, reason: 'onQueueDone should have fired');
      },
    );

    testWidgets(
      '1.2  passKeyWord wins even if title also contains a queue keyword',
      (tester) async {
        bool queueDone = false;

        final platform = await _pumpWidget(
          tester,
          config: WaitingRoomConfig(
            isEnable: true,
            queueUrl: 'https://test/',
            queueKeyWord: ['queue'],
            passKeyWord: ['paykool'],
          ),
          onQueueDone: () => queueDone = true,
        );

        // Title contains "queue" but also "paykool" → pass wins.
        await platform.latestController!
            .simulatePageLoad('paykool queue success');
        await tester.pump();

        expect(queueDone, isTrue,
            reason: 'passKeyWord should win over queueKeyWord');
      },
    );

    testWidgets(
      '1.3  CF meta page ("just a moment") is ignored — onQueueDone NOT fired',
      (tester) async {
        bool queueDone = false;

        final platform = await _pumpWidget(
          tester,
          config: WaitingRoomConfig(
            isEnable: true,
            queueUrl: 'https://test/',
            passKeyWord: ['myapp'],
          ),
          onQueueDone: () => queueDone = true,
        );

        // CF verification page — should stay in Phase 1, no callback.
        await platform.latestController!.simulatePageLoad('Just a moment...');
        await tester.pump();

        expect(queueDone, isFalse,
            reason: 'CF meta page must not trigger onQueueDone');
      },
    );

    testWidgets(
      '1.4  When passKeyWord is empty, any non-CF page triggers onQueueDone',
      (tester) async {
        bool queueDone = false;

        final platform = await _pumpWidget(
          tester,
          config: WaitingRoomConfig(
            isEnable: true,
            queueUrl: 'https://test/',
            passKeyWord: [], // empty → any non-CF title passes
          ),
          onQueueDone: () => queueDone = true,
        );

        await platform.latestController!.simulatePageLoad('Welcome to my app');
        await tester.pump();

        expect(queueDone, isTrue);
      },
    );
  });

  group('Phase 1 → Phase 2: queue detected', () {
    testWidgets(
      '2.1  Queue keyword → Phase 2 overlay is shown',
      (tester) async {
        final platform = await _pumpWidget(
          tester,
          config: WaitingRoomConfig(
            isEnable: true,
            queueUrl: 'https://test/',
            queueKeyWord: ['waiting'],
            passKeyWord: ['myapp'],
          ),
          onQueueDone: () {},
        );

        // Simulate a waiting-room page load.
        await platform.latestController!.simulatePageLoad('Waiting Room');
        await tester.pumpAndSettle();

        // The default overlay title widget should be visible.
        expect(find.byKey(const Key('cf_wr_overlay')), findsOneWidget);
      },
    );

    testWidgets(
      '2.2  Queue page followed by pass page → onQueueDone fires (Phase 2)',
      (tester) async {
        bool queueDone = false;

        final platform = await _pumpWidget(
          tester,
          config: WaitingRoomConfig(
            isEnable: true,
            queueUrl: 'https://test/',
            queueKeyWord: ['waiting'],
            passKeyWord: ['myapp'],
          ),
          onQueueDone: () => queueDone = true,
        );

        // Phase 1 → Phase 2 (queue detected).
        await platform.latestController!.simulatePageLoad('Waiting Room');
        await tester.pumpAndSettle();

        // Phase 2 → Phase 3 (pass page).
        await platform.latestController!.simulatePageLoad('myapp home');
        await tester.pump();

        expect(queueDone, isTrue);
      },
    );
  });

  group('Phase 1 — edge cases', () {
    testWidgets(
      '1.5  Empty title → stays in Phase 1, onQueueDone NOT fired',
      (tester) async {
        bool queueDone = false;

        final platform = await _pumpWidget(
          tester,
          config: WaitingRoomConfig(
            isEnable: true,
            queueUrl: 'https://test/',
            passKeyWord: ['myapp'],
          ),
          onQueueDone: () => queueDone = true,
        );

        // Empty title — the guard `title.isEmpty` must short-circuit.
        await platform.latestController!.simulatePageLoad('');
        await tester.pump();

        expect(queueDone, isFalse,
            reason: 'Empty title must not trigger onQueueDone');
        // Widget should still be in Phase 1 (full-screen WebView placeholder).
        expect(find.byKey(const Key('fake_webview')), findsOneWidget);
      },
    );

    testWidgets(
      '1.6  CF structural URL (cdn-cgi) → Phase 2 overlay, regardless of title',
      (tester) async {
        final platform = await _pumpWidget(
          tester,
          config: WaitingRoomConfig(
            isEnable: true,
            queueUrl: 'https://test/',
            queueKeyWord: ['waiting'],
            passKeyWord: ['myapp'],
          ),
          onQueueDone: () {},
        );

        // URL contains 'cdn-cgi' — widget treats it as waiting room even if
        // the title contains no queue keyword.
        await platform.latestController!.simulatePageLoad(
          'Some Page',
          url: 'https://test/cdn-cgi/challenge-platform/h/g',
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('cf_wr_overlay')), findsOneWidget,
            reason: 'cdn-cgi URL must trigger Phase 2 overlay');
      },
    );

    testWidgets(
      '1.7  Phase 1 main-frame error → onQueueDone fires (graceful fallback)',
      (tester) async {
        bool queueDone = false;

        final platform = await _pumpWidget(
          tester,
          config: WaitingRoomConfig(
            isEnable: true,
            queueUrl: 'https://test/',
            passKeyWord: ['myapp'],
          ),
          onQueueDone: () => queueDone = true,
        );

        // Fire a main-frame resource error while still in Phase 1.
        platform.latestDelegate!.onWebResourceErrorCallback?.call(
          const WebResourceError(
            errorCode: -2,
            description: 'net::ERR_INTERNET_DISCONNECTED',
            isForMainFrame: true,
          ),
        );
        await tester.pump();

        expect(queueDone, isTrue,
            reason:
                'Phase 1 main-frame error must call onQueueDone so the app is not stuck');
      },
    );

    testWidgets(
      '1.8  Phase 2 main-frame error → overlay stays, onQueueDone NOT fired',
      (tester) async {
        int queueDoneCalls = 0;

        final platform = await _pumpWidget(
          tester,
          config: WaitingRoomConfig(
            isEnable: true,
            queueUrl: 'https://test/',
            queueKeyWord: ['waiting'],
            passKeyWord: ['myapp'],
          ),
          onQueueDone: () => queueDoneCalls++,
        );

        // Enter Phase 2 (queue detected).
        await platform.latestController!.simulatePageLoad('Waiting Room');
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('cf_wr_overlay')), findsOneWidget);
        expect(queueDoneCalls, 0);

        // Fire a main-frame error while in Phase 2 (e.g. CF page blipped).
        platform.latestDelegate!.onWebResourceErrorCallback?.call(
          const WebResourceError(
            errorCode: -2,
            description: 'net::ERR_INTERNET_DISCONNECTED',
            isForMainFrame: true,
          ),
        );
        await tester.pump();

        expect(queueDoneCalls, 0,
            reason: 'Phase 2 error must NOT fire onQueueDone');
        expect(find.byKey(const Key('cf_wr_overlay')), findsOneWidget,
            reason: 'Overlay must remain during Phase 2 error');
      },
    );

    testWidgets(
      '1.9  Phase 3 main-frame error → onQueueDone NOT fired again, '
      'onNeedReQueue NOT called',
      (tester) async {
        int queueDoneCalls = 0;
        bool needReQueueCalled = false;

        final platform = await _pumpWidget(
          tester,
          config: WaitingRoomConfig(
            isEnable: true,
            queueUrl: 'https://test/',
            queueKeyWord: ['waiting'],
            passKeyWord: ['myapp'],
            sessionTimeoutMinutes: 5,
          ),
          onQueueDone: () => queueDoneCalls++,
          onNeedReQueue: () => needReQueueCalled = true,
        );

        // Phase 1 → Phase 2 (queue).
        await platform.latestController!.simulatePageLoad('Waiting Room');
        await tester.pumpAndSettle();

        // Phase 2 → Phase 3 (passed).
        await platform.latestController!.simulatePageLoad('myapp home');
        await tester.pump();
        expect(queueDoneCalls, 1);

        // Fire a main-frame error while in Phase 3 (e.g. network error after
        // cookie-clear reload).  This was the root bug — previously the error
        // handler called _handleQueueDone() unconditionally, restarting the
        // session timer as if the queue had been re-passed.
        platform.latestDelegate!.onWebResourceErrorCallback?.call(
          const WebResourceError(
            errorCode: -2,
            description: 'net::ERR_INTERNET_DISCONNECTED',
            isForMainFrame: true,
          ),
        );
        await tester.pump();

        expect(queueDoneCalls, 1,
            reason: 'Phase 3 error must NOT fire onQueueDone a second time');
        expect(needReQueueCalled, isFalse,
            reason: 'Phase 3 error must NOT fire onNeedReQueue');
      },
    );
  });

  group('Phase 1 — mock flow (Flow 2): mock queue → auto pass → onQueueDone',
      () {
    testWidgets(
      '3.1  Mock: after waitDuration the pass title fires onQueueDone',
      (tester) async {
        bool queueDone = false;

        final platform = await _pumpWidget(
          tester,
          config: WaitingRoomConfig(
            isEnable: true,
            queueUrl: 'https://test/', // non-empty so fallback loadRequest runs
            queueKeyWord: ['waiting', 'queue'],
            passKeyWord: ['myapp'],
          ),
          onQueueDone: () => queueDone = true,
          mockConfig: MockConfig(
            isEnable: true,
            waitDuration: const Duration(milliseconds: 200),
          ),
        );

        // The widget calls loadRequest (asset load fails in test env) so we
        // manually simulate the queue page being loaded.
        await platform.latestController!.simulatePageLoad('Waiting Room');
        await tester.pumpAndSettle();

        // Verify we're in Phase 2 (overlay visible).
        expect(find.byKey(const Key('cf_wr_overlay')), findsOneWidget,
            reason: 'Phase 2 overlay must be shown while in queue');
        expect(queueDone, isFalse);

        // Advance past waitDuration → widget calls loadHtmlString with pass title.
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();

        expect(queueDone, isTrue,
            reason: 'onQueueDone must fire after mock waitDuration');
      },
    );

    testWidgets(
      '3.2  Mock: Phase 1 with immediate pass (no queue detected) fires onQueueDone',
      (tester) async {
        bool queueDone = false;

        final platform = await _pumpWidget(
          tester,
          config: WaitingRoomConfig(
            isEnable: true,
            queueUrl: 'https://test/',
            queueKeyWord: ['waiting'],
            passKeyWord: ['myapp'],
          ),
          onQueueDone: () => queueDone = true,
          mockConfig: MockConfig(
            isEnable: true,
            waitDuration: const Duration(milliseconds: 200),
          ),
        );

        // Simulate a non-queue page load immediately (skip the queue entirely).
        await platform.latestController!.simulatePageLoad('myapp home');
        await tester.pump();

        expect(queueDone, isTrue,
            reason: 'Skipped queue → onQueueDone must fire immediately');
      },
    );
  });
}
