import 'package:json_annotation/json_annotation.dart';

part 'waiting_room_config.g.dart';

// ── MockConfig ────────────────────────────────────────────────────────────

/// Configuration for the built-in mock/development mode.
///
/// When [isEnable] is `true` and the widget is running with `isMock: true`,
/// a timer fires after [waitDuration] and auto-simulates a successful queue
/// pass, letting you test the full queue → app transition without a live CF
/// endpoint.
class MockConfig {
  /// Activates the automatic pass simulation.
  final bool isEnable;

  /// How long to wait before simulating a queue pass.
  /// Defaults to 30 seconds.
  final Duration waitDuration;

  const MockConfig({
    this.isEnable = false,
    this.waitDuration = const Duration(seconds: 30),
  });

  factory MockConfig.fromJson(Map<String, dynamic> json) => MockConfig(
        isEnable: json['isEnable'] as bool? ?? false,
        waitDuration:
            Duration(seconds: (json['waitSeconds'] as num?)?.toInt() ?? 30),
      );

  Map<String, dynamic> toJson() => {
        'isEnable': isEnable,
        'waitSeconds': waitDuration.inSeconds,
      };
}

@JsonSerializable()
class WaitingRoomConfig {
  @JsonKey(name: 'isEnable')
  final bool? isEnable;

  @JsonKey(name: 'queueUrl')
  final String? queueUrl;

  /// Title/URL substrings that indicate the user is in the CF waiting room.
  @JsonKey(name: 'queueKeyWord')
  final List<String>? queueKeyWord;

  /// Title substrings that indicate the queue has been passed (real app page).
  @JsonKey(name: 'passKeyWord')
  final List<String>? passKeyWord;

  /// CSS element id for the ETA text. Defaults to 'waitTime'.
  @JsonKey(name: 'etaId')
  final String? etaId;

  /// CSS element id for the last-updated text. Defaults to 'last-updated'.
  @JsonKey(name: 'lastUpdatedId')
  final String? lastUpdatedId;

  /// Minutes after queue is confirmed before the session timeout fires and
  /// the widget re-checks whether the CF queue is active again.
  ///
  /// **Non-enterprise:** set this to your CF waiting-room session duration —
  /// the widget automatically adds a 60-second grace period so the CF cookie
  /// has truly expired before the widget clears it and re-evaluates.
  ///
  /// **Enterprise:** set this equal to (or slightly less than) your CF
  /// waiting-room session duration — the revoke header frees the slot
  /// immediately.
  @JsonKey(name: 'sessionTimeoutMinutes')
  final int? sessionTimeoutMinutes;

  /// 訪特權 Off → false: skip clearing cookies/cache on widget init.
  /// Defaults to true (always clear).
  @JsonKey(name: 'clearCookieOnStart')
  final bool? clearCookieOnStart;

  /// Set to `true` when your Cloudflare zone is on the **Enterprise** plan.
  ///
  /// | Plan              | Session revocation method |
  /// |-------------------|--------------------------|
  /// | Free / Pro / Business | Cookie jar + cache cleared locally (CF re-evaluates on next request) |
  /// | **Enterprise**    | `Cf-Waiting-Room-Command: revoke` header — CF frees the slot server-side immediately |
  ///
  /// **Non-enterprise note:** CF automatically renews the `__cfwaitingroom_*`
  /// cookie expiry on every request the WebView makes.  To guarantee that the
  /// cookie has *actually* expired by the time the Flutter session timer fires,
  /// set [sessionTimeoutMinutes] (or seconds/hours) to **CF's configured
  /// waiting-room session duration + at least 1 minute**.  The widget adds a
  /// 60-second automatic grace period on top of your configured value when
  /// [isEnterprise] is `false`.
  @JsonKey(name: 'isEnterprise')
  final bool? isEnterprise;

  /// Controls whether the widget automatically transitions back to the queue
  /// overlay (Phase 2) when a session timeout check detects the CF queue is
  /// active again.
  ///
  /// | Value | Behaviour |
  /// |-------|-----------|
  /// | `true` (default) | On session timeout: revoke/clear cookie → reload → if queue detected, auto-transition to Phase 2 and call `onNeedReQueue`. |
  /// | `false` | On session timeout: revoke/clear cookie only, then call `onSessionTimeout`. The host must call `key.currentState?.checkQueueStatus()` when ready to re-check. |
  ///
  /// Keeping this in `WaitingRoomConfig` allows toggling via Firebase Remote
  /// Config without an app release.
  @JsonKey(name: 'autoReQueue')
  final bool? autoReQueue;

