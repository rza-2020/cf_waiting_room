# cf_waiting_room

> **Disclaimer:** This package is an unofficial community library and is not
> affiliated with, endorsed by, or supported by Cloudflare, Inc.
> Cloudflare® is a registered trademark of Cloudflare, Inc.

An unofficial Flutter widget that gates your app behind a [Cloudflare Waiting Room](https://developers.cloudflare.com/waiting-room/), with a two-phase WebView/native-overlay approach and full UI customisation.

## Features

- **Two-phase display** — shows the live CF queue page immediately (Phase 1), then switches to a native overlay while keeping the WebView alive at 1×1 px so CF's auto-refresh JS keeps the session cookie valid (Phase 2).
- **Dynamic keyword detection** — queue/pass keywords and CSS selectors are driven by `WaitingRoomConfig`, ready for Firebase Remote Config.
- **Session timeout callback** — fires `onSessionTimeout` after a configurable number of minutes.
- **Force re-queue** — `forceReQueue()` shows a non-dismissible page, clears CF cookies, then calls your callback.
- **Custom UI builders** — supply `waitingOverlayBuilder` and `reQueuePageBuilder` to render your own brand UI.
- **訪特權 mode** — set `clearCookieOnStart: false` to skip cookie clearing (skip-queue pass).
- **Dev mock** — `isMock: true` loads a bundled HTML page with a "simulate done" button.

## Installation

```yaml
dependencies:
  cf_waiting_room: ^0.1.0
```

For local development inside a monorepo:

```yaml
dependencies:
  cf_waiting_room:
    path: packages/cf_waiting_room
```

## Basic usage

Wrap the widget in a `Stack` — it returns `Positioned` children internally.

```dart
Stack(
  children: [
    CFWaitingRoomOverlayWidget(
      config: WaitingRoomConfig(
        isEnable: true,
        queueUrl: 'https://your-site.com/',
        queueKeyWord: ['waiting', 'queue'],
        passKeyWord: ['myapp'],
        sessionTimeoutMinutes: 25,
      ),
      onQueueDone: () => setState(() => _queueDone = true),
      onSessionTimeout: () => _showTimeoutDialog(),
    ),
  ],
)
```

## Custom UI

### Waiting overlay (Phase 2)

```dart
CFWaitingRoomOverlayWidget(
  config: config,
  onQueueDone: _onDone,
  waitingOverlayBuilder: (context, info) {
    return MyWaitingScreen(
      title: info.title ?? 'You are in the queue',
      eta: info.eta,
      lastUpdated: info.lastUpdated,
    );
  },
)
```

### Force re-queue page

```dart
CFWaitingRoomOverlayWidget(
  config: config,
  onQueueDone: _onDone,
  reQueuePageBuilder: (context, onConfirm) {
    return MyReQueuePage(onConfirm: onConfirm);
  },
)
```

### Trigger force re-queue (e.g. after a successful purchase)

```dart
await CFWaitingRoomOverlayWidget.forceReQueue(
  context,
  config: waitingRoomConfig,
  onConfirm: () => _resetToQueuePhase(),
);
```

## Firebase Remote Config integration

Store `WaitingRoomConfig` as a JSON string in Firebase Remote Config under the key `waitingRoomConfig`:

```json
{
  "isEnable": true,
  "queueUrl": "https://your-site.com/",
  "queueKeyWord": ["waiting", "queue"],
  "passKeyWord": ["myapp"],
  "etaId": "waitTime",
  "lastUpdatedId": "last-updated",
  "sessionTimeoutMinutes": 25,
  "clearCookieOnStart": true,
  "reQueueDialogMessage": "You have successfully purchased. Please re-queue for another attempt.",
  "reQueueDialogBtnText": "Re-join queue"
}
```

Then parse it in your config layer:

```dart
final raw = remoteConfig.getString('waitingRoomConfig');
final config = raw.isNotEmpty
    ? WaitingRoomConfig.fromJson(jsonDecode(raw))
    : WaitingRoomConfig(isEnable: false);
```

## Platform support

| Platform | Support |
|----------|---------|
| Android  | ✅ |
| iOS      | ✅ |
| Web      | ❌ (webview_flutter not supported on Web) |
