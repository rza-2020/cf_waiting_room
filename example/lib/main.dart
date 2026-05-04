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
    queueUrl: 'https://your-site.com/',
    queueKeyWord: ['waiting', 'queue'],
    passKeyWord: ['myapp'],
    sessionTimeoutMinutes: 25,
    clearCookieOnStart: true,
    reQueueDialogMessage:
        'Purchase successful! Please re-join the queue for another attempt.',
    reQueueDialogBtnText: 'Re-join queue',
  );

  @override
  Widget build(BuildContext context) {
    if (_queueDone) return const _AppPage();

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Use isMock: true so the example runs without a real CF endpoint.
            CFWaitingRoomOverlayWidget(
              config: _config,
              isMock: true,
              onQueueDone: () => setState(() => _queueDone = true),
              onSessionTimeout: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Session expired — please re-queue')),
                );
              },
              // Optional: supply your own overlay
              // waitingOverlayBuilder: (ctx, info) => MyWaitingScreen(info: info),
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
                    const SnackBar(content: Text('Cookies cleared — re-queuing')),
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
