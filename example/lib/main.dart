import 'package:cf_waiting_room/cf_waiting_room.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  await dotenv.load(fileName: '.env');
  runApp(const ExampleApp());
}

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

// ── Gate page ─────────────────────────────────────────────────────────────

class _GatePage extends StatefulWidget {
  const _GatePage();

  @override
  State<_GatePage> createState() => _GatePageState();
}

class _GatePageState extends State<_GatePage> {
  bool _queueDone = false;
  int _widgetGeneration = 0;

  // Toggleable config flags
  bool _isEnterprise = false;

  WaitingRoomConfig get _config => WaitingRoomConfig(
        isEnable: true,
        queueUrl: dotenv.env['QUEUE_URL'] ?? 'https://your-site.com/',
        queueKeyWord: ['waiting', 'queue', '等候'],
        passKeyWord: ['PayKool'],
        etaId: 'waitTime',
        lastUpdatedId: 'last-updated',
        sessionTimeoutMinutes: 1,
        clearCookieOnStart: true,
        isEnterprise: _isEnterprise,
        locale: 'zh-HK',
        waitingTitle: '您正在排隊中…',
        waitingRefreshMessage: '目前使用人數較多，請稍作等候。\n系統會盡快為您處理，感謝您的耐心等候。\n\n'
            '此頁面將自動重新整理，請勿關閉應用程式。',
        lastUpdatedPrefix: '最後更新：',
        reQueueDialogMessage: '恭喜您搶購成功！為確保公平，您的本次優先通行證已使用完畢。\n若想再次購買，請重新排隊。',
        reQueueDialogBtnText: '確定並重新排隊',
      );

  void _onQueueDone() => setState(() => _queueDone = true);

  void _onNeedReQueue() => setState(() {
        _queueDone = false;
        _widgetGeneration++;
      });

  void _toggleEnterprise(bool value) => setState(() {
        _isEnterprise = value;
        // Remount widget so the new isEnterprise value takes effect immediately.
        _widgetGeneration++;
      });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            if (_queueDone)
              _AppPage(
                onNeedReQueue: _onNeedReQueue,
                isEnterprise: _isEnterprise,
                onToggleEnterprise: _toggleEnterprise,
                config: _config,
              ),
            CFWaitingRoomOverlayWidget(
              key: ValueKey(_widgetGeneration),
              config: _config,
              onQueueDone: _onQueueDone,
              onSessionTimeout: () {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('⏱ Session expired — checking queue…'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              onNeedReQueue: _onNeedReQueue,
              mockConfig: MockConfig(
                isEnable: false,
                waitDuration: const Duration(seconds: 10),
              ),
              overlayIcon: const Icon(
                Icons.stadium_outlined,
                color: Colors.white70,
                size: 48,
              ),
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
            ),
          ],
        ),
      ),
    );
  }
}

// ── App page — scenario menu ──────────────────────────────────────────────

class _AppPage extends StatelessWidget {
  const _AppPage({
    required this.onNeedReQueue,
    required this.isEnterprise,
    required this.onToggleEnterprise,
    required this.config,
  });

  final VoidCallback onNeedReQueue;
  final bool isEnterprise;
  final ValueChanged<bool> onToggleEnterprise;
  final WaitingRoomConfig config;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2C45),
        title:
            const Text('✅ Queue Passed', style: TextStyle(color: Colors.white)),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Status card ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.greenAccent.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle,
                        color: Colors.greenAccent, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You are in the app!\nCF queue has been passed.',
                        style: TextStyle(color: Colors.white, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Config toggles ───────────────────────────────────────
              const Text(
                'CONFIG',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _ConfigToggle(
                icon: Icons.business,
                label: 'isEnterprise',
                description: isEnterprise
                    ? 'Revoke via Cf-Waiting-Room-Command header'
                    : 'Clear cookie jar + cache locally',
                value: isEnterprise,
                onChanged: onToggleEnterprise,
                activeColor: Colors.amberAccent,
              ),
              const SizedBox(height: 24),

              // ── Scenario menu ────────────────────────────────────────
              const Text(
                'TEST SCENARIOS',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              _ScenarioTile(
                icon: Icons.shopping_cart_checkout,
                title: 'Force Re-Queue',
                subtitle:
                    'Built-in confirmation dialog → releases slot → Phase 1.',
                color: Colors.orangeAccent,
                onTap: () => CFWaitingRoomOverlayWidget.forceReQueue(
                  context,
                  config: config,
                  onConfirm: onNeedReQueue,
                ),
              ),
              const SizedBox(height: 12),

              _ScenarioTile(
                icon: Icons.shopping_bag_outlined,
                title: 'Force Re-Queue (Custom Page)',
                subtitle: 'Same flow with a custom confirmation screen.',
                color: Colors.purpleAccent,
                onTap: () => CFWaitingRoomOverlayWidget.forceReQueue(
                  context,
                  config: config,
                  onConfirm: onNeedReQueue,
                  pageBuilder: (ctx, onConfirm) =>
                      _CustomReQueuePage(onConfirm: onConfirm),
                ),
              ),
              const SizedBox(height: 12),

              _ScenarioTile(
                icon: Icons.refresh,
                title: 'Instant Re-Queue (no dialog)',
                subtitle: 'Directly fires onNeedReQueue — no confirmation.',
                color: Colors.blueAccent,
                onTap: onNeedReQueue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Config toggle row ─────────────────────────────────────────────────────

class _ConfigToggle extends StatelessWidget {
  const _ConfigToggle({
    required this.icon,
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
    required this.activeColor,
  });

  final IconData icon;
  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: value
            ? activeColor.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value
              ? activeColor.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: value ? activeColor : Colors.white38, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: value ? activeColor : Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                Text(description,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11, height: 1.4)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: activeColor,
            activeTrackColor: activeColor.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }
}

// ── Scenario tile ─────────────────────────────────────────────────────────

class _ScenarioTile extends StatelessWidget {
  const _ScenarioTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 12, height: 1.4)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: color.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Custom Phase 2 overlay (optional example) ─────────────────────────────

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
              Text('ETA: ${info.eta}',
                  style: const TextStyle(color: Colors.amber)),
            ],
            if (info.lastUpdated != null) ...[
              const SizedBox(height: 8),
              Text('Updated: ${info.lastUpdated}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Custom forceReQueue page (optional example) ───────────────────────────

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
                  style:
                      TextStyle(color: Colors.white, fontSize: 18, height: 1.5),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Re-join queue',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
