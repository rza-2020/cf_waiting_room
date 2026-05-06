import 'package:cf_waiting_room/cf_waiting_room.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WaitingRoomConfig', () {
    // ── fromJson / toJson roundtrip ──────────────────────────────────────

    test('fromJson roundtrip — core fields', () {
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

    test('fromJson roundtrip — locale field', () {
      final config = WaitingRoomConfig.fromJson({'locale': 'zh-TW'});
      expect(config.locale, 'zh-TW');
    });

    test('fromJson roundtrip — overlay text fields', () {
      final config = WaitingRoomConfig.fromJson({
        'waitingTitle': 'You are queuing',
        'waitingRefreshMessage': 'Page refreshes automatically.',
        'lastUpdatedPrefix': 'Updated: ',
      });
      expect(config.waitingTitle, 'You are queuing');
      expect(config.waitingRefreshMessage, 'Page refreshes automatically.');
      expect(config.lastUpdatedPrefix, 'Updated: ');
    });

    test('toJson includes all fields', () {
      final config = WaitingRoomConfig(
        isEnable: true,
        queueUrl: 'https://example.com/',
        locale: 'en-US',
        sessionTimeoutMinutes: 10,
        waitingTitle: 'Queuing…',
        waitingRefreshMessage: 'Auto-refreshing.',
        lastUpdatedPrefix: 'At: ',
      );
      final json = config.toJson();
      expect(json['isEnable'], isTrue);
      expect(json['queueUrl'], 'https://example.com/');
      expect(json['locale'], 'en-US');
      expect(json['sessionTimeoutMinutes'], 10);
      expect(json['waitingTitle'], 'Queuing…');
      expect(json['waitingRefreshMessage'], 'Auto-refreshing.');
      expect(json['lastUpdatedPrefix'], 'At: ');
    });

    // ── effectiveSessionTimeout ──────────────────────────────────────────

    group('effectiveSessionTimeout', () {
      test('returns null when sessionTimeoutMinutes is not set', () {
        expect(WaitingRoomConfig().effectiveSessionTimeout, isNull);
      });

      test('returns null when sessionTimeoutMinutes is 0', () {
        expect(
          WaitingRoomConfig(sessionTimeoutMinutes: 0).effectiveSessionTimeout,
          isNull,
        );
      });

      test('non-enterprise: adds 60s grace to configured minutes', () {
        final config = WaitingRoomConfig(
          sessionTimeoutMinutes: 5,
          isEnterprise: false,
        );
        expect(
          config.effectiveSessionTimeout,
          const Duration(minutes: 5, seconds: 60),
        );
      });

      test('non-enterprise (isEnterprise unset): adds 60s grace', () {
        final config = WaitingRoomConfig(sessionTimeoutMinutes: 10);
        expect(
          config.effectiveSessionTimeout,
          const Duration(minutes: 10, seconds: 60),
        );
      });

      test('enterprise: no grace period added', () {
        final config = WaitingRoomConfig(
          sessionTimeoutMinutes: 5,
          isEnterprise: true,
        );
        expect(config.effectiveSessionTimeout, const Duration(minutes: 5));
      });
    });

    // ── effective getters — null defaults ────────────────────────────────

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

      test('overlay text fields are null by default', () {
        expect(empty.waitingTitle, isNull);
        expect(empty.waitingRefreshMessage, isNull);
        expect(empty.lastUpdatedPrefix, isNull);
        expect(empty.locale, isNull);
      });

      test('effectiveSessionTimeout is null by default', () {
        expect(empty.effectiveSessionTimeout, isNull);
      });
    });

    // ── effective getters — provided values ──────────────────────────────

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

    // ── isEnabled ────────────────────────────────────────────────────────

    test('isEnabled defaults to false when isEnable is null', () {
      expect(WaitingRoomConfig().isEnabled, isFalse);
    });

    test('isEnabled is true when isEnable is true', () {
      expect(WaitingRoomConfig(isEnable: true).isEnabled, isTrue);
    });
  });

  // ── MockConfig ──────────────────────────────────────────────────────────

  group('MockConfig', () {
    test('default values', () {
      const mc = MockConfig();
      expect(mc.isEnable, isFalse);
      expect(mc.waitDuration, const Duration(seconds: 30));
    });

    test('custom values', () {
      const mc = MockConfig(
        isEnable: true,
        waitDuration: Duration(seconds: 10),
      );
      expect(mc.isEnable, isTrue);
      expect(mc.waitDuration, const Duration(seconds: 10));
    });

    test('fromJson roundtrip', () {
      final json = {'isEnable': true, 'waitSeconds': 20};
      final mc = MockConfig.fromJson(json);
      expect(mc.isEnable, isTrue);
      expect(mc.waitDuration, const Duration(seconds: 20));
    });

    test('toJson roundtrip', () {
      const mc =
          MockConfig(isEnable: true, waitDuration: Duration(seconds: 15));
      final json = mc.toJson();
      expect(json['isEnable'], isTrue);
      expect(json['waitSeconds'], 15);
    });

    test('fromJson defaults when fields missing', () {
      final mc = MockConfig.fromJson({});
      expect(mc.isEnable, isFalse);
      expect(mc.waitDuration, const Duration(seconds: 30));
    });
  });

  // ── QueueWaitingInfo ────────────────────────────────────────────────────

  group('QueueWaitingInfo', () {
    test('const constructor — all null by default', () {
      const info = QueueWaitingInfo();
      expect(info.title, isNull);
      expect(info.eta, isNull);
      expect(info.lastUpdated, isNull);
    });

    test('holds provided values', () {
      const info = QueueWaitingInfo(
        title: 'You are in the queue',
        eta: '5 minutes',
        lastUpdated: '12:00',
      );
      expect(info.title, 'You are in the queue');
      expect(info.eta, '5 minutes');
      expect(info.lastUpdated, '12:00');
    });
  });
}
