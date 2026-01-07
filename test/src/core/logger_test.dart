import 'package:flutter_test/flutter_test.dart';
import 'package:reddit_pixel/src/core/logger.dart';

void main() {
  group('LogLevel', () {
    test('has all expected values', () {
      expect(LogLevel.values, hasLength(4));
      expect(LogLevel.values, contains(LogLevel.debug));
      expect(LogLevel.values, contains(LogLevel.info));
      expect(LogLevel.values, contains(LogLevel.warning));
      expect(LogLevel.values, contains(LogLevel.error));
    });
  });

  group('RedditPixelLogger', () {
    setUp(() {
      // Reset debug mode before each test
      RedditPixelLogger.setDebugMode(enabled: false);
    });

    tearDown(() {
      // Clean up after tests
      RedditPixelLogger.setDebugMode(enabled: false);
    });

    group('setDebugMode', () {
      test('enables debug mode', () {
        RedditPixelLogger.setDebugMode(enabled: true);
        expect(RedditPixelLogger.isDebugMode, isTrue);
      });

      test('disables debug mode', () {
        RedditPixelLogger.setDebugMode(enabled: true);
        RedditPixelLogger.setDebugMode(enabled: false);
        expect(RedditPixelLogger.isDebugMode, isFalse);
      });
    });

    group('isDebugMode', () {
      test('returns false by default', () {
        expect(RedditPixelLogger.isDebugMode, isFalse);
      });

      test('reflects current debug mode state', () {
        expect(RedditPixelLogger.isDebugMode, isFalse);

        RedditPixelLogger.setDebugMode(enabled: true);
        expect(RedditPixelLogger.isDebugMode, isTrue);

        RedditPixelLogger.setDebugMode(enabled: false);
        expect(RedditPixelLogger.isDebugMode, isFalse);
      });
    });

    group('debug', () {
      test('does not throw when called with debug mode off', () {
        RedditPixelLogger.setDebugMode(enabled: false);
        expect(() => RedditPixelLogger.debug('test message'), returnsNormally);
      });

      test('does not throw when called with debug mode on', () {
        RedditPixelLogger.setDebugMode(enabled: true);
        expect(() => RedditPixelLogger.debug('test message'), returnsNormally);
      });
    });

    group('info', () {
      test('does not throw when called with debug mode off', () {
        RedditPixelLogger.setDebugMode(enabled: false);
        expect(() => RedditPixelLogger.info('test message'), returnsNormally);
      });

      test('does not throw when called with debug mode on', () {
        RedditPixelLogger.setDebugMode(enabled: true);
        expect(() => RedditPixelLogger.info('test message'), returnsNormally);
      });
    });

    group('warning', () {
      test('does not throw when called with debug mode off', () {
        RedditPixelLogger.setDebugMode(enabled: false);
        expect(
          () => RedditPixelLogger.warning('test warning'),
          returnsNormally,
        );
      });

      test('does not throw when called with debug mode on', () {
        RedditPixelLogger.setDebugMode(enabled: true);
        expect(
          () => RedditPixelLogger.warning('test warning'),
          returnsNormally,
        );
      });
    });

    group('error', () {
      test('does not throw when called with message only', () {
        expect(
          () => RedditPixelLogger.error('test error'),
          returnsNormally,
        );
      });

      test('does not throw when called with error object', () {
        expect(
          () => RedditPixelLogger.error(
            'test error',
            error: Exception('Test exception'),
          ),
          returnsNormally,
        );
      });

      test('does not throw when called with stack trace', () {
        expect(
          () => RedditPixelLogger.error(
            'test error',
            error: Exception('Test exception'),
            stackTrace: StackTrace.current,
          ),
          returnsNormally,
        );
      });

      test('works with debug mode on or off', () {
        RedditPixelLogger.setDebugMode(enabled: false);
        expect(() => RedditPixelLogger.error('error 1'), returnsNormally);

        RedditPixelLogger.setDebugMode(enabled: true);
        expect(() => RedditPixelLogger.error('error 2'), returnsNormally);
      });
    });
  });
}
