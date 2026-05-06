import 'package:cf_waiting_room/cf_waiting_room.dart';
import 'package:flutter/material.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'cf_waiting_room demo',
      home: _GatePage(),
    );
  }
}

// ── Config ────────────────────────────────────────────────────────────────

/// All WaitingRoomConfig fields — normally loaded from Firebase Remote Config.
final _config = WaitingRoomConfig(
  // ── Required ──────────────────────────────────────────────────────────
  isEnable: true,
  queueUrl: 'https://busyprod.paykool.com.hk/',

  // ── Keyword detection ─────────────────────────────────────────────────
  queueKeyWord: ['waiting', 'queue', '等候'], // page title substrings → queue
  // passKeyWord: ['queueSuccess'], // page title substrings → passed
  passKeyWord: ['PayKool'], // page title substrings → passed

  // ── DOM element IDs scraped from the CF page ──────────────────────────
  etaId: 'waitTime',
  lastUpdatedId: 'last-updated',

  // ── Session timeout (choose ONE unit; seconds takes priority) ─────────
  sessionTimeoutMinutes: 1, // start counting AFTER queue passes (Phase 3)
  // sessionTimeoutMinutes: 25,

  // ── Cookie / cache behaviour ──────────────────────────────────────────
  clearCookieOnStart: true, // false = 訪特權 skip-queue mode

  // ── Locale (Accept-Language header) ──────────────────────────────────
  locale:
      'zh-HK', // overridden per-widget via CFWaitingRoomOverlayWidget.locale

  // ── Default overlay text (Remote Config-friendly) ─────────────────────
  waitingTitle: '您正在排隊中…', // overrides CF <h1>
  waitingRefreshMessage: '目前使用人數較多，請稍作等候。\n系統會盡快為您處理，感謝您的耐心等候。\n\n'
      '此頁面將自動重新整理，請勿關閉應用程式。',
  lastUpdatedPrefix: '最後更新：',

  // ── ForceReQueue dialog text ──────────────────────────────────────────
  reQueueDialogMessage: '恭喜您搶購成功！為確保公平，您的本次優先通行證已使用完畢。\n若想再次購買，請重新排隊。',
  reQueueDialogBtnText: '確定並重新排隊',
);

// ── Gate page ─────────────────────────────────────────────────────────────

class _GatePage extends StatefulWidget {
  const _GatePage();

  @override
  State<_GatePage> createState() => _GatePageState();
}

class _GatePageState extends State<_GatePage> {
  bool _queueDone = false;

  void _onQueueDone() => setState(() => _queueDone = true);
  void _onNeedReQueue() => setState(() => _queueDone = false);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // ── Your app content (shown in Phase 3 after queue passes) ──
            if (_queueDone) _AppPage(onNeedReQueue: _onNeedReQueue),

            // ── CFWaitingRoomOverlayWidget ──────────────────────────────
            CFWaitingRoomOverlayWidget(
              // ── Required ─────────────────────────────────────────────
              config: _config,
              onQueueDone: _onQueueDone,

              // ── Session / re-queue callbacks ──────────────────────────
              // Called in production when sessionTimeout fires (Phase 3).
              // In mock mode, fires when user taps "No — queue cleared".
              onSessionTimeout: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Session expired — timer restarted'),
                  ),
                );
              },
              // Called when CF queue becomes active again after session
              // timeout (production: reload detected queue;
              // mock: user tapped "Yes — still in queue").
              onNeedReQueue: _onNeedReQueue,

              // ── Mock mode ─────────────────────────────────────────────
              // Remove MockConfig (or set isEnable: false) for production.
              mockConfig: MockConfig(
                isEnable: false,
                waitDuration: const Duration(seconds: 30),
              ),

              // ── Locale override ───────────────────────────────────────
              // Widget-level override takes priority over config.locale.
              // locale: const Locale('en', 'US'),

              // ── Default overlay visual customisation ──────────────────
              // Brand logo shown above the spinner (any Widget).
              overlayIcon: const Icon(
                Icons.stadium_outlined,
                color: Colors.white70,
                size: 48,
              ),
              // Custom spinner — replace with Lottie / GIF / SvgPicture.
              // When null: built-in AnimatedRotation hourglass is used.
              // loadingIcon: Image.asset('assets/spinner.gif', width: 56),
              overlayBackgroundColor: const Color(0xFF1A2C45),
              titleStyle: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
              refreshMessageStyle: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.5,
              ),

              // ── Full custom Phase 2 overlay (overrides all above) ─────
              // Uncomment to use your own branded waiting screen.
              // waitingOverlayBuilder: (context, info) => _CustomWaitingOverlay(info: info),

              // NOTE: custom re-queue page is passed to forceReQueue(),
              // not to this widget. See pageBuilder in _AppPage below.
            ),
          ],
        ),
      ),
    );
  }
}

// ── App page (shown after queue passes) ──────────────────────────────────

class _AppPage extends StatelessWidget {
  const _AppPage({required this.onNeedReQueue});

  final VoidCallback onNeedReQueue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('App — queue passed')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎉 You are in the app!'),
            const SizedBox(height: 32),

            // ── forceReQueue ───────────────────────────────────────────
            // Trigger manually after a purchase / action that consumes
            // the user's queue slot.
            ElevatedButton(
              onPressed: () => CFWaitingRoomOverlayWidget.forceReQueue(
                context,
                config: _config,
                // Called after cookies are cleared and page is dismissed.
                onConfirm: onNeedReQueue,
                // Optional: supply a fully custom re-queue confirmation page.
                // pageBuilder: (ctx, onConfirm) => _CustomReQueuePage(onConfirm: onConfirm),
              ),
              child: const Text('Simulate force re-queue'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Optional: custom Phase 2 overlay example ─────────────────────────────

class _CustomWaitingOverlay extends StatelessWidget {
  const _CustomWaitingOverlay({required this.info});

  final QueueWaitingInfo info;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D1B2A),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.amber),
            const SizedBox(height: 24),
            Text(
              info.title ?? 'You are in the queue.',
              style: const TextStyle(color: Colors.white, fontSize: 20),
              textAlign: TextAlign.center,
            ),
            if (info.eta != null) ...[
              const SizedBox(height: 12),
              Text(
                'ETA: ${info.eta}',
                style: const TextStyle(color: Colors.amber),
              ),
            ],
            if (info.lastUpdated != null) ...[
              const SizedBox(height: 8),
              Text(
                'Updated: ${info.lastUpdated}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Optional: custom forceReQueue page example ────────────────────────────

class _CustomReQueuePage extends StatelessWidget {
  const _CustomReQueuePage({required this.onConfirm});

  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle,
                    color: Colors.greenAccent, size: 72),
                const SizedBox(height: 24),
                const Text(
                  'Purchase successful!\nPlease re-queue for another attempt.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: onConfirm,
                  child: const Text('Re-join queue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
