# cf_waiting_room — Development Plan

## Package goal
A Flutter package that gates an app behind a Cloudflare Waiting Room using a
three-phase WebView/native-overlay approach with full UI customisation and
Remote Config support.

---

## Three-phase lifecycle

| Phase | Name | Render | Purpose |
|---|---|---|---|
| 1 | `loading` | Full-screen WebView | Show live CF page immediately; detect queue or pass |
| 2 | `waiting` | Native overlay + 1×1 WebView | Show branded UI; keep CF JS alive for cookie refresh |
| 3 | `monitoring` | Invisible 1×1 WebView | Post-pass session monitoring; reload to re-check queue |

Transitions:
- Phase 1 → Phase 2: CF queue keywords / structural URL detected
- Phase 1 → Phase 3: Page title matches `passKeyWord` (skipped queue)
- Phase 2 → Phase 3: Page title matches `passKeyWord` (queue passed) → `onQueueDone()`
- Phase 3 → Phase 2: Session timer reload detects queue → `onNeedReQueue()`

---

## Key decisions

### passKeyWord wins over queueKeyWord
If a page title matches `passKeyWord`, it is never treated as a queue page,
even if it also contains a queue keyword (e.g. "queueSuccess" contains "queue").

### Session timer is wall-clock based
`_sessionStartTime` is stored; on app resume `_rearmSessionTimer()` calculates
remaining time from `DateTime.now()` — prevents under-firing when backgrounded.

### mockConfig replaces isMock
`MockConfig(isEnable, waitDuration)` on the widget constructor. When enabled:
1. Loads bundled `mock_waiting_room.html`
2. After `waitDuration` auto-loads a pass-page HTML (title = first `passKeyWord`)
3. Session timeout shows a dialog ("Yes — re-queue" / "No — stay in app")

### Text config lives in WaitingRoomConfig (Remote Config)
`waitingTitle`, `waitingRefreshMessage`, `lastUpdatedPrefix` are JSON-serialisable
so they can be driven from Firebase Remote Config without an app update.

### Visual config lives on the widget (compile-time)
`overlayIcon`, `loadingIcon`, `overlayBackgroundColor`, `titleStyle`,
`refreshMessageStyle` are Flutter types (`Widget`, `Color`, `TextStyle`) that
cannot be serialised to JSON.

---

## WaitingRoomConfig fields

| Field | Type | Default | Notes |
|---|---|---|---|
| `isEnable` | `bool?` | `false` | Master switch |
| `queueUrl` | `String?` | — | CF waiting room URL |
| `queueKeyWord` | `List<String>?` | `['waiting','queue','等候']` | Title substrings → queue |
| `passKeyWord` | `List<String>?` | `[]` | Title substrings → passed; empty = any non-CF page |
| `etaId` | `String?` | `'waitTime'` | DOM element id for ETA |
| `lastUpdatedId` | `String?` | `'last-updated'` | DOM element id for last-updated |
| `sessionTimeoutSeconds` | `int?` | — | Seconds after pass before Phase 3 check |
| `sessionTimeoutMinutes` | `int?` | — | Minutes (converted to seconds internally) |
| `sessionTimeoutHours` | `int?` | — | Hours (converted to seconds internally) |
| `clearCookieOnStart` | `bool?` | `true` | False = 訪特權 skip-queue mode |
| `locale` | `String?` | system locale | BCP-47 for Accept-Language header |
| `waitingTitle` | `String?` | English fallback | Overrides CF `<h1>` |
| `waitingRefreshMessage` | `String?` | English fallback | Below ETA copy |
| `lastUpdatedPrefix` | `String?` | `'Last updated: '` | Last-updated prefix |
| `reQueueDialogMessage` | `String?` | Chinese default | forceReQueue dialog body |
| `reQueueDialogBtnText` | `String?` | Chinese default | forceReQueue dialog button |

---

## CFWaitingRoomOverlayWidget parameters

| Parameter | Type | Notes |
|---|---|---|
| `config` | `WaitingRoomConfig` | Required |
| `onQueueDone` | `VoidCallback` | Required; Phase 1 skip or Phase 2 pass |
| `onSessionTimeout` | `VoidCallback?` | Phase 3 timer; mock: "No" choice |
| `onNeedReQueue` | `VoidCallback?` | Phase 3 reload detects queue; mock: "Yes" choice |
| `waitingOverlayBuilder` | `Widget Function(ctx, QueueWaitingInfo)?` | Full Phase 2 custom UI |
| `reQueuePageBuilder` | `Widget Function(ctx, onConfirm)?` | Full forceReQueue custom UI |
| `mockConfig` | `MockConfig?` | Mock mode config |
| `locale` | `Locale?` | Widget-level Accept-Language override |
| `overlayIcon` | `Widget?` | Brand logo above spinner |
| `loadingIcon` | `Widget?` | Replaces AnimatedRotation hourglass |
| `overlayBackgroundColor` | `Color?` | Default overlay background |
| `titleStyle` | `TextStyle?` | Default overlay title style |
| `refreshMessageStyle` | `TextStyle?` | Default overlay body style |

---

## MockConfig

```dart
MockConfig({
  bool isEnable = false,
  Duration waitDuration = const Duration(seconds: 30),
})
```

---

## Static API

```dart
CFWaitingRoomOverlayWidget.forceReQueue(
  context,
  config: config,
  onConfirm: () => resetQueueState(),
  pageBuilder: (ctx, onConfirm) => MyPage(onConfirm: onConfirm), // optional
)
```

---

## Pending / future work

- [ ] Publish 0.3.0 to pub.dev with all changes
- [ ] Update CHANGELOG for 0.3.0
- [ ] Update unit tests for new session timeout fields + mock flow
- [ ] Consider SharedPreferences for session start time persistence across kills
- [ ] Android: test invisible WebView suspension workaround (`Opacity(0.01)`)
- [ ] Web platform: document unsupported + provide graceful no-op

---

## File map

```
lib/
  cf_waiting_room.dart              # Public exports
  src/
    cf_waiting_room_overlay_widget.dart  # Main widget (3-phase logic)
    waiting_room_config.dart             # Config model
    waiting_room_config.g.dart           # Generated JSON serialisation
    queue_waiting_info.dart              # QueueWaitingInfo value object
assets/
  mock_waiting_room.html            # Bundled mock page
example/
  lib/main.dart                     # Usage demo
test/
  waiting_room_config_test.dart     # Unit tests
```

