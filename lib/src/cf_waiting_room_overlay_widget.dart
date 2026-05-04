import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'queue_waiting_info.dart';
import 'waiting_room_config.dart';

/// A full-screen Flutter widget that gates your app behind a
/// [Cloudflare Waiting Room](https://developers.cloudflare.com/waiting-room/).
///
/// ## How it works
///
/// **Phase 1 — WebView full-screen:**
/// The CF queue page is shown immediately so the user sees real content
/// instead of a blank splash screen.
///
/// **Phase 2 — Native overlay:**
/// Once the waiting room is confirmed, an overlay replaces the full-screen
/// WebView. The WebView is kept alive at 1 × 1 px so CF's auto-refresh
/// JavaScript continues running and the session cookie stays valid.
///
/// [onQueueDone] is called when:
/// - The loaded page is **not** a waiting room (skip queue entirely).
/// - CF redirects away from the queue page (queue ended).
/// - Mock mode: the JS bridge fires a `'done'` message.
/// - A main-frame WebView resource error occurs.
///
/// ## Custom UI
///
/// Supply [waitingOverlayBuilder] to render your own Phase 2 overlay.
/// Supply [reQueuePageBuilder] to render your own [forceReQueue] page.
/// When either builder is `null`, a built-in brand-neutral default is used.
///
/// ## Usage
///
/// ```dart
/// Stack(
///   children: [
///     CFWaitingRoomOverlayWidget(
///       config: WaitingRoomConfig(
///         isEnable: true,
///         queueUrl: 'https://your-site.com/',
///       ),
///       onQueueDone: () => setState(() => _showApp = true),
///     ),
///   ],
/// )
/// ```
class CFWaitingRoomOverlayWidget extends StatefulWidget {
  const CFWaitingRoomOverlayWidget({
    super.key,
    required this.config,
    required this.onQueueDone,
    this.onSessionTimeout,
    this.waitingOverlayBuilder,
    this.reQueuePageBuilder,
    this.isMock = false,
  });

  /// Configuration for the waiting room behaviour and keyword detection.
  /// Typically sourced from Firebase Remote Config.
  final WaitingRoomConfig config;

  /// Called when the CF queue is no longer active.
  /// Transition your app to its normal post-queue state here.
  final VoidCallback onQueueDone;

  /// Called when [WaitingRoomConfig.sessionTimeoutMinutes] elapses after the
  /// waiting room is confirmed active.
  ///
  /// Use this to show a re-queue prompt or refresh the session.
  final VoidCallback? onSessionTimeout;

  /// Builder for the Phase 2 native overlay shown while the user waits.
  ///
  /// Receives the [QueueWaitingInfo] extracted from the live CF page
  /// (title, ETA, last-updated). Return `null` or omit to use the
  /// built-in brand-neutral overlay.
  ///
  /// ```dart
  /// waitingOverlayBuilder: (context, info) => MyWaitingScreen(info: info),
  /// ```
  final Widget Function(BuildContext context, QueueWaitingInfo info)?
      waitingOverlayBuilder;

  /// Builder for the full-screen page shown by [forceReQueue].
  ///
  /// Receives an [onConfirm] callback — call it when the user confirms
  /// re-queueing. The callback clears CF cookies then pops the page.
  ///
  /// ```dart
  /// reQueuePageBuilder: (context, onConfirm) => MyReQueuePage(onConfirm: onConfirm),
  /// ```
  final Widget Function(BuildContext context, VoidCallback onConfirm)?
      reQueuePageBuilder;

  /// When `true`, loads the bundled mock HTML asset instead of [WaitingRoomConfig.queueUrl].
  /// Useful for development and UI testing without a live CF endpoint.
  final bool isMock;

  // ── Static API ─────────────────────────────────────────────────────────────

