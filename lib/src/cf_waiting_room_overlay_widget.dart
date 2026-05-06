import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'queue_waiting_info.dart';
import 'waiting_room_config.dart';

const _kSessionStartKey = 'cf_wr_session_start_ms';

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
    this.onNeedReQueue,
    this.waitingOverlayBuilder,
    this.mockConfig,
    this.locale,
    this.overlayIcon,
    this.loadingIcon,
    this.overlayBackgroundColor,
    this.titleStyle,
    this.refreshMessageStyle,
  });

  /// Configuration for the waiting room behaviour and keyword detection.
  /// Typically sourced from Firebase Remote Config.
  final WaitingRoomConfig config;

  /// Called when the CF queue is no longer active.
  /// Transition your app to its normal post-queue state here.
  final VoidCallback onQueueDone;

  /// Called when [WaitingRoomConfig.sessionTimeoutMinutes] elapses after the
  /// queue is **passed** (Phase 3 monitoring). In mock mode this is handled
  /// internally by a dialog; in production the WebView is reloaded to detect
  /// whether the CF queue has become active again.
  ///
  /// Only fired when the "No — stay in app" option is chosen in the mock
  /// dialog, or as an extra signal alongside WebView reload in production.
  final VoidCallback? onSessionTimeout;

  /// Called when the widget detects the CF queue is active again after a
  /// session timeout (production: page reloaded and queue detected; mock:
  /// user chose "Yes — re-queue").
  ///
  /// Use this to reset your app's post-queue state back to the queue screen.
  final VoidCallback? onNeedReQueue;

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

  /// Supply a custom re-queue confirmation page via [forceReQueue]'s
  /// `pageBuilder` parameter instead:
  ///
  /// ```dart
  /// await CFWaitingRoomOverlayWidget.forceReQueue(
  ///   context,
  ///   config: config,
  ///   onConfirm: () => resetState(),
  ///   pageBuilder: (ctx, onConfirm) => MyReQueuePage(onConfirm: onConfirm),
  /// );
  /// ```

  /// Mock mode configuration. When non-null, the widget loads the bundled
  /// mock HTML instead of [WaitingRoomConfig.queueUrl], enabling full
  /// queue-flow testing without a live CF endpoint.
  ///
  /// - [MockConfig.isEnable] activates the automatic pass timer.
  /// - [MockConfig.waitDuration] controls how long until queue is simulated as passed.
  /// - Session timeout in mock shows a dialog to choose re-queue or pass through.
  ///
  /// ```dart
  /// mockConfig: MockConfig(
  ///   isEnable: true,
  ///   waitDuration: Duration(seconds: 10),
  /// )
  /// ```
  final MockConfig? mockConfig;

  /// BCP-47 locale to use as the `Accept-Language` request header when
  /// loading the queue URL (e.g. `Locale('zh', 'TW')` → `"zh-TW"`).
  ///
  /// Resolution order:
  /// 1. This [locale] parameter (widget-level override).
  /// 2. [WaitingRoomConfig.locale] (Remote Config string, e.g. `"zh-TW"`).
  /// 3. The device system locale (`PlatformDispatcher.instance.locale`).
  final Locale? locale;

  // ── Default overlay visual customisation ───────────────────────────────

  /// Widget shown as a brand logo at the very top of the default Phase 2
  /// overlay (above the spinner). Any widget is accepted — e.g.
  /// `Image.asset('assets/logo.png')`, `SvgPicture.asset(...)`, etc.
  ///
  /// When `null` no logo is shown.
  final Widget? overlayIcon;

  /// Widget that replaces the animated hourglass **spinner** in the default
  /// Phase 2 overlay. Any widget is accepted — e.g.
  /// `Image.asset('assets/loading.gif')`, a `Lottie` animation, etc.
  ///
  /// When `null` the built-in `AnimatedRotation` hourglass is used.
  final Widget? loadingIcon;

  /// Background colour of the default Phase 2 overlay.
  ///
  /// Defaults to `Color(0xFF1A2C45)`.
  final Color? overlayBackgroundColor;

  /// [TextStyle] for the title / in-queue heading in the default overlay.
  ///
  /// When `null` the built-in style (white, 20 px, bold) is used.
  final TextStyle? titleStyle;

  /// [TextStyle] for the "refresh automatically" body line in the default overlay.
  ///
  /// When `null` the built-in style (white70, 13 px) is used.
  final TextStyle? refreshMessageStyle;

  // ── Static API ─────────────────────────────────────────────────────────────

  /// Shows a non-dismissible full-screen page that blocks the user until they
  /// confirm re-queueing.
  ///
  /// On confirm:
  /// 1. `Cf-Waiting-Room-Command: revoke` is sent to CF via the WebView so
  ///    the `__cfwaitingroom_<waitingroomname>` session cookie is included,
  ///    freeing the slot.  (A background dart:io request would arrive
  ///    cookie-less and be ignored.)
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
                // forceReQueue has no WebView reference — the widget's
                // _revokeAndReload handles revoke+reload when onNeedReQueue
                // transitions back to Phase 1.  Here we simply pop and call
                // onConfirm; the host app is responsible for re-mounting the
                // widget (which will trigger a fresh WebView load).
                if (ctx.mounted) Navigator.of(ctx).pop();
                onConfirm?.call();
              })
            : _DefaultReQueuePage(config: config, onConfirm: onConfirm),
      ),
    );
  }

  /// Sends `Cf-Waiting-Room-Command: revoke` through the WebView so that the
  /// request carries the `__cfwaitingroom_<waitingroomname>` session cookie
  /// that CF needs to identify which slot to release.  The cookie name suffix
  /// matches the waiting room name set in the Cloudflare dashboard and differs
  /// per site.
  ///
  /// `dart:io` / `HttpClient` does **not** share the WebView cookie store, so
  /// a background HTTP request would arrive at CF without the cookie and the
  /// revoke would be silently ignored.  By routing through [controller] the
  /// browser cookie jar is used automatically — equivalent to:
  ///
  /// ```sh
  /// curl https://your-site.com/ \
  ///   -H 'Cf-Waiting-Room-Command: revoke' \
  ///   -b '__cfwaitingroom_<waitingroomname>=<token>'
  /// ```
  ///
  /// The [onDone] callback is called once [controller.onPageFinished] fires
  /// for the revoke response so the caller can chain a fresh reload.
  ///
  /// Ref: https://blog.cloudflare.com/banish-bots-from-your-waiting-room
  static void _sendCfRevokeViaWebView(
    WebViewController controller,
    WaitingRoomConfig config,
    String acceptLanguage,
  ) {
    final queueUrl = config.queueUrl;
    if (queueUrl == null || queueUrl.isEmpty) return;
    debugPrint(
        '[CF_WR] 🔓 Sending Cf-Waiting-Room-Command: revoke via WebView (cookie attached)');
    controller.loadRequest(
      Uri.parse(queueUrl),
      headers: {
        'Cf-Waiting-Room-Command': 'revoke',
        'Accept-Language': acceptLanguage,
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
      },
    );
  }

  @override
  State<CFWaitingRoomOverlayWidget> createState() =>
      CFWaitingRoomOverlayWidgetState();
}

