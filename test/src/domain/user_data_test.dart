import 'package:flutter_test/flutter_test.dart';
import 'package:reddit_pixel/src/domain/user_data.dart';

void main() {
  group('RedditUserData', () {
    test('creates with all fields', () {
      final userData = RedditUserData(
        email: 'test@example.com',
        externalId: 'ext-123',
        uuid: 'uuid-456',
        idfa: 'idfa-789',
        aaid: 'aaid-012',
        ipAddress: '192.168.1.1',
        userAgent: 'TestAgent/1.0',
        screenDimensions: '1920x1080',
        clickId: 'click-345',
      );

      expect(userData.email, equals('test@example.com'));
      expect(userData.externalId, equals('ext-123'));
      expect(userData.uuid, equals('uuid-456'));
      expect(userData.idfa, equals('idfa-789'));
      expect(userData.aaid, equals('aaid-012'));
      expect(userData.ipAddress, equals('192.168.1.1'));
      expect(userData.userAgent, equals('TestAgent/1.0'));
      expect(userData.screenDimensions, equals('1920x1080'));
      expect(userData.clickId, equals('click-345'));
    });

    test('creates with no fields', () {
      const userData = RedditUserData();

      expect(userData.email, isNull);
      expect(userData.externalId, isNull);
      expect(userData.uuid, isNull);
      expect(userData.idfa, isNull);
      expect(userData.aaid, isNull);
      expect(userData.ipAddress, isNull);
      expect(userData.userAgent, isNull);
      expect(userData.screenDimensions, isNull);
      expect(userData.clickId, isNull);
    });

    group('copyWith', () {
      test('copies all fields', () {
        final original = RedditUserData(
          email: 'original@example.com',
          externalId: 'orig-123',
        );

        final copied = original.copyWith(
          email: 'new@example.com',
        );

        expect(copied.email, equals('new@example.com'));
        expect(copied.externalId, equals('orig-123'));
      });

      test('preserves null fields when not specified', () {
        final original = RedditUserData(email: 'test@example.com');

        final copied = original.copyWith();

        expect(copied.email, equals('test@example.com'));
        expect(copied.externalId, isNull);
      });
    });

    group('toJson', () {
      test('includes all non-null fields', () {
        final userData = RedditUserData(
          email: 'test@example.com',
          externalId: 'ext-123',
          ipAddress: '192.168.1.1',
        );

        final json = userData.toJson();

        expect(json['email'], equals('test@example.com'));
        expect(json['external_id'], equals('ext-123'));
        expect(json['ip_address'], equals('192.168.1.1'));
      });

      test('excludes null fields', () {
        final userData = RedditUserData(
          email: 'test@example.com',
        );

        final json = userData.toJson();

        expect(json.containsKey('email'), isTrue);
        expect(json.containsKey('external_id'), isFalse);
        expect(json.containsKey('uuid'), isFalse);
      });

      test('uses snake_case keys', () {
        final userData = RedditUserData(
          externalId: 'ext-123',
          ipAddress: '192.168.1.1',
          userAgent: 'TestAgent',
          screenDimensions: '1920x1080',
          clickId: 'click-123',
        );

        final json = userData.toJson();

        expect(json.containsKey('external_id'), isTrue);
        expect(json.containsKey('ip_address'), isTrue);
        expect(json.containsKey('user_agent'), isTrue);
        expect(json.containsKey('screen_dimensions'), isTrue);
        expect(json.containsKey('click_id'), isTrue);
      });
    });

    group('fromJson', () {
      test('parses all fields', () {
        final json = {
          'email': 'test@example.com',
          'external_id': 'ext-123',
          'uuid': 'uuid-456',
          'idfa': 'idfa-789',
          'aaid': 'aaid-012',
          'ip_address': '192.168.1.1',
          'user_agent': 'TestAgent/1.0',
          'screen_dimensions': '1920x1080',
          'click_id': 'click-345',
        };

        final userData = RedditUserData.fromJson(json);

        expect(userData.email, equals('test@example.com'));
        expect(userData.externalId, equals('ext-123'));
        expect(userData.uuid, equals('uuid-456'));
        expect(userData.idfa, equals('idfa-789'));
        expect(userData.aaid, equals('aaid-012'));
        expect(userData.ipAddress, equals('192.168.1.1'));
        expect(userData.userAgent, equals('TestAgent/1.0'));
        expect(userData.screenDimensions, equals('1920x1080'));
        expect(userData.clickId, equals('click-345'));
      });

      test('handles missing fields', () {
        final json = <String, dynamic>{
          'email': 'test@example.com',
        };

        final userData = RedditUserData.fromJson(json);

        expect(userData.email, equals('test@example.com'));
        expect(userData.externalId, isNull);
      });
    });

    group('equality', () {
      test('equal instances are equal', () {
        final a = RedditUserData(
          email: 'test@example.com',
          externalId: 'ext-123',
        );
        final b = RedditUserData(
          email: 'test@example.com',
          externalId: 'ext-123',
        );

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('different instances are not equal', () {
        final a = RedditUserData(
          email: 'test@example.com',
        );
        final b = RedditUserData(
          email: 'other@example.com',
        );

        expect(a, isNot(equals(b)));
      });
    });

    group('toString', () {
      test('redacts sensitive fields', () {
        final userData = RedditUserData(
          email: 'sensitive@example.com',
          externalId: 'secret-id',
          idfa: 'secret-idfa',
          aaid: 'secret-aaid',
          ipAddress: '192.168.1.1',
        );

        final str = userData.toString();

        expect(str, contains('email: [REDACTED]'));
        expect(str, contains('externalId: [REDACTED]'));
        expect(str, contains('idfa: [REDACTED]'));
        expect(str, contains('aaid: [REDACTED]'));
        expect(str, contains('ipAddress: [REDACTED]'));
        expect(str, isNot(contains('sensitive@example.com')));
        expect(str, isNot(contains('secret-id')));
        expect(str, isNot(contains('192.168.1.1')));
      });

      test('shows non-sensitive fields', () {
        final userData = RedditUserData(
          screenDimensions: '1920x1080',
        );

        final str = userData.toString();

        expect(str, contains('screenDimensions: 1920x1080'));
      });

      test('truncates long user agent', () {
        final userData = RedditUserData(
          userAgent:
              'This is a very long user agent string that should be truncated',
        );

        final str = userData.toString();

        expect(str, contains('userAgent: This is a very long ...'));
      });

      test('omits null fields', () {
        final userData = RedditUserData(
          email: 'test@example.com',
        );

        final str = userData.toString();

        expect(str, contains('email: [REDACTED]'));
        expect(str, isNot(contains('externalId')));
        expect(str, isNot(contains('uuid')));
      });
    });
  });
}