  /// Shows a non-dismissible full-screen page that blocks the user until they
  /// confirm re-queueing.
  ///
  /// On confirm:
  /// 1. All CF cookies are cleared via [WebViewCookieManager].
  /// 2. The page is popped.
  /// 3. [onConfirm] is called — reset your app's queue/auth state here.
  ///
  /// Supply [pageBuilder] to render a fully custom page; otherwise the
  /// built-in page uses [WaitingRoomConfig.effectiveReQueueMessage] and
  /// [WaitingRoomConfig.effectiveReQueueBtnText].
  ///
  /// ```dart
  /// // After a successful purchase:
  /// await CFWaitingRoomOverlayWidget.forceReQueue(
  ///   context,
  ///   config: waitingRoomConfig,
  ///   onConfirm: () => _resetToQueuePhase(),
  /// );
  /// ```
  static Future<void> forceReQueue(
    BuildContext context, {
    required WaitingRoomConfig config,
    VoidCallback? onConfirm,
    Widget Function(BuildContext context, VoidCallback onConfirm)? pageBuilder,
  }) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      pageBuilder: (ctx, _, __) => PopScope(
        canPop: false,
        child: pageBuilder != null
            ? pageBuilder(ctx, () async {
                await WebViewCookieManager().clearCookies();
                if (ctx.mounted) Navigator.of(ctx).pop();
                onConfirm?.call();
              })
            : _DefaultReQueuePage(config: config, onConfirm: onConfirm),
      ),
    );
  }

  @override
  State<CFWaitingRoomOverlayWidget> createState() =>
      _CFWaitingRoomOverlayWidgetState();
}

