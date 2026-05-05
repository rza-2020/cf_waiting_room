# cf_waiting_room

> **Disclaimer:** This package is an unofficial community library and is not
> affiliated with, endorsed by, or supported by Cloudflare, Inc.
> Cloudflare® is a registered trademark of Cloudflare, Inc.

An unofficial Flutter widget that gates your app behind a [Cloudflare Waiting Room](https://developers.cloudflare.com/waiting-room/).

---

## How it works — the user journey

Imagine your app is a ticket-sale event backed by a Cloudflare Waiting Room.

```
User opens app
      │
      ▼
┌─────────────────────────────┐
│  Phase 1 – Live CF page     │  Full-screen WebView.
│  (WebView full-screen)      │  User sees the real CF queue page immediately.
└────────────┬────────────────┘
             │ CF confirms queue active
             ▼
┌─────────────────────────────┐
│  Phase 2 – Native overlay   │  Your brand UI replaces the raw CF page.
│  (overlay + 1×1 WebView)    │  The tiny invisible WebView keeps CF's JS
└────────────┬────────────────┘  running so the session cookie stays valid.
             │ CF redirects → pass page (title contains passKeyWord)
             ▼
┌─────────────────────────────┐
│  Phase 3 – Silent monitor   │  onQueueDone() fires — your app is shown.
│  (invisible 1×1 WebView)    │  A session timer continues ticking in the
└────────────┬────────────────┘  background to detect re-queue situations.
             │ sessionTimeout fires
             ▼
      WebView reloads silently
      ┌── queue active? ──▶ onNeedReQueue() → back to Phase 2
      └── still clear?  ──▶ onSessionTimeout() → timer restarts
```

---

## Installation

```yaml
dependencies:
  cf_waiting_room: ^0.3.0
```

---

## Quick start

```dart
class _GatePageState extends State<_GatePage> {
  bool _queueDone = false;

  final _config = WaitingRoomConfig(
    isEnable: true,
    queueUrl: 'https://your-site.com/',
    queueKeyWord: ['waiting', 'queue'],
    passKeyWord: ['myapp'],           // substring of the real app page title
    sessionTimeoutSeconds: 1500,     // 25 min post-pass monitoring interval
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (_queueDone) YourAppContent(),
        CFWaitingRoomOverlayWidget(
          config: _config,
          onQueueDone: () => setState(() => _queueDone = true),
          onNeedReQueue: () => setState(() => _queueDone = false),
          onSessionTimeout: () => _showSessionExpiredBanner(),
        ),
      ],
    );
  }
}
```

---

## Session timeout

`sessionTimeoutSeconds` / `sessionTimeoutMinutes` / `sessionTimeoutHours`
starts counting **after the queue is passed** (Phase 3). When it fires the
WebView reloads silently to re-check whether the CF queue is back.

```dart
WaitingRoomConfig(
  sessionTimeoutSeconds: 1500,  // 25 minutes
  // or: sessionTimeoutMinutes: 25,
  // or: sessionTimeoutHours: 1,
)
```

---

## Mock mode — test the full flow without a live CF endpoint

```dart
CFWaitingRoomOverlayWidget(
  config: _config,
  mockConfig: MockConfig(
    isEnable: true,
    waitDuration: Duration(seconds: 10), // auto-pass after 10 s
  ),
  onQueueDone: () => setState(() => _queueDone = true),
  onNeedReQueue: () => setState(() => _queueDone = false),
  onSessionTimeout: () => _showBanner('Session expired'),
)
```

**Mock timeline** (with `sessionTimeoutSeconds: 15`, `waitDuration: 10s`):

| t | Event |
|---|---|
| 0 s | Mock queue HTML loads → Phase 1 → Phase 2 overlay |
| 10 s | Auto-pass → `onQueueDone()` fires, your app appears (Phase 3) |
| 25 s (10+15) | Dialog: **"Yes — re-queue"** → `onNeedReQueue()` + reset to Phase 1 |
| | **"No — stay in app"** → `onSessionTimeout()` + timer restarts |

---

## Force re-queue (e.g. after a successful purchase)

```dart
await CFWaitingRoomOverlayWidget.forceReQueue(
  context,
  config: _config,
  onConfirm: () => setState(() => _queueDone = false),
);
```

---

## Customise the default overlay

No full custom builder needed — pass widgets and styles directly:

```dart
CFWaitingRoomOverlayWidget(
  config: _config,
  onQueueDone: _onDone,
  overlayIcon: Image.asset('assets/logo.png', height: 64),
  loadingIcon: Image.asset('assets/spinner.gif', width: 56, height: 56),
  overlayBackgroundColor: const Color(0xFF0D1B2A),
  titleStyle: const TextStyle(color: Colors.amber, fontSize: 22),
  refreshMessageStyle: const TextStyle(color: Colors.white60, fontSize: 14),
)
```

Text labels driven from `WaitingRoomConfig` (Remote Config-friendly):

| Config field | Description |
|---|---|
| `waitingTitle` | Overrides CF page `<h1>` — always shown |
| `waitingRefreshMessage` | Body copy below the ETA |
| `lastUpdatedPrefix` | Prefix before the last-updated timestamp |

---

## Locale — `Accept-Language` header

Resolution order:
1. `CFWaitingRoomOverlayWidget.locale` — widget-level `Locale` override
2. `WaitingRoomConfig.locale` — Remote Config BCP-47 string, e.g. `"zh-HK"`
3. Device system locale (`PlatformDispatcher.instance.locale`)

```dart
CFWaitingRoomOverlayWidget(
  config: _config,
  locale: const Locale('zh', 'HK'),
  onQueueDone: _onDone,
)
```

---

## Custom UI builders

### Phase 2 waiting overlay

```dart
CFWaitingRoomOverlayWidget(
  config: _config,
  onQueueDone: _onDone,
  waitingOverlayBuilder: (context, info) => MyWaitingScreen(
    title: info.title,
    eta: info.eta,
    lastUpdated: info.lastUpdated,
  ),
)
```

### Force re-queue page

```dart
CFWaitingRoomOverlayWidget(
  config: _config,
  onQueueDone: _onDone,
  reQueuePageBuilder: (context, onConfirm) =>
      MyReQueuePage(onConfirm: onConfirm),
)
```

---

## Firebase Remote Config integration

```json
{
  "isEnable": true,
  "queueUrl": "https://your-site.com/",
  "queueKeyWord": ["waiting", "queue"],
  "passKeyWord": ["myapp"],
  "etaId": "waitTime",
  "lastUpdatedId": "last-updated",
  "sessionTimeoutSeconds": 1500,
  "clearCookieOnStart": true,
  "locale": "zh-HK",
  "waitingTitle": "您正在排隊中，感謝耐心等候。",
  "waitingRefreshMessage": "本頁將自動更新，請勿關閉應用程式。",
  "lastUpdatedPrefix": "最後更新：",
  "reQueueDialogMessage": "恭喜您搶購成功！若想再次購買，請重新排隊。",
  "reQueueDialogBtnText": "確定並重新排隊"
}
```

```dart
final raw = remoteConfig.getString('waitingRoomConfig');
final config = raw.isNotEmpty
    ? WaitingRoomConfig.fromJson(jsonDecode(raw))
    : WaitingRoomConfig(isEnable: false);
```

---

## 訪特權 mode (skip-queue pass)

Set `clearCookieOnStart: false` to preserve existing CF cookies so a returning
user skips the queue if their session is still valid.

---

## Platform support

| Platform | Support |
|----------|---------|
| Android  | ✅ |
| iOS      | ✅ |
| Web      | ❌ (`webview_flutter` not supported on Web) |
