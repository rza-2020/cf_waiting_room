## 0.4.1

- feat: `WaitingRoomConfig.autoReQueue` flag — when `false`, session timeout only
  revokes/clears the cookie without auto-reloading. Host calls
  `key.currentState?.checkQueueStatus()` when ready to re-check queue status.
  Defaults to `true` (existing behaviour unchanged).
- feat: `CFWaitingRoomOverlayWidgetState` is now **public** — hold a
  `GlobalKey<CFWaitingRoomOverlayWidgetState>` to call `checkQueueStatus()` externally.
- fix: pressing "Force Re-Queue" no longer shows a black screen — the widget is
  remounted from Phase 1 via a `ValueKey` that increments on every re-queue.
- chore: example app refactored into a scenario menu with `isEnterprise` toggle
  and three test scenarios (built-in dialog, custom page, instant re-queue).
- chore: example app uses `flutter_dotenv` to keep the test URL out of git.

## 0.4.0

- **breaking:** `sessionTimeoutSeconds` and `sessionTimeoutHours` removed from
  `WaitingRoomConfig` — use `sessionTimeoutMinutes` only.
- feat: `WaitingRoomConfig.isEnterprise` flag controls session revocation method.
  - `isEnterprise: true` (Enterprise plan) — sends `Cf-Waiting-Room-Command: revoke`
    header through the WebView so the `__cfwaitingroom_*` session cookie is included,
    freeing the CF slot server-side immediately.
  - `isEnterprise: false` / unset (Free / Pro / Business) — clears the WebView cookie
    jar via `WebViewCookieManager().clearCookies()` + cache + localStorage locally,
    then reloads so CF re-evaluates without the session cookie.
- feat: automatic **60-second grace period** added to `effectiveSessionTimeout` when
  `isEnterprise` is `false`.  CF auto-renews the `__cfwaitingroom_*` cookie expiry on
  every WebView request; the grace period ensures the cookie has genuinely expired
  before the widget clears and re-evaluates.  Set `sessionTimeoutMinutes` equal to
  your CF session duration — the extra 60 s is applied internally.
- chore: bumped package version to `0.4.0`.
- docs: README updated with `isEnterprise` section, plan comparison table, and
  grace period explanation. Firebase Remote Config JSON example updated.

## 0.3.0

- feat: session start time is now persisted to `SharedPreferences` (`cf_wr_session_start_ms`)
  so the session timer survives app kills and fires correctly on relaunch.
  - `_startSessionTimer()` honours a previously restored start time; does **not** reset
    the clock on restart if the session is still within its timeout window.
  - Persisted key is cleared on re-queue (Phase 3 → Phase 2), mock reset, and when
    Phase 3 monitoring detects the queue is active again.
- test: expanded unit-test suite for `WaitingRoomConfig` and `MockConfig`.
  - Added `effectiveSessionTimeout` group: null default, seconds / minutes / hours
    individual cases, full priority-order matrix (seconds > minutes > hours), and
    zero/negative treated-as-unset edge cases.
  - Added `fromJson` / `toJson` tests for `sessionTimeoutSeconds` and
    `sessionTimeoutHours`.
  - Added `toJson` assertion for all three timeout fields together.
  - Added `MockConfig` group: default values, custom values, `fromJson` roundtrip,
    `toJson` roundtrip, and missing-field defaults.
  - Added `QueueWaitingInfo` group: null defaults and provided values.
- chore: bumped package version to `0.3.0`.

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
