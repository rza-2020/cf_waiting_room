// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'waiting_room_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WaitingRoomConfig _$WaitingRoomConfigFromJson(Map<String, dynamic> json) =>
    WaitingRoomConfig(
      isEnable: json['isEnable'] as bool?,
      queueUrl: json['queueUrl'] as String?,
      queueKeyWord: (json['queueKeyWord'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      passKeyWord: (json['passKeyWord'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      etaId: json['etaId'] as String?,
      lastUpdatedId: json['lastUpdatedId'] as String?,
      sessionTimeoutMinutes: (json['sessionTimeoutMinutes'] as num?)?.toInt(),
      clearCookieOnStart: json['clearCookieOnStart'] as bool?,
      isEnterprise: json['isEnterprise'] as bool?,
      reQueueDialogMessage: json['reQueueDialogMessage'] as String?,
      reQueueDialogBtnText: json['reQueueDialogBtnText'] as String?,
      locale: json['locale'] as String?,
      waitingTitle: json['waitingTitle'] as String?,
      waitingRefreshMessage: json['waitingRefreshMessage'] as String?,
      lastUpdatedPrefix: json['lastUpdatedPrefix'] as String?,
    );

Map<String, dynamic> _$WaitingRoomConfigToJson(WaitingRoomConfig instance) =>
    <String, dynamic>{
      'isEnable': instance.isEnable,
      'queueUrl': instance.queueUrl,
      'queueKeyWord': instance.queueKeyWord,
      'passKeyWord': instance.passKeyWord,
      'etaId': instance.etaId,
      'lastUpdatedId': instance.lastUpdatedId,
      'sessionTimeoutMinutes': instance.sessionTimeoutMinutes,
      'clearCookieOnStart': instance.clearCookieOnStart,
      'isEnterprise': instance.isEnterprise,
      'reQueueDialogMessage': instance.reQueueDialogMessage,
      'reQueueDialogBtnText': instance.reQueueDialogBtnText,
      'locale': instance.locale,
      'waitingTitle': instance.waitingTitle,
      'waitingRefreshMessage': instance.waitingRefreshMessage,
      'lastUpdatedPrefix': instance.lastUpdatedPrefix,
    };
