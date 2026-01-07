import 'package:flutter_test/flutter_test.dart';
import 'package:reddit_pixel/src/core/normalizer.dart';
import 'package:reddit_pixel/src/domain/user_data.dart';

void main() {
  group('RedditNormalizer', () {
    group('normalizeAndHashEmail', () {
      test('returns null for null input', () async {
        final result = await RedditNormalizer.normalizeAndHashEmail(null);
        expect(result, isNull);
      });

      test('returns null for empty input', () async {
        final result = await RedditNormalizer.normalizeAndHashEmail('');
        expect(result, isNull);
      });

      test('returns null for whitespace-only input', () async {
        final result = await RedditNormalizer.normalizeAndHashEmail('   ');
        expect(result, isNull);
      });

      test('normalizes email to lowercase before hashing', () async {
        final result1 =
            await RedditNormalizer.normalizeAndHashEmail('USER@EXAMPLE.COM');
        final result2 =
            await RedditNormalizer.normalizeAndHashEmail('user@example.com');

        expect(result1, equals(result2));
      });

      test('trims whitespace before hashing', () async {
        final result1 = await RedditNormalizer.normalizeAndHashEmail(
          '  user@example.com  ',
        );
        final result2 =
            await RedditNormalizer.normalizeAndHashEmail('user@example.com');

        expect(result1, equals(result2));
      });

      test('returns SHA-256 hash (64 hex characters)', () async {
        final result =
            await RedditNormalizer.normalizeAndHashEmail('user@example.com');

        expect(result, isNotNull);
        expect(result!.length, equals(64));
        expect(result, matches(RegExp(r'^[a-f0-9]{64}$')));
      });

      test('handles mixed case with whitespace', () async {
        final result1 = await RedditNormalizer.normalizeAndHashEmail(
          '  User@Example.COM  ',
        );
        final result2 =
            await RedditNormalizer.normalizeAndHashEmail('user@example.com');

        expect(result1, equals(result2));
      });
    });

    group('normalizeAndHashPhone', () {
      test('returns null for null input', () async {
        final result = await RedditNormalizer.normalizeAndHashPhone(null);
        expect(result, isNull);
      });

      test('returns null for input with no digits', () async {
        final result = await RedditNormalizer.normalizeAndHashPhone('abc');
        expect(result, isNull);
      });

      test('strips non-digit characters', () async {
        final result1 =
            await RedditNormalizer.normalizeAndHashPhone('+1 (415) 555-1234');
        final result2 =
            await RedditNormalizer.normalizeAndHashPhone('14155551234');

        expect(result1, equals(result2));
      });

      test('handles various phone formats', () async {
        final formats = [
          '+14155551234',
          '1-415-555-1234',
          '(415) 555-1234',
          '415.555.1234',
          '415 555 1234',
        ];

        final results =
            await Future.wait(formats.map(RedditNormalizer.normalizeAndHashPhone));

        // First format is E.164 with country code
        expect(results[0], equals(results[1]));
        // Without country code, different hash
        expect(results[2], isNot(equals(results[0])));
      });

      test('returns SHA-256 hash', () async {
        final result =
            await RedditNormalizer.normalizeAndHashPhone('14155551234');

        expect(result, isNotNull);
        expect(result!.length, equals(64));
      });
    });

    group('normalizeAndHashIdfa', () {
      test('returns null for null input', () async {
        final result = await RedditNormalizer.normalizeAndHashIdfa(null);
        expect(result, isNull);
      });

      test('returns null for empty input', () async {
        final result = await RedditNormalizer.normalizeAndHashIdfa('');
        expect(result, isNull);
      });

      test('normalizes IDFA to uppercase before hashing', () async {
        final result1 = await RedditNormalizer.normalizeAndHashIdfa(
          'abc123-def456-ghi789',
        );
        final result2 = await RedditNormalizer.normalizeAndHashIdfa(
          'ABC123-DEF456-GHI789',
        );

        expect(result1, equals(result2));
      });

      test('returns SHA-256 hash', () async {
        final result = await RedditNormalizer.normalizeAndHashIdfa(
          'ABC123-DEF456-GHI789',
        );

        expect(result, isNotNull);
        expect(result!.length, equals(64));
      });
    });

    group('normalizeAndHashAaid', () {
      test('returns null for null input', () async {
        final result = await RedditNormalizer.normalizeAndHashAaid(null);
        expect(result, isNull);
      });

      test('returns null for empty input', () async {
        final result = await RedditNormalizer.normalizeAndHashAaid('');
        expect(result, isNull);
      });

      test('normalizes AAID to lowercase before hashing', () async {
        final result1 = await RedditNormalizer.normalizeAndHashAaid(
          'ABC123-DEF456-GHI789',
        );
        final result2 = await RedditNormalizer.normalizeAndHashAaid(
          'abc123-def456-ghi789',
        );

        expect(result1, equals(result2));
      });

      test('returns SHA-256 hash', () async {
        final result = await RedditNormalizer.normalizeAndHashAaid(
          'abc123-def456-ghi789',
        );

        expect(result, isNotNull);
        expect(result!.length, equals(64));
      });
    });

    group('normalizeUserData', () {
      test('normalizes all PII fields', () async {
        final userData = RedditUserData(
          email: 'USER@EXAMPLE.COM',
          externalId: 'user-123',
          uuid: 'uuid-456',
          idfa: 'idfa-789',
          aaid: 'AAID-012',
          ipAddress: '192.168.1.1',
          userAgent: 'TestAgent/1.0',
          screenDimensions: '1920x1080',
          clickId: 'click-345',
        );

        final normalized = await RedditNormalizer.normalizeUserData(userData);

        // Email should be hashed (lowercase first)
        expect(normalized.emailHash, isNotNull);
        expect(normalized.emailHash!.length, equals(64));

        // External ID should be hashed
        expect(normalized.externalIdHash, isNotNull);
        expect(normalized.externalIdHash!.length, equals(64));

        // UUID should NOT be hashed
        expect(normalized.uuid, equals('uuid-456'));

        // IDFA should be hashed (uppercase first)
        expect(normalized.idfaHash, isNotNull);

        // AAID should be hashed (lowercase first)
        expect(normalized.aaidHash, isNotNull);

        // Non-PII fields preserved
        expect(normalized.ipAddress, equals('192.168.1.1'));
        expect(normalized.userAgent, equals('TestAgent/1.0'));
        expect(normalized.screenDimensions, equals('1920x1080'));
        expect(normalized.clickId, equals('click-345'));
      });

      test('handles null fields gracefully', () async {
        const userData = RedditUserData();

        final normalized = await RedditNormalizer.normalizeUserData(userData);

        expect(normalized.emailHash, isNull);
        expect(normalized.externalIdHash, isNull);
        expect(normalized.uuid, isNull);
        expect(normalized.idfaHash, isNull);
        expect(normalized.aaidHash, isNull);
        expect(normalized.ipAddress, isNull);
        expect(normalized.userAgent, isNull);
        expect(normalized.screenDimensions, isNull);
        expect(normalized.clickId, isNull);
      });
    });
  });

  group('NormalizedUserData', () {
    test('toJson produces correct format for Reddit API', () {
      const normalized = NormalizedUserData(
        emailHash: 'hash1',
        externalIdHash: 'hash2',
        uuid: 'uuid-123',
        idfaHash: 'hash3',
        aaidHash: 'hash4',
        ipAddress: '192.168.1.1',
        userAgent: 'TestAgent/1.0',
        screenDimensions: '1920x1080',
        clickId: 'click-123',
      );

      final json = normalized.toJson();

      expect(json['em'], equals('hash1'));
      expect(json['external_id'], equals('hash2'));
      expect(json['uuid'], equals('uuid-123'));
      expect(json['idfa'], equals('hash3'));
      expect(json['aaid'], equals('hash4'));
      expect(json['client_ip_address'], equals('192.168.1.1'));
      expect(json['client_user_agent'], equals('TestAgent/1.0'));
      expect(json['screen_dimensions'], equals('1920x1080'));
      expect(json['click_id'], equals('click-123'));
    });

    test('toJson omits null fields', () {
      const normalized = NormalizedUserData(
        emailHash: 'hash1',
      );

      final json = normalized.toJson();

      expect(json.containsKey('em'), isTrue);
      expect(json.containsKey('external_id'), isFalse);
      expect(json.containsKey('uuid'), isFalse);
      expect(json.containsKey('idfa'), isFalse);
      expect(json.containsKey('aaid'), isFalse);
    });

    test('toString redacts sensitive information', () {
      const normalized = NormalizedUserData(
        emailHash: 'abcdefghijklmnop',
        ipAddress: '192.168.1.1',
      );

      final str = normalized.toString();

      expect(str, contains('emailHash: abcdefgh...'));
      expect(str, contains('ipAddress: [REDACTED]'));
    });
  });
}
