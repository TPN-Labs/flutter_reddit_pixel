import 'package:flutter_test/flutter_test.dart';
import 'package:reddit_pixel/src/client/direct_transport.dart';
import 'package:reddit_pixel/src/client/transport_strategy.dart';

void main() {
  group('DirectTransport', () {
    group('constructor', () {
      test('creates instance with required token', () {
        final transport = DirectTransport(token: 'test-token');

        expect(transport, isA<RedditTransport>());
        expect(transport.token, equals('test-token'));

        transport.dispose();
      });

      test('accepts custom connect timeout', () {
        final transport = DirectTransport(
          token: 'test-token',
          connectTimeout: const Duration(seconds: 10),
        );

        // Verify it doesn't throw
        expect(transport, isA<DirectTransport>());

        transport.dispose();
      });

      test('accepts custom receive timeout', () {
        final transport = DirectTransport(
          token: 'test-token',
          receiveTimeout: const Duration(seconds: 15),
        );

        expect(transport, isA<DirectTransport>());

        transport.dispose();
      });
    });

    group('token property', () {
      test('returns the configured token', () {
        final transport = DirectTransport(token: 'my-secret-token');

        expect(transport.token, equals('my-secret-token'));

        transport.dispose();
      });
    });

    group('dispose', () {
      test('can be called multiple times without error', () {
        final transport = DirectTransport(token: 'test-token');

        expect(transport.dispose, returnsNormally);
        expect(transport.dispose, returnsNormally);
      });
    });

    group('send', () {
      test('returns TransportFailure on network error', () async {
        final transport = DirectTransport(
          token: 'test-token',
          // Use very short timeouts to force failure
          connectTimeout: const Duration(milliseconds: 1),
        );

        final result = await transport.send(
          'pixel123',
          {'events': <Map<String, dynamic>>[]},
        );

        expect(result, isA<TransportFailure>());

        transport.dispose();
      });

      test('handles empty events payload', () async {
        final transport = DirectTransport(
          token: 'test-token',
          connectTimeout: const Duration(milliseconds: 1),
        );

        final result = await transport.send(
          'pixel123',
          {'events': <Map<String, dynamic>>[]},
        );

        // Should fail due to connection, but not throw
        expect(result, isA<TransportFailure>());

        transport.dispose();
      });

      test('handles null events in payload', () async {
        final transport = DirectTransport(
          token: 'test-token',
          connectTimeout: const Duration(milliseconds: 1),
        );

        final result = await transport.send(
          'pixel123',
          <String, dynamic>{},
        );

        expect(result, isA<TransportFailure>());

        transport.dispose();
      });
    });
  });

  group('DirectTransport error extraction', () {
    test('TransportFailure contains message', () async {
      final transport = DirectTransport(
        token: 'test-token',
        connectTimeout: const Duration(milliseconds: 1),
      );

      final result = await transport.send(
        'pixel123',
        {'events': <Map<String, dynamic>>[]},
      );

      expect(result, isA<TransportFailure>());
      final failure = result as TransportFailure;
      expect(failure.message, isNotEmpty);

      transport.dispose();
    });
  });
}
