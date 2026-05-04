import 'package:cf_waiting_room/cf_waiting_room.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WaitingRoomConfig', () {
    test('fromJson roundtrip', () {
      final json = {
        'isEnable': true,
        'queueUrl': 'https://example.com/',
        'queueKeyWord': ['waiting', 'queue'],
        'passKeyWord': ['myapp'],
        'etaId': 'eta',
        'lastUpdatedId': 'updated',
        'sessionTimeoutMinutes': 30,
        'clearCookieOnStart': false,
        'reQueueDialogMessage': 'Thanks!',
        'reQueueDialogBtnText': 'OK',
      };
      final config = WaitingRoomConfig.fromJson(json);
      expect(config.isEnabled, isTrue);
      expect(config.queueUrl, 'https://example.com/');
      expect(config.queueKeyWord, ['waiting', 'queue']);
      expect(config.passKeyWord, ['myapp']);
      expect(config.etaId, 'eta');
      expect(config.lastUpdatedId, 'updated');
      expect(config.sessionTimeoutMinutes, 30);
      expect(config.clearCookieOnStart, isFalse);
      expect(config.reQueueDialogMessage, 'Thanks!');
      expect(config.reQueueDialogBtnText, 'OK');
    });

    group('effective getters use defaults when fields are null', () {
      final empty = WaitingRoomConfig();

      test('effectiveQueueKeyWords', () {
        expect(empty.effectiveQueueKeyWords, ['waiting', 'queue', '等候']);
      });

      test('effectivePassKeyWords', () {
        expect(empty.effectivePassKeyWords, isEmpty);
      });

      test('effectiveEtaId', () {
        expect(empty.effectiveEtaId, 'waitTime');
      });

      test('effectiveLastUpdatedId', () {
        expect(empty.effectiveLastUpdatedId, 'last-updated');
      });

      test('effectiveReQueueMessage non-empty', () {
        expect(empty.effectiveReQueueMessage, isNotEmpty);
      });

      test('effectiveReQueueBtnText non-empty', () {
        expect(empty.effectiveReQueueBtnText, isNotEmpty);
      });
    });

    test('effective getters use provided values when non-empty', () {
      final config = WaitingRoomConfig(
        queueKeyWord: ['排隊'],
        passKeyWord: ['home'],
        etaId: 'my-eta',
        lastUpdatedId: 'my-updated',
        reQueueDialogMessage: 'Custom msg',
        reQueueDialogBtnText: 'Go',
      );
      expect(config.effectiveQueueKeyWords, ['排隊']);
      expect(config.effectivePassKeyWords, ['home']);
      expect(config.effectiveEtaId, 'my-eta');
      expect(config.effectiveLastUpdatedId, 'my-updated');
      expect(config.effectiveReQueueMessage, 'Custom msg');
      expect(config.effectiveReQueueBtnText, 'Go');
    });

    test('isEnabled defaults to false when isEnable is null', () {
      expect(WaitingRoomConfig().isEnabled, isFalse);
    });
  });
}