class _CFWaitingRoomOverlayWidgetState
    extends State<CFWaitingRoomOverlayWidget> with WidgetsBindingObserver {
  late final WebViewController _controller;

  bool _showNativeOverlay = false;
  double _hourglassTurns = 0;
  Timer? _rotationTimer;
  Timer? _sessionTimer;

  QueueWaitingInfo _waitingInfo = const QueueWaitingInfo();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    debugPrint(
        '[CF_WR] ▶ initState  url=${widget.config.queueUrl}  isMock=${widget.isMock}');
    _initWebView();
    _rotationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _hourglassTurns += 0.25);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _showNativeOverlay) {
      debugPrint('[CF_WR] 🔄 App resumed (native overlay) → reloading WebView');
      _controller.reload();
    }
  }

  @override
  void dispose() {
    debugPrint('[CF_WR] ■ dispose');
    WidgetsBinding.instance.removeObserver(this);
    _rotationTimer?.cancel();
    _sessionTimer?.cancel();
    super.dispose();
  }

  // ── Keyword detection ────────────────────────────────────────────────────

  bool _isWaitingRoomPage(String pageUrl, String title) {
    final t = title.toLowerCase();
    // CF structural URL signals — always checked regardless of config
    if (pageUrl.contains('cdn-cgi') ||
        pageUrl.contains('waiting-room') ||
        pageUrl.contains('cf_wr')) {
      debugPrint('[CF_WR] _isWaitingRoomPage → true (CF structural URL)');
      return true;
    }
    final result = widget.config.effectiveQueueKeyWords
        .any((kw) => t.contains(kw.toLowerCase()));
    debugPrint('[CF_WR] _isWaitingRoomPage  title="$title"  → $result');
    return result;
  }

  bool _isAnyCFPage(String title) {
    final t = title.toLowerCase();
    const cfMeta = [
      'cloudflare',
      'just a moment',
      'attention required',
      'checking your browser',
      'please wait',
      'enable javascript',
    ];
    if (cfMeta.any((s) => t.contains(s))) return true;
    return widget.config.effectiveQueueKeyWords
        .any((kw) => t.contains(kw.toLowerCase()));
  }

  bool _isRealAppPage(String title) {
    if (_isAnyCFPage(title)) return false;
    final passKws = widget.config.effectivePassKeyWords;
    // If no passKeyWords configured, any non-CF page is treated as the real app
    if (passKws.isEmpty) return true;
    final t = title.toLowerCase();
    return passKws.any((kw) => t.contains(kw.toLowerCase()));
  }

  // ── Session timer ────────────────────────────────────────────────────────

  void _startSessionTimer() {
    final minutes = widget.config.sessionTimeoutMinutes;
    if (minutes == null || minutes <= 0) return;
    _sessionTimer?.cancel();
    debugPrint('[CF_WR] ⏱ Session timer started — ${minutes}min');
    _sessionTimer = Timer(Duration(minutes: minutes), () {
      debugPrint('[CF_WR] ⏱ Session timeout fired');
      if (mounted) widget.onSessionTimeout?.call();
    });
  }

  // ── WebView ──────────────────────────────────────────────────────────────

  Future<void> _initWebView() async {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'FlutterQueueBridge',
        onMessageReceived: (msg) {
          debugPrint('[CF_WR] 📩 JS bridge: "${msg.message}"');
          if (msg.message == 'done') widget.onQueueDone();
        },
      )
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (url) => debugPrint('[CF_WR] 🌐 onPageStarted  $url'),
        onNavigationRequest: (_) => NavigationDecision.navigate,
        onPageFinished: _onPageFinished,
        onWebResourceError: (error) {
          if (error.isForMainFrame == true) {
            debugPrint('[CF_WR] ❌ Main-frame error → onQueueDone()');
            widget.onQueueDone();
          }
        },
      ));

    if (widget.config.clearCookieOnStart != false) {
      debugPrint('[CF_WR] 🧹 Clearing cookies, cache and local storage');
      await WebViewCookieManager().clearCookies();
      await _controller.clearCache();
      await _controller.clearLocalStorage();
    } else {
      debugPrint('[CF_WR] 🔑 clearCookieOnStart=false — skipping clear');
    }

    final queueUrl = widget.config.queueUrl ?? '';
    if (widget.isMock) {
      try {
        final html = await rootBundle.loadString(
            'packages/cf_waiting_room/assets/mock_waiting_room.html');
        await _controller.loadHtmlString(html, baseUrl: queueUrl);
      } catch (_) {
        if (queueUrl.isNotEmpty) {
          _controller.loadRequest(Uri.parse(queueUrl));
        }
      }
    } else if (queueUrl.isNotEmpty) {
      _controller.loadRequest(Uri.parse(queueUrl));
    }
  }

  Future<void> _onPageFinished(String pageUrl) async {
    final title = await _controller.getTitle() ?? '';
    final isWaiting = _isWaitingRoomPage(pageUrl, title);
    debugPrint('[CF_WR] ✔ onPageFinished  url="$pageUrl"  title="$title"'
        '  isWaiting=$isWaiting  nativeOverlay=$_showNativeOverlay');

    if (!isWaiting && !_showNativeOverlay) {
      if (title.isEmpty || _isAnyCFPage(title)) return;
      debugPrint('[CF_WR] ✅ Not a queue page (Phase 1) → onQueueDone()');
      widget.onQueueDone();
      return;
    }

    if (!isWaiting) {
      if (title.isNotEmpty && _isRealAppPage(title)) {
        debugPrint('[CF_WR] ✅ Queue passed → onQueueDone()');
        widget.onQueueDone();
      }
      return;
    }

    // Waiting room confirmed — extract CF content
    final etaId = widget.config.effectiveEtaId;
    final lastUpdatedId = widget.config.effectiveLastUpdatedId;

    String? title_, eta_, lastUpdated_;
    try {
      final raw = await _controller.runJavaScriptReturningResult(
          "Array.from(document.querySelectorAll('h1'))"
          ".map(e=>e.innerText.trim()).filter(t=>t.length>0).join('\\n')");
      title_ = (raw as String)
          .replaceAll(RegExp(r'^"|"$'), '')
          .replaceAll(r'\n', '\n')
          .trim();
      if (title_.isEmpty) title_ = null;
    } catch (_) {}
    try {
      final raw = await _controller.runJavaScriptReturningResult(
          "document.getElementById('$etaId')?.innerText?.trim()??''");
      eta_ = (raw as String).replaceAll(RegExp(r'^"|"$'), '').trim();
      if (eta_.isEmpty) eta_ = null;
    } catch (_) {}
    try {
      final raw = await _controller.runJavaScriptReturningResult(
          "document.getElementById('$lastUpdatedId')?.innerText?.trim()??''");
      lastUpdated_ =
          (raw as String).replaceAll(RegExp(r'^"|"$'), '').trim();
      if (lastUpdated_.isEmpty) lastUpdated_ = null;
    } catch (_) {}

    if (mounted) {
      final firstTransition = !_showNativeOverlay;
      setState(() {
        _showNativeOverlay = true;
        _waitingInfo =
            QueueWaitingInfo(title: title_, eta: eta_, lastUpdated: lastUpdated_);
      });
      if (firstTransition) _startSessionTimer();
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_showNativeOverlay) {
      return Positioned.fill(
        child: WebViewWidget(controller: _controller),
      );
    }

    final overlay = widget.waitingOverlayBuilder != null
        ? widget.waitingOverlayBuilder!(context, _waitingInfo)
        : _DefaultWaitingOverlay(
            info: _waitingInfo,
            hourglassTurns: _hourglassTurns,
          );

    return Positioned.fill(
      child: Stack(
        children: [
          // 1×1px WebView kept alive. Opacity(0.01) prevents some Android
          // devices from suspending a fully-invisible WebView.
          Positioned(
            left: 0,
            top: 0,
            width: 1,
            height: 1,
            child: Opacity(
              opacity: 0.01,
              child: WebViewWidget(controller: _controller),
            ),
          ),
          Positioned.fill(child: overlay),
        ],
      ),
    );
  }
}

