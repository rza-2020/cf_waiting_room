## 0.3.1

- fix: main-frame WebView errors in Phase 2/3 no longer incorrectly fire
  `onQueueDone()`. Error handling is now phase-aware:
  - **Phase 1**: error → `onQueueDone()` (graceful fallback, existing behaviour).
  - **Phase 2**: error → stay in overlay (CF's JS will auto-retry).
  - **Phase 3**: error → restart session timer; never treated as a queue pass.
  Previously, a network hiccup after the non-enterprise cookie-clear reload would
  trigger `onQueueDone()` and silently reset the session timer as if the queue
  had been re-passed.

## 0.3.0

- **breaking:** `sessionTimeoutSeconds` and `sessionTimeoutHours` removed from
  `WaitingRoomConfig` — use `sessionTimeoutMinutes` only.
- feat: `WaitingRoomConfig.isEnterprise` — controls session revocation method.
  - `true` (Enterprise plan): sends `Cf-Waiting-Room-Command: revoke` through WebView
    so the `__cfwaitingroom_*` cookie is included, freeing the CF slot server-side.
  - `false` / unset (Free / Pro / Business): clears WebView cookie jar +
    cache + localStorage locally, then reloads for CF re-evaluation.
- feat: automatic **60-second grace period** added to `effectiveSessionTimeout` when
  `isEnterprise` is `false`. CF auto-renews the cookie on every WebView request;
  the grace ensures it has genuinely expired. Set `sessionTimeoutMinutes` to your CF
  session duration — the +60 s is applied internally.
- feat: `WaitingRoomConfig.autoReQueue` — when `false`, session timeout only
  revokes/clears cookie without auto-reloading. Host calls
  `key.currentState?.checkQueueStatus()` when ready.
- feat: `CFWaitingRoomOverlayWidgetState` is now **public** — use a
  `GlobalKey<CFWaitingRoomOverlayWidgetState>` to call `checkQueueStatus()` externally.
- feat: session start time persisted to `SharedPreferences` (`cf_wr_session_start_ms`)
  so the session timer survives app kills and fires correctly on relaunch.
- fix: pressing "Force Re-Queue" no longer shows a black screen — widget remounts
  from Phase 1 via a `ValueKey` that increments on every re-queue.
- chore: example app refactored into a scenario menu with `isEnterprise` toggle
  and three test scenarios (built-in dialog, custom page, instant re-queue).
- chore: example app uses `flutter_dotenv` to keep the test URL out of git.
- docs: README updated with `isEnterprise` section, plan comparison table,
  grace period explanation, and `autoReQueue` usage.

## 0.2.2

- feat: visual customisation parameters for the default Phase 2 overlay.
  - `overlayIcon` (`Widget?`) — brand logo widget shown above the spinner (replaces old `overlayIconAsset`).
  - `loadingIcon` (`Widget?`) — widget that replaces the `AnimatedRotation` hourglass spinner slot.
  - Accepts any widget: `Image.asset`, `Image.network`, Lottie, `SvgPicture`, etc.
  - `overlayBackgroundColor` (`Color?`) — background colour of the overlay.
  - `titleStyle` / `refreshMessageStyle` (`TextStyle?`) — text styles for the two body lines.
- feat: text labels (`defaultWaitingTitle`, `waitingRefreshMessage`, `lastUpdatedPrefix`) moved to `WaitingRoomConfig` for Firebase Remote Config support.
- chore: expanded `.gitignore` with iOS Pods, Android Gradle, build artefacts.

## 0.2.1

- feat: expose default overlay text via constructor parameters on `CFWaitingRoomOverlayWidget`.
  - `defaultWaitingTitle` — fallback title shown when the CF page supplies no `<h1>` heading.
  - `waitingRefreshMessage` — body message shown below the ETA in the default overlay.
  - `lastUpdatedPrefix` — prefix prepended to the last-updated timestamp (default `'Last updated: '`).
  - All three parameters are optional; the previous hard-coded English strings are used when omitted.

## 0.2.0

- feat: locale support for queue page requests (`Accept-Language` header).
  - New `locale` parameter on `CFWaitingRoomOverlayWidget` (widget-level `Locale` override).
  - New `locale` field in `WaitingRoomConfig` (BCP-47 string, e.g. `"zh-TW"`), ready for Firebase Remote Config.
  - Resolution order: widget `locale` → `WaitingRoomConfig.locale` → device system locale (default).

## 0.1.0

- Initial release.
- `CFWaitingRoomOverlayWidget` with two-phase WebView/native-overlay approach.
- `WaitingRoomConfig` for Firebase Remote Config integration.
- `QueueWaitingInfo` data class passed to `waitingOverlayBuilder`.
- `forceReQueue()` static method with configurable `reQueuePageBuilder`.
- Session timeout callback via `onSessionTimeout`.
- `WidgetsBindingObserver` lifecycle management (auto-reload on resume).
- `clearCookieOnStart` toggle (訪特權 mode).
- Built-in mock HTML asset for development (`isMock: true`).
