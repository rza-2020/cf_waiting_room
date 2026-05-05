import 'package:cf_waiting_room/cf_waiting_room.dart';
import 'package:flutter/material.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'cf_waiting_room example',
      home: _GatePage(),
    );
  }
}

class _GatePage extends StatefulWidget {
  const _GatePage();

  @override
  State<_GatePage> createState() => _GatePageState();
}

class _GatePageState extends State<_GatePage> {
  bool _queueDone = false;

  // Minimal config — no Firebase needed for the example.
  static final _config = WaitingRoomConfig(
    isEnable: true,
    queueUrl: 'https://test.queue.com/',
    queueKeyWord: ['waiting', 'queue', '等候'],
    passKeyWord: ['queueSuccess'],
    etaId: 'waitTime',
    lastUpdatedId: 'last-updated',
    sessionTimeoutSeconds: 15, // fires at 15s — before the mock pass at 30s
    clearCookieOnStart: true,
    waitingTitle: '您正在排隊中…',
    waitingRefreshMessage:
        '目前使用人數較多，請稍作等候。\n系統會盡快為您處理，感謝您的耐心等候。\n\n此頁面將自動重新整理，請勿關閉應用程式。',
    lastUpdatedPrefix: '最後更新：',
    reQueueDialogMessage: '恭喜您搶購成功！為確保公平，您的本次優先通行證已使用完畢。若想再次購買，請重新排隊。',
    reQueueDialogBtnText: '確定並重新排隊',
    locale: 'zh-HK',
  );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // App content shown after queue passes — always in tree
            if (_queueDone) const _AppPage(),

            // Widget stays in tree for Phase 3 session monitoring
            CFWaitingRoomOverlayWidget(
              config: _config,
              mockConfig: MockConfig(
                isEnable: true,
                waitDuration: const Duration(seconds: 10),
              ),
              onQueueDone: () => setState(() => _queueDone = true),
              onNeedReQueue: () => setState(() => _queueDone = false),
              onSessionTimeout: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Session expired — staying in app')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AppPage extends StatelessWidget {
  const _AppPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('App')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Queue passed — welcome!'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => CFWaitingRoomOverlayWidget.forceReQueue(
                context,
                config: _GatePageState._config,
                onConfirm: () {
                  // In a real app: logout + reset to queue phase
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Cookies cleared — re-queuing')),
                  );
                },
              ),
              child: const Text('Simulate force re-queue'),
            ),
          ],
        ),
      ),
    );
  }
}
