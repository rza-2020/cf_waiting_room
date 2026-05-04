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