// ── Default built-in overlays ─────────────────────────────────────────────

const _kDefaultBg = Color(0xFF1A2C45);

/// Brand-neutral Phase 2 overlay shown when no [waitingOverlayBuilder] is set.
class _DefaultWaitingOverlay extends StatelessWidget {
  const _DefaultWaitingOverlay({
    required this.info,
    required this.hourglassTurns,
  });

  final QueueWaitingInfo info;
  final double hourglassTurns;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kDefaultBg,
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedRotation(
              turns: hourglassTurns,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
              child:
                  const Icon(Icons.hourglass_top, color: Colors.white, size: 56),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                info.title ?? 'You are in the queue.\nThank you for your patience.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
            ),
            if (info.eta != null) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  info.eta!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'This page will refresh automatically.\nPlease keep the app open.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
              ),
            ),
            if (info.lastUpdated != null) ...[
              const SizedBox(height: 20),
              Text(
                'Last updated: ${info.lastUpdated}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Built-in forceReQueue full-screen page.
class _DefaultReQueuePage extends StatefulWidget {
  const _DefaultReQueuePage({required this.config, this.onConfirm});

  final WaitingRoomConfig config;
  final VoidCallback? onConfirm;

  @override
  State<_DefaultReQueuePage> createState() => _DefaultReQueuePageState();
}

class _DefaultReQueuePageState extends State<_DefaultReQueuePage> {
  bool _processing = false;

  Future<void> _confirm() async {
    if (_processing) return;
    setState(() => _processing = true);
    await WebViewCookieManager().clearCookies();
    if (mounted) Navigator.of(context).pop();
    widget.onConfirm?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kDefaultBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline,
                  color: Colors.greenAccent, size: 72),
              const SizedBox(height: 32),
              Text(
                widget.config.effectiveReQueueMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _processing ? null : _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _kDefaultBg,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _processing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          widget.config.effectiveReQueueBtnText,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
