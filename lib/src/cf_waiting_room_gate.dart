import 'package:flutter/material.dart';

import 'cf_waiting_room_overlay_widget.dart';
import 'queue_waiting_info.dart';
import 'waiting_room_config.dart';

/// A drop-in root widget that gates your app behind a
/// [Cloudflare Waiting Room](https://developers.cloudflare.com/waiting-room/).
///
/// Unlike [CFWaitingRoomOverlayWidget] — which must be placed inside a [Stack]
/// yourself — `CFWaitingRoomGate` owns the [Stack] and all the queue-state
/// bookkeeping internally.  Just provide [appBuilder] for your app content and
/// drop the gate wherever you need it.
///
/// ## Usage (minimal)
///
/// ```dart
/// @override
/// Widget build(BuildContext context) {
///   return CFWaitingRoomGate(
///     config: WaitingRoomConfig(
///       isEnable: true,
///       queueUrl: 'https://your-site.com/',
///       passKeyWord: ['myapp'],
///       sessionTimeoutMinutes: 25,
///     ),
///     appBuilder: (context) => const MyAppHome(),
///   );
/// }
/// ```
///
/// ## What it manages for you
///
/// | Concern | CFWaitingRoomGate | manual Stack |
/// |---------|:-----------------:|:------------:|
/// | `_queueDone` state | ✅ internal | ❌ manual |
/// | Remount key on re-queue | ✅ internal | ❌ manual |
/// | Stack layout | ✅ internal | ❌ manual |
/// | Invisible WebView in Phase 3 | ✅ internal | ✅ handled by overlay widget |
///
/// ## Advanced — accessing the inner widget state
///
/// If you need to call [CFWaitingRoomOverlayWidgetState.checkQueueStatus],
/// use [overlayKey]:
///
/// ```dart
/// final _overlayKey = GlobalKey<CFWaitingRoomOverlayWidgetState>();
///
/// CFWaitingRoomGate(
///   config: _config,
///   overlayKey: _overlayKey,
///   appBuilder: (context) => MyApp(),
/// )
///
/// // later:
/// _overlayKey.currentState?.checkQueueStatus();
/// ```
class CFWaitingRoomGate extends StatefulWidget {
  const CFWaitingRoomGate({
    super.key,
    required this.config,
    required this.appBuilder,
    this.onSessionTimeout,
    this.onNeedReQueue,
    this.onQueueDone,
    this.waitingOverlayBuilder,
    this.mockConfig,
    this.locale,
    this.overlayIcon,
    this.loadingIcon,
    this.overlayBackgroundColor,
    this.titleStyle,
    this.refreshMessageStyle,
    this.overlayKey,
  });

  /// Configuration for the waiting room behaviour and keyword detection.
  final WaitingRoomConfig config;

  /// Builder for your app content — called once the CF queue is passed.
  ///
  /// Receives a `onReQueue` callback you can pass to
  /// [CFWaitingRoomOverlayWidget.forceReQueue]'s `onConfirm` so the gate
  /// resets back to Phase 1 automatically when the user confirms:
  ///
  /// ```dart
  /// appBuilder: (context, onReQueue) => ElevatedButton(
  ///   onPressed: () => CFWaitingRoomOverlayWidget.forceReQueue(
  ///     context,
  ///     config: config,
  ///     onConfirm: onReQueue,   // ← gate resets automatically
  ///   ),
  ///   child: const Text('Re-queue'),
  /// ),
  /// ```
  final Widget Function(BuildContext context, VoidCallback onReQueue)
      appBuilder;

  /// Called when the session timer fires (Phase 3 → reload check).
  /// The gate also shows a [SnackBar] with the supplied text automatically.
  /// Pass `null` to suppress the snack bar.
  final VoidCallback? onSessionTimeout;

  /// Called when the widget detects the CF queue is active again after a
  /// timeout.  The gate resets itself back to Phase 1 automatically.
  /// Use this callback for any extra host-side cleanup (e.g. sign-out).
  final VoidCallback? onNeedReQueue;

  /// Called when the CF queue is passed for the first time (or after a
  /// re-queue). Use for analytics / logging — the gate already transitions
  /// the UI automatically.
  final VoidCallback? onQueueDone;

  /// Custom Phase 2 overlay builder — see [CFWaitingRoomOverlayWidget.waitingOverlayBuilder].
  final Widget Function(BuildContext context, QueueWaitingInfo info)?
      waitingOverlayBuilder;

  /// Mock mode — see [CFWaitingRoomOverlayWidget.mockConfig].
  final MockConfig? mockConfig;

  /// BCP-47 locale override — see [CFWaitingRoomOverlayWidget.locale].
  final Locale? locale;

  // ── Default overlay visual customisation (passed through) ─────────────

  /// See [CFWaitingRoomOverlayWidget.overlayIcon].
  final Widget? overlayIcon;

  /// See [CFWaitingRoomOverlayWidget.loadingIcon].
  final Widget? loadingIcon;

  /// See [CFWaitingRoomOverlayWidget.overlayBackgroundColor].
  final Color? overlayBackgroundColor;

  /// See [CFWaitingRoomOverlayWidget.titleStyle].
  final TextStyle? titleStyle;

  /// See [CFWaitingRoomOverlayWidget.refreshMessageStyle].
  final TextStyle? refreshMessageStyle;

  /// Optional [GlobalKey] to access
  /// [CFWaitingRoomOverlayWidgetState.checkQueueStatus] from outside.
  final GlobalKey<CFWaitingRoomOverlayWidgetState>? overlayKey;

  @override
  State<CFWaitingRoomGate> createState() => _CFWaitingRoomGateState();
}

class _CFWaitingRoomGateState extends State<CFWaitingRoomGate> {
  bool _queueDone = false;

  /// Incrementing forces [CFWaitingRoomOverlayWidget] to remount from Phase 1.
  int _overlayGeneration = 0;

  void _onQueueDone() {
    setState(() => _queueDone = true);
    widget.onQueueDone?.call();
  }

  void _onNeedReQueue() {
    setState(() {
      _queueDone = false;
      _overlayGeneration++;
    });
    widget.onNeedReQueue?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── App content — shown after queue passes (Phase 3) ─────────────
        if (_queueDone) widget.appBuilder(context, _onNeedReQueue),

        // ── CF overlay — keyed so it remounts cleanly on re-queue ─────────
        CFWaitingRoomOverlayWidget(
          key: widget.overlayKey ?? ValueKey(_overlayGeneration),
          config: widget.config,
          onQueueDone: _onQueueDone,
          onSessionTimeout: widget.onSessionTimeout,
          onNeedReQueue: _onNeedReQueue,
          waitingOverlayBuilder: widget.waitingOverlayBuilder,
          mockConfig: widget.mockConfig,
          locale: widget.locale,
          overlayIcon: widget.overlayIcon,
          loadingIcon: widget.loadingIcon,
          overlayBackgroundColor: widget.overlayBackgroundColor,
          titleStyle: widget.titleStyle,
          refreshMessageStyle: widget.refreshMessageStyle,
        ),
      ],
    );
  }
}
