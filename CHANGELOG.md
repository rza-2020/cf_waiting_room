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