// Make state class public so callers can hold a GlobalKey and invoke
// checkQueueStatus() when autoReQueue=false.
class CFWaitingRoomOverlayWidgetState extends State<CFWaitingRoomOverlayWidget>
    with WidgetsBindingObserver {
  late final WebViewController _controller;

  /// Phase 1 — WebView full-screen (queue detection).
  /// Phase 2 — Native overlay + 1×1 WebView (user waiting).
  /// Phase 3 — Invisible 1×1 WebView (session monitoring after queue passed).
  _WPhase _phase = _WPhase.loading;

  double _hourglassTurns = 0;
  Timer? _rotationTimer;
  Timer? _sessionTimer;
  Timer? _mockPassTimer;
  DateTime? _sessionStartTime;

  /// True while a `Cf-Waiting-Room-Command: revoke` request is in-flight
  /// through the WebView.  [_onPageFinished] must skip phase logic during
  /// this window so the revoke response is not mistakenly interpreted as a
  /// queue or pass page.
  bool _isRevoking = false;

  QueueWaitingInfo _waitingInfo = const QueueWaitingInfo();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    debugPrint(
      '[CF_WR] ▶ initState  url=${widget.config.queueUrl}  isMock=${widget.mockConfig?.isEnable == true}',
    );
    _initWebView();
    _restorePersistedSession();
    _rotationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _hourglassTurns += 0.25);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('[CF_WR] 📱 lifecycle → $state  (phase=$_phase)');
    if (state == AppLifecycleState.resumed &&
        (_phase == _WPhase.waiting || _phase == _WPhase.monitoring)) {
      debugPrint('[CF_WR] 🔄 App resumed → reloading WebView');
      _controller.reload();
      _rearmSessionTimer();
    }
  }

  @override
  void dispose() {
    debugPrint('[CF_WR] ■ dispose');
    WidgetsBinding.instance.removeObserver(this);
    _rotationTimer?.cancel();
    _sessionTimer?.cancel();
    _mockPassTimer?.cancel();
    super.dispose();
  }
  // ── Keyword detection ────────────────────────────────────────────────────

  /// Returns true if [title] matches any configured passKeyWord.
  /// passKeyWords always take explicit priority over queue/CF detection.
  bool _isPassKeyWordMatch(String title) {
    final passKws = widget.config.effectivePassKeyWords;
    if (passKws.isEmpty) return false;
    final t = title.toLowerCase();
    return passKws.any((kw) => t.contains(kw.toLowerCase()));
  }

  bool _isWaitingRoomPage(String pageUrl, String title) {
    // passKeyWords win — a matching pass title is never a waiting room
    if (_isPassKeyWordMatch(title)) {
      debugPrint('[CF_WR] _isWaitingRoomPage → false (passKeyWord match)');
      return false;
    }
    final t = title.toLowerCase();
    if (pageUrl.contains('cdn-cgi') ||
        pageUrl.contains('waiting-room') ||
        pageUrl.contains('cf_wr')) {
      debugPrint('[CF_WR] _isWaitingRoomPage → true (CF structural URL)');
      return true;
    }
    final result = widget.config.effectiveQueueKeyWords.any(
      (kw) => t.contains(kw.toLowerCase()),
    );
    debugPrint('[CF_WR] _isWaitingRoomPage  title="$title"  → $result');
    return result;
  }

  bool _isAnyCFPage(String title) {
    if (_isPassKeyWordMatch(title)) return false;
    final t = title.toLowerCase();
    const cfMeta = [
      'cloudflare',
      'just a moment',
      'attention required',
      'checking your browser',
      'please wait',
      'enable javascript',
    ];
    final matched = cfMeta.where((s) => t.contains(s)).toList();
    if (matched.isNotEmpty) {
      debugPrint('[CF_WR] _isAnyCFPage → true (matched CF meta: $matched)');
      return true;
    }
    final kwMatch = widget.config.effectiveQueueKeyWords
        .where((kw) => t.contains(kw.toLowerCase()))
        .toList();
    if (kwMatch.isNotEmpty) {
      debugPrint(
          '[CF_WR] _isAnyCFPage → true (matched queueKeyWord: $kwMatch)');
      return true;
    }
    return false;
  }

  bool _isRealAppPage(String title) {
    if (_isPassKeyWordMatch(title)) {
      debugPrint('[CF_WR] _isRealAppPage → true (passKeyWord match)');
      return true;
    }
    if (_isAnyCFPage(title)) {
      debugPrint('[CF_WR] _isRealAppPage → false (CF page)');
      return false;
    }
    final result = widget.config.effectivePassKeyWords.isEmpty;
    debugPrint('[CF_WR] _isRealAppPage → $result (passKeyWord empty=$result)');
    return result;
  }

  // ── Internal queue-done handler ──────────────────────────────────────────

  /// Called when the queue is passed. Transitions to monitoring phase,
  /// notifies the host, and starts the session timer.
  void _handleQueueDone() {
    if (!mounted) return;
    debugPrint('[CF_WR] ✅ Queue passed → monitoring phase + onQueueDone()');
    _mockPassTimer?.cancel();
    setState(() {
      _phase = _WPhase.monitoring;
      _waitingInfo = const QueueWaitingInfo();
    });
    _startSessionTimer();
    widget.onQueueDone();
  }

  // ── Session timer ────────────────────────────────────────────────────────

  /// Reads a previously persisted session start time from [SharedPreferences]
  /// and restores [_sessionStartTime] so that [_rearmSessionTimer] fires
  /// correctly even if the app was killed and restarted mid-session.
  Future<void> _restorePersistedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMs = prefs.getInt(_kSessionStartKey);
      if (savedMs != null && _sessionStartTime == null) {
        final saved = DateTime.fromMillisecondsSinceEpoch(savedMs);
        final timeout = widget.config.effectiveSessionTimeout;
        if (timeout != null) {
          final elapsed = DateTime.now().difference(saved);
          if (elapsed < timeout) {
            // Session is still valid — restore start time so re-arm works
            _sessionStartTime = saved;
            debugPrint(
              '[CF_WR] ⏱ Restored session start from prefs '
              '(${elapsed.inSeconds}s elapsed, '
              '${(timeout - elapsed).inSeconds}s remaining)',
            );
          } else {
            // Session already expired — clear stored key
            debugPrint('[CF_WR] ⏱ Persisted session expired — clearing prefs');
            await prefs.remove(_kSessionStartKey);
          }
        }
      }
    } catch (e) {
      debugPrint('[CF_WR] ⚠ Could not restore persisted session: $e');
    }
  }

  void _startSessionTimer() {
    final timeout = widget.config.effectiveSessionTimeout;
    if (timeout == null || timeout <= Duration.zero) return;
    _sessionTimer?.cancel();

    // If a persisted start time was restored (from a previous run), honour it
    // so the timer fires at the correct wall-clock time after an app restart.
    _sessionStartTime ??= DateTime.now();

    // Persist the start time for cross-kill survival.
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt(
        _kSessionStartKey,
        _sessionStartTime!.millisecondsSinceEpoch,
      );
    }).catchError((_) {});

    final elapsed = DateTime.now().difference(_sessionStartTime!);
    final remaining = elapsed >= timeout ? Duration.zero : timeout - elapsed;
    debugPrint(
      '[CF_WR] ⏱ Session timer started — '
      '${timeout.inSeconds}s total, ${remaining.inSeconds}s remaining',
    );
    _sessionTimer = Timer(remaining, _onSessionTimerFired);
  }

  void _rearmSessionTimer() {
    final timeout = widget.config.effectiveSessionTimeout;
    final start = _sessionStartTime;
    if (timeout == null || timeout <= Duration.zero || start == null) return;
    final elapsed = DateTime.now().difference(start);
    final remaining = timeout - elapsed;
    if (remaining <= Duration.zero) {
      debugPrint('[CF_WR] ⏱ Session timed out while backgrounded → firing now');
      _onSessionTimerFired();
    } else {
      _sessionTimer?.cancel();
      debugPrint(
          '[CF_WR] ⏱ Session timer re-armed — ${remaining.inSeconds}s remaining');
      _sessionTimer = Timer(remaining, _onSessionTimerFired);
    }
  }

  void _onSessionTimerFired() {
    debugPrint('[CF_WR] ⏱ Session timeout fired (phase=$_phase)');
    if (!mounted) return;
    if (widget.mockConfig?.isEnable == true) {
      _showMockSessionTimeoutDialog();
    } else if (widget.config.autoReQueue != false) {
      // Default (autoReQueue=true/null): revoke/clear + reload + auto phase-check.
      _revokeAndReload();
      widget.onSessionTimeout?.call();
    } else {
      // autoReQueue=false: only revoke/clear the cookie, then signal the host.
      // The host is responsible for calling checkQueueStatus() when ready.
      debugPrint(
          '[CF_WR] ⏱ autoReQueue=false — revoking/clearing only; host must call checkQueueStatus()');
      _revokeOrClear();
      widget.onSessionTimeout?.call();
    }
  }

  /// Prints all JS-visible cookies from the WebView with a [label] prefix.
  ///
  /// ⚠️ `document.cookie` only returns **non-HttpOnly** cookies.
  /// CF's waiting room session cookie follows the pattern
  /// `__cfwaitingroom_<waitingroomname>` and is **HttpOnly** — it will NOT
  /// appear here.  Use this log to check other visible cookies (e.g.
  /// `cf_clearance`) and to confirm the cookie jar changes after a revoke.
  Future<void> _logCookies(String label, String url) async {
    if (url.isEmpty) return;
    try {
      final raw = await _controller.runJavaScriptReturningResult(
        'document.cookie',
      );
      final cookies = (raw as String).replaceAll(RegExp(r'^"|"$'), '').trim();
      if (cookies.isEmpty) {
        debugPrint('[CF_WR] 🍪 $label — no JS-visible cookies');
      } else {
        debugPrint('[CF_WR] 🍪 $label — $cookies');
      }
    } catch (e) {
      debugPrint('[CF_WR] ⚠ _logCookies($label) failed: $e');
    }
  }

  /// Two-step CF session revocation for **Enterprise** plans, or local cookie
  /// clear for lower-tier plans.
  ///
  /// **Enterprise** (`isEnterprise == true`):
  ///   Step 1 — Send `Cf-Waiting-Room-Command: revoke` through the WebView so
  ///   the `__cfwaitingroom_<waitingroomname>` cookie is carried automatically,
  ///   freeing the CF slot server-side.
  ///   Step 2 — Fresh reload so CF issues a new evaluation response.
  ///
  /// **Non-Enterprise** (`isEnterprise != true`):
  ///   CF ignores the revoke header on lower-tier plans.  Instead, clear the
  ///   WebView cookie jar + cache + localStorage locally so the next request
  ///   arrives without a session cookie and CF re-evaluates.
  ///
  /// Ref: https://blog.cloudflare.com/banish-bots-from-your-waiting-room
  Future<void> _revokeAndReload() async {
    if (!mounted) return;
    final queueUrl = widget.config.queueUrl ?? '';
    final acceptLanguage = _resolveLocale().toLanguageTag();
    final isEnterprise = widget.config.isEnterprise == true;

    if (isEnterprise) {
      // ── Enterprise: server-side revoke via header ──────────────────────
      await _logCookies('BEFORE revoke (enterprise)', queueUrl);
      debugPrint(
          '[CF_WR] ⏱ Enterprise — Step 1: Cf-Waiting-Room-Command: revoke');
      _isRevoking = true;
      CFWaitingRoomOverlayWidget._sendCfRevokeViaWebView(
          _controller, widget.config, acceptLanguage);
      await Future<void>.delayed(const Duration(milliseconds: 800));
      _isRevoking = false;
      await _logCookies('AFTER revoke (before reload)', queueUrl);
      debugPrint(
          '[CF_WR] ⏱ Enterprise — Step 2: fresh reload for new CF evaluation');
    } else {
      // ── Non-Enterprise: clear local cookie jar + cache ─────────────────
      debugPrint(
          '[CF_WR] 🧹 Non-enterprise: clearing cookie jar + cache (revoke header not supported)');
      await _logCookies('BEFORE clear (non-enterprise)', queueUrl);
      await WebViewCookieManager().clearCookies();
      await _controller.clearCache();
      await _controller.clearLocalStorage();
      await _logCookies('AFTER clear (non-enterprise)', queueUrl);
      debugPrint('[CF_WR] ⏱ Non-enterprise: reloading for fresh CF evaluation');
    }

    if (!mounted) return;
    if (queueUrl.isNotEmpty) {
      _controller.loadRequest(
        Uri.parse(queueUrl),
        headers: {
          'Accept-Language': acceptLanguage,
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
        },
      );
    } else {
      _controller.reload();
    }
  }

  /// Revokes (Enterprise) or clears (non-Enterprise) the CF session cookie
  /// **without** reloading the page.
  ///
  /// Used internally when [CFWaitingRoomOverlayWidget.autoReQueue] is `false`
  /// so the host can perform its own async work before triggering a queue check
  /// via [checkQueueStatus].
  Future<void> _revokeOrClear() async {
    if (!mounted) return;
    final queueUrl = widget.config.queueUrl ?? '';
    final acceptLanguage = _resolveLocale().toLanguageTag();
    final isEnterprise = widget.config.isEnterprise == true;

    if (isEnterprise) {
      await _logCookies('BEFORE revoke (enterprise, no-reload)', queueUrl);
      debugPrint('[CF_WR] 🔓 Enterprise revokeOrClear — sending revoke header');
      _isRevoking = true;
      CFWaitingRoomOverlayWidget._sendCfRevokeViaWebView(
          _controller, widget.config, acceptLanguage);
      await Future<void>.delayed(const Duration(milliseconds: 800));
      _isRevoking = false;
      await _logCookies('AFTER revoke (no reload)', queueUrl);
    } else {
      debugPrint(
          '[CF_WR] 🧹 Non-enterprise revokeOrClear — clearing cookie jar + cache');
      await _logCookies('BEFORE clear (non-enterprise, no-reload)', queueUrl);
      await WebViewCookieManager().clearCookies();
      await _controller.clearCache();
      await _controller.clearLocalStorage();
      await _logCookies('AFTER clear (no reload)', queueUrl);
    }
  }

  /// Triggers a fresh reload of [WaitingRoomConfig.queueUrl] and runs the
  /// normal queue-detection logic in `_onPageFinished`.
  ///
  /// Call this from outside (via `GlobalKey<CFWaitingRoomOverlayWidgetState>`)
  /// when [CFWaitingRoomOverlayWidget.autoReQueue] is `false` and your app is
  /// ready to let the widget re-check whether the CF queue is active.
  ///
  /// ```dart
  /// final _wrKey = GlobalKey<CFWaitingRoomOverlayWidgetState>();
  ///
  /// // After your async work is done:
  /// _wrKey.currentState?.checkQueueStatus();
  /// ```
  Future<void> checkQueueStatus() async {
    if (!mounted) return;
    debugPrint('[CF_WR] 🔍 checkQueueStatus() — reloading for queue detection');
    final queueUrl = widget.config.queueUrl ?? '';
    final acceptLanguage = _resolveLocale().toLanguageTag();
    if (queueUrl.isNotEmpty) {
      await _controller.loadRequest(
        Uri.parse(queueUrl),
        headers: {
          'Accept-Language': acceptLanguage,
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
        },
      );
    } else {
      await _controller.reload();
    }
  }

  /// Mock-only: asks the user whether to re-queue or stay in the app.
  void _showMockSessionTimeoutDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('[Mock] Session timeout'),
        content: Text(
          'Session timeout reached (${widget.config.effectiveSessionTimeout?.inSeconds}s).\n\n'
          'Simulate: is the waiting room still active?\n'
          '(This dialog only appears in mock mode.)',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _sessionTimer?.cancel();
              _sessionStartTime = null;
              SharedPreferences.getInstance()
                  .then((p) => p.remove(_kSessionStartKey))
                  .catchError((_) => false);
              widget.onSessionTimeout?.call();
            },
            child: const Text('No — queue cleared'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.onNeedReQueue?.call();
              _resetMock();
            },
            child: const Text('Yes — still in queue'),
          ),
        ],
      ),
    );
  }

  // ── Mock helpers ─────────────────────────────────────────────────────────

  /// Resets to Phase 1 and reloads the mock queue HTML.
  Future<void> _resetMock() async {
    debugPrint('[CF_WR] 🎭 Mock reset → Phase 1');
    _sessionTimer?.cancel();
    _sessionStartTime = null;
    _mockPassTimer?.cancel();
    // Clear persisted session so it doesn't affect the fresh run.
    SharedPreferences.getInstance()
        .then((p) => p.remove(_kSessionStartKey))
        .catchError((_) => false);
    if (!mounted) return;
    setState(() {
      _phase = _WPhase.loading;
      _waitingInfo = const QueueWaitingInfo();
    });
    await _loadMockHtml();
  }

  Future<void> _loadMockHtml() async {
    final queueUrl = widget.config.queueUrl ?? '';
    final acceptLanguage = _resolveLocale().toLanguageTag();
    try {
      final html = await rootBundle.loadString(
        'packages/cf_waiting_room/assets/mock_waiting_room.html',
      );
      debugPrint(
          '[CF_WR] 🎭 Mock HTML loaded from asset bundle (${html.length} chars)');
      await _controller.loadHtmlString(html, baseUrl: queueUrl);
    } catch (e) {
      debugPrint(
          '[CF_WR] 🎭 Mock asset load failed ($e) — falling back to loadRequest: $queueUrl');
      if (queueUrl.isNotEmpty) {
        _controller.loadRequest(
          Uri.parse(queueUrl),
          headers: {'Accept-Language': acceptLanguage},
        );
      }
    }
    _startMockPassTimer();
  }

  void _startMockPassTimer() {
    final mc = widget.mockConfig;
    if (mc == null || !mc.isEnable) return;
    _mockPassTimer?.cancel();
    debugPrint('[CF_WR] 🎭 Mock pass timer — ${mc.waitDuration.inSeconds}s');
    _mockPassTimer = Timer(mc.waitDuration, _simulateMockPass);
  }

  void _simulateMockPass() {
    final passKws = widget.config.effectivePassKeyWords;
    final passTitle = passKws.isNotEmpty ? passKws.first : 'app';
    debugPrint('[CF_WR] 🎭 Mock: simulating pass with title="$passTitle"');
    _controller.loadHtmlString(
      '<html lang=""><head><title>$passTitle</title></head>'
      '<body><h1>Mock — Queue Passed</h1></body></html>',
    );
  }

  // ── Locale resolution ────────────────────────────────────────────────────

  Locale _resolveLocale() {
    if (widget.locale != null) return widget.locale!;
    final cfgLocale = widget.config.locale;
    if (cfgLocale != null && cfgLocale.isNotEmpty) {
      final parts = cfgLocale.split(RegExp(r'[-_]'));
      if (parts.length >= 2) return Locale(parts[0], parts[1]);
      return Locale(parts[0]);
    }
    return PlatformDispatcher.instance.locale;
  }

  // ── WebView ──────────────────────────────────────────────────────────────

  Future<void> _initWebView() async {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'FlutterQueueBridge',
        onMessageReceived: (msg) {
          debugPrint('[CF_WR] 📩 JS bridge: "${msg.message}"');
          if (msg.message == 'done') _handleQueueDone();
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) => debugPrint('[CF_WR] 🌐 onPageStarted  $url'),
          onNavigationRequest: (_) => NavigationDecision.navigate,
          onPageFinished: _onPageFinished,
          onWebResourceError: (error) {
            if (error.isForMainFrame == true) {
              debugPrint('[CF_WR] ❌ Main-frame error → onQueueDone()');
              _handleQueueDone();
            }
          },
        ),
      );

    if (widget.config.clearCookieOnStart != false) {
      final acceptLanguage = _resolveLocale().toLanguageTag();
      if (widget.config.isEnterprise == true) {
        // Enterprise: revoke server-side slot then clear local cache.
        debugPrint(
            '[CF_WR] 🧹 Enterprise clearCookieOnStart: sending revoke + clearing cache/storage');
        _isRevoking = true;
        CFWaitingRoomOverlayWidget._sendCfRevokeViaWebView(
            _controller, widget.config, acceptLanguage);
        await Future<void>.delayed(const Duration(milliseconds: 800));
        _isRevoking = false;
        await _controller.clearCache();
        await _controller.clearLocalStorage();
      } else {
        // Non-enterprise: clear cookie jar + cache locally.
        debugPrint(
            '[CF_WR] 🧹 Non-enterprise clearCookieOnStart: clearing cookie jar + cache/storage');
        await WebViewCookieManager().clearCookies();
        await _controller.clearCache();
        await _controller.clearLocalStorage();
      }
    } else {
      debugPrint('[CF_WR] 🔑 clearCookieOnStart=false — skipping clear');
    }

    final queueUrl = widget.config.queueUrl ?? '';
    final acceptLanguage = _resolveLocale().toLanguageTag();
    debugPrint('[CF_WR] 🌐 Accept-Language: $acceptLanguage');
    if (widget.mockConfig?.isEnable == true) {
      await _loadMockHtml();
    } else if (queueUrl.isNotEmpty) {
      _controller.loadRequest(
        Uri.parse(queueUrl),
        headers: {'Accept-Language': acceptLanguage},
      );
    }
  }

  Future<void> _onPageFinished(String pageUrl) async {
    // Skip processing during the revoke request — the revoke response must
    // not be treated as a queue or pass page.
    if (_isRevoking) {
      debugPrint('[CF_WR] ⏭ _onPageFinished skipped (revoke in-flight)');
      return;
    }
    final title = await _controller.getTitle() ?? '';
    final isWaiting = _isWaitingRoomPage(pageUrl, title);
    debugPrint(
      '[CF_WR] ✔ onPageFinished  url="$pageUrl"  title="$title"'
      '  isWaiting=$isWaiting  phase=$_phase',
    );

    switch (_phase) {
      case _WPhase.loading:
        if (!isWaiting) {
          if (title.isEmpty) {
            debugPrint('[CF_WR] ⏭ Phase 1: empty title — staying in Phase 1');
            return;
          }
          if (_isAnyCFPage(title)) {
            debugPrint(
                '[CF_WR] ⏭ Phase 1: CF/bot-check page — staying in Phase 1');
            return;
          }
          debugPrint('[CF_WR] ✅ Not a queue page (Phase 1) → done');
          _handleQueueDone();
          return;
        }
        _transitionToWaiting(title);

      case _WPhase.waiting:
        if (!isWaiting) {
          if (title.isNotEmpty && _isRealAppPage(title)) {
            debugPrint('[CF_WR] ✅ Queue passed (Phase 2) → done');
            _handleQueueDone();
          } else {
            debugPrint(
              '[CF_WR] ⏭ Phase 2: page not recognised as real app page '
              '(title="$title") — staying in overlay',
            );
          }
          return;
        }
        debugPrint(
            '[CF_WR] 🔄 Phase 2: still in queue — refreshing overlay info');
        _transitionToWaiting(title);

      case _WPhase.monitoring:
        // Log cookies on every Phase 3 page-finish so we can see what CF
        // returned after the revoke + fresh reload cycle.
        _logCookies('Phase 3 onPageFinished', pageUrl);
        if (isWaiting) {
          // Queue came back! Return to Phase 2 and notify host
          debugPrint('[CF_WR] ⚠ Queue detected in monitoring → re-queue');
          _sessionTimer?.cancel();
          _sessionStartTime = null;
          // Clear persisted session — user must re-queue from scratch.
          SharedPreferences.getInstance()
              .then((p) => p.remove(_kSessionStartKey))
              .catchError((_) => false);
          _transitionToWaiting(title);
          widget.onNeedReQueue?.call();
        } else {
          debugPrint(
              '[CF_WR] ✓ Phase 3: reload confirmed no queue — restarting session timer');
          // Reset start time so the next cycle runs for the full duration,
          // then re-arm.  This keeps the periodic queue-check running
          // indefinitely until a queue is detected or the widget is disposed.
          _sessionStartTime = null;
          _startSessionTimer();
        }
    }
  }

  Future<void> _transitionToWaiting(String pageTitle) async {
    final etaId = widget.config.effectiveEtaId;
    final lastUpdatedId = widget.config.effectiveLastUpdatedId;
    String? title_, eta_, lastUpdated_;
    try {
      final raw = await _controller.runJavaScriptReturningResult(
        "Array.from(document.querySelectorAll('h1'))"
        ".map(e=>e.innerText.trim()).filter(t=>t.length>0).join('\\n')",
      );
      title_ = (raw as String)
          .replaceAll(RegExp(r'^"|"$'), '')
          .replaceAll(r'\n', '\n')
          .trim();
      if (title_.isEmpty) title_ = null;
    } catch (e) {
      debugPrint('[CF_WR] ⚠ JS h1 extraction failed: $e');
    }
    try {
      final raw = await _controller.runJavaScriptReturningResult(
        "document.getElementById('$etaId')?.innerText?.trim()??''",
      );
      eta_ = (raw as String).replaceAll(RegExp(r'^"|"$'), '').trim();
      if (eta_.isEmpty) eta_ = null;
    } catch (e) {
      debugPrint('[CF_WR] ⚠ JS eta (#$etaId) extraction failed: $e');
    }
    try {
      final raw = await _controller.runJavaScriptReturningResult(
        "document.getElementById('$lastUpdatedId')?.innerText?.trim()??''",
      );
      lastUpdated_ = (raw as String).replaceAll(RegExp(r'^"|"$'), '').trim();
      if (lastUpdated_.isEmpty) lastUpdated_ = null;
    } catch (e) {
      debugPrint(
          '[CF_WR] ⚠ JS lastUpdated (#$lastUpdatedId) extraction failed: $e');
    }
    debugPrint(
      '[CF_WR] 🖼 Phase 2 info — h1="$title_"  eta="$eta_"  lastUpdated="$lastUpdated_"',
    );
    if (mounted) {
      setState(() {
        _phase = _WPhase.waiting;
        _waitingInfo = QueueWaitingInfo(
          title: title_,
          eta: eta_,
          lastUpdated: lastUpdated_,
        );
      });
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Phase 3: invisible keeper — just keep the WebView alive
    if (_phase == _WPhase.monitoring) {
      return Positioned(
        left: 0,
        top: 0,
        width: 1,
        height: 1,
        child: Opacity(
          opacity: 0.01,
          child: WebViewWidget(controller: _controller),
        ),
      );
    }

    // Phase 1: full-screen WebView
    if (_phase == _WPhase.loading) {
      return Positioned.fill(child: WebViewWidget(controller: _controller));
    }

    // Phase 2: native overlay
    final overlay = widget.waitingOverlayBuilder != null
        ? widget.waitingOverlayBuilder!(context, _waitingInfo)
        : _DefaultWaitingOverlay(
            info: _waitingInfo,
            hourglassTurns: _hourglassTurns,
            defaultWaitingTitle: widget.config.waitingTitle,
            waitingRefreshMessage: widget.config.waitingRefreshMessage,
            lastUpdatedPrefix: widget.config.lastUpdatedPrefix,
            overlayIcon: widget.overlayIcon,
            loadingIcon: widget.loadingIcon,
            overlayBackgroundColor: widget.overlayBackgroundColor,
            titleStyle: widget.titleStyle,
            refreshMessageStyle: widget.refreshMessageStyle,
          );

    return Positioned.fill(
      key: const Key('cf_wr_overlay'),
      child: Stack(
        children: [
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

// ── Phase enum ────────────────────────────────────────────────────────────

enum _WPhase {
  loading, // Phase 1 — full-screen WebView
  waiting, // Phase 2 — native overlay + 1×1 WebView
  monitoring, // Phase 3 — invisible 1×1 WebView (post-pass session monitoring)
}

// ── Default built-in overlays ─────────────────────────────────────────────

const _kDefaultBg = Color(0xFF1A2C45);

/// Brand-neutral Phase 2 overlay shown when no [waitingOverlayBuilder] is set.
class _DefaultWaitingOverlay extends StatelessWidget {
  const _DefaultWaitingOverlay({
    required this.info,
    required this.hourglassTurns,
    this.defaultWaitingTitle,
    this.waitingRefreshMessage,
    this.lastUpdatedPrefix,
    this.overlayIcon,
    this.loadingIcon,
    this.overlayBackgroundColor,
    this.titleStyle,
    this.refreshMessageStyle,
  });

  final QueueWaitingInfo info;
  final double hourglassTurns;
  final String? defaultWaitingTitle;
  final String? waitingRefreshMessage;
  final String? lastUpdatedPrefix;
  final Widget? overlayIcon;
  final Widget? loadingIcon;
  final Color? overlayBackgroundColor;
  final TextStyle? titleStyle;
  final TextStyle? refreshMessageStyle;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: overlayBackgroundColor ?? _kDefaultBg,
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (overlayIcon != null) ...[
              overlayIcon!,
              const SizedBox(height: 20),
            ],
            loadingIcon ??
                AnimatedRotation(
                  turns: hourglassTurns,
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOut,
                  child: const Icon(
                    Icons.hourglass_top,
                    color: Colors.white,
                    size: 56,
                  ),
                ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                defaultWaitingTitle ??
                    info.title ??
                    'You are in the queue.\nThank you for your patience.',
                textAlign: TextAlign.center,
                style: titleStyle ??
                    const TextStyle(
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                waitingRefreshMessage ??
                    'This page will refresh automatically.\nPlease keep the app open.',
                textAlign: TextAlign.center,
                style: refreshMessageStyle ??
                    const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.5,
                    ),
              ),
            ),
            if (info.lastUpdated != null) ...[
              const SizedBox(height: 20),
              Text(
                '${lastUpdatedPrefix ?? 'Last updated: '}${info.lastUpdated}',
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
    // The revoke+reload cycle is handled by the widget's _revokeAndReload
    // when the host resets state and re-mounts CFWaitingRoomOverlayWidget.
    // Nothing to do here other than dismiss the page and call onConfirm.
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
              const Icon(
                Icons.check_circle_outline,
                color: Colors.greenAccent,
                size: 72,
              ),
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
