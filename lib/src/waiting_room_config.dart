import 'package:json_annotation/json_annotation.dart';

part 'waiting_room_config.g.dart';

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

  /// Minutes after queue is confirmed before [onSessionTimeout] fires.
  @JsonKey(name: 'sessionTimeoutMinutes')
  final int? sessionTimeoutMinutes;

  /// 訪特權 Off → false: skip clearing cookies/cache on widget init.
  /// Defaults to true (always clear).
  @JsonKey(name: 'clearCookieOnStart')
  final bool? clearCookieOnStart;

  /// Full message shown in the forceReQueue full-screen dialog.
  @JsonKey(name: 'reQueueDialogMessage')
  final String? reQueueDialogMessage;

  /// Button label in the forceReQueue dialog.
  @JsonKey(name: 'reQueueDialogBtnText')
  final String? reQueueDialogBtnText;

  WaitingRoomConfig({
    this.isEnable,
    this.queueUrl,
    this.queueKeyWord,
    this.passKeyWord,
    this.etaId,
    this.lastUpdatedId,
    this.sessionTimeoutMinutes,
    this.clearCookieOnStart,
    this.reQueueDialogMessage,
    this.reQueueDialogBtnText,
  });

  factory WaitingRoomConfig.fromJson(Map<String, dynamic> json) =>
      _$WaitingRoomConfigFromJson(json);

  Map<String, dynamic> toJson() => _$WaitingRoomConfigToJson(this);

  bool get isEnabled => isEnable ?? false;

  List<String> get effectiveQueueKeyWords =>
      (queueKeyWord?.isNotEmpty == true)
          ? queueKeyWord!
          : ['waiting', 'queue', '等候'];

  /// Returns configured [passKeyWord] list, or an empty list if unset.
  /// When empty, the widget treats any non-CF page as the real app page.
  List<String> get effectivePassKeyWords => passKeyWord ?? [];

  String get effectiveEtaId => (etaId?.isNotEmpty == true) ? etaId! : 'waitTime';

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