  /// Full message shown in the forceReQueue full-screen dialog.
  @JsonKey(name: 'reQueueDialogMessage')
  final String? reQueueDialogMessage;

  /// Button label in the forceReQueue dialog.
  @JsonKey(name: 'reQueueDialogBtnText')
  final String? reQueueDialogBtnText;

  /// BCP-47 locale tag used as the `Accept-Language` header for the queue
  /// page request (e.g. `"zh-TW"`, `"en-US"`).
  ///
  /// When `null`, the system locale is used by default.
  /// Can also be overridden per-widget via [CFWaitingRoomOverlayWidget.locale].
  @JsonKey(name: 'locale')
  final String? locale;

  // ── Default overlay text (drivable from Remote Config) ──────────────────

  /// Title shown in the default Phase 2 overlay.
  ///
  /// When set, this **overrides** the `<h1>` heading scraped from the CF page,
  /// making it useful for localisation or branding even in mock mode.
  ///
  /// Falls back to the scraped `<h1>`, then to the built-in English default.
  @JsonKey(name: 'waitingTitle')
  final String? waitingTitle;

  /// Body message shown below the ETA in the default Phase 2 overlay.
  ///
  /// Defaults to `'This page will refresh automatically.\nPlease keep the app open.'`
  @JsonKey(name: 'waitingRefreshMessage')
  final String? waitingRefreshMessage;

  /// Prefix prepended to the last-updated timestamp in the default Phase 2 overlay.
  ///
  /// Defaults to `'Last updated: '`
  @JsonKey(name: 'lastUpdatedPrefix')
  final String? lastUpdatedPrefix;

  WaitingRoomConfig({
    this.isEnable,
    this.queueUrl,
    this.queueKeyWord,
    this.passKeyWord,
    this.etaId,
    this.lastUpdatedId,
    this.sessionTimeoutMinutes,
    this.clearCookieOnStart,
    this.isEnterprise,
    this.autoReQueue,
    this.reQueueDialogMessage,
    this.reQueueDialogBtnText,
    this.locale,
    this.waitingTitle,
    this.waitingRefreshMessage,
    this.lastUpdatedPrefix,
  });

  factory WaitingRoomConfig.fromJson(Map<String, dynamic> json) =>
      _$WaitingRoomConfigFromJson(json);

  Map<String, dynamic> toJson() => _$WaitingRoomConfigToJson(this);

  bool get isEnabled => isEnable ?? false;

  /// Effective session timeout as a [Duration].
  ///
  /// Returns `null` if [sessionTimeoutMinutes] is not set or is zero.
  ///
  /// When [isEnterprise] is `false` (or unset) an automatic **60-second grace
  /// period** is added.  This compensates for CF automatically renewing the
  /// `__cfwaitingroom_*` cookie expiry on every WebView request, ensuring the
  /// cookie has genuinely expired before the widget clears it and re-evaluates.
  Duration? get effectiveSessionTimeout {
    if (sessionTimeoutMinutes == null || sessionTimeoutMinutes! <= 0)
      return null;
    Duration base = Duration(minutes: sessionTimeoutMinutes!);
    // Non-enterprise: CF auto-renews the cookie on each request, so add a
    // 60-second grace to guarantee it has truly expired when the timer fires.
    if (isEnterprise != true) base += const Duration(seconds: 60);
    return base;
  }

  List<String> get effectiveQueueKeyWords => (queueKeyWord?.isNotEmpty == true)
      ? queueKeyWord!
      : ['waiting', 'queue', '等候'];

  /// Returns configured [passKeyWord] list, or an empty list if unset.
  /// When empty, the widget treats any non-CF page as the real app page.
  List<String> get effectivePassKeyWords => passKeyWord ?? [];

  String get effectiveEtaId =>
      (etaId?.isNotEmpty == true) ? etaId! : 'waitTime';

  String get effectiveLastUpdatedId =>
      (lastUpdatedId?.isNotEmpty == true) ? lastUpdatedId! : 'last-updated';

  String get effectiveReQueueMessage =>
      (reQueueDialogMessage?.isNotEmpty == true)
          ? reQueueDialogMessage!
          : '恭喜您搶購成功！為確保公平，您的本次優先通行證已使用完畢。若想再次購買，請重新排隊。';

  String get effectiveReQueueBtnText =>
      (reQueueDialogBtnText?.isNotEmpty == true)
          ? reQueueDialogBtnText!
          : '確定並重新排隊';
}
