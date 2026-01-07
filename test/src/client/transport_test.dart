import 'package:flutter_test/flutter_test.dart';
import 'package:reddit_pixel/src/client/transport_strategy.dart';

void main() {
  group('TransportResult', () {
    group('TransportSuccess', () {
      test('creates with default values', () {
        const result = TransportSuccess();

        expect(result.statusCode, equals(200));
        expect(result.responseBody, isNull);
      });

      test('creates with custom values', () {
        const result = TransportSuccess(
          statusCode: 201,
          responseBody: '{"success": true}',
        );

        expect(result.statusCode, equals(201));
        expect(result.responseBody, equals('{"success": true}'));
      });

      test('toString includes status code', () {
        const result = TransportSuccess();

        expect(result.toString(), contains('200'));
      });
    });

    group('TransportFailure', () {
      test('creates with required message', () {
        const result = TransportFailure(message: 'Connection failed');

        expect(result.message, equals('Connection failed'));
        expect(result.statusCode, isNull);
        expect(result.error, isNull);
        expect(result.isRetryable, isFalse);
      });

      test('creates with all fields', () {
        final error = Exception('Network error');
        final result = TransportFailure(
          message: 'Server error',
          statusCode: 500,
          error: error,
          isRetryable: true,
        );

        expect(result.message, equals('Server error'));
        expect(result.statusCode, equals(500));
        expect(result.error, equals(error));
        expect(result.isRetryable, isTrue);
      });

      test('toString includes relevant info', () {
        const result = TransportFailure(
          message: 'Error occurred',
          statusCode: 503,
          isRetryable: true,
        );

        final str = result.toString();

        expect(str, contains('Error occurred'));
        expect(str, contains('503'));
        expect(str, contains('true'));
      });
    });

    group('pattern matching', () {
      test('works with switch expression', () {
        const results = <TransportResult>[
          TransportSuccess(),
          TransportFailure(message: 'Failed', isRetryable: true),
          TransportFailure(message: 'Client error', statusCode: 400),
        ];

        final messages = results.map((result) {
          return switch (result) {
            TransportSuccess(:final statusCode) => 'Success: $statusCode',
            TransportFailure(:final message, :final isRetryable) =>
              'Failure: $message (retryable: $isRetryable)',
          };
        }).toList();

        expect(messages[0], equals('Success: 200'));
        expect(messages[1], equals('Failure: Failed (retryable: true)'));
        expect(messages[2], equals('Failure: Client error (retryable: false)'));
      });

      test('destructures success', () {
        const TransportResult result = TransportSuccess(
          statusCode: 201,
          responseBody: 'Created',
        );

        final (code, body) = switch (result) {
          TransportSuccess(:final statusCode, :final responseBody) => (
            statusCode,
            responseBody,
          ),
          TransportFailure() => (-1, null),
        };

        expect(code, equals(201));
        expect(body, equals('Created'));
      });

      test('destructures failure', () {
        const TransportResult result = TransportFailure(
          message: 'Timeout',
          statusCode: 504,
          isRetryable: true,
        );

        final (msg, retry) = switch (result) {
          TransportSuccess() => ('ok', false),
          TransportFailure(:final message, :final isRetryable) => (
            message,
            isRetryable,
          ),
        };

        expect(msg, equals('Timeout'));
        expect(retry, isTrue);
      });
    });
  });
}
