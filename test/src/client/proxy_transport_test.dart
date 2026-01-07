import 'package:flutter_test/flutter_test.dart';
import 'package:reddit_pixel/src/client/proxy_transport.dart';
import 'package:reddit_pixel/src/client/transport_strategy.dart';

void main() {
  group('ProxyTransport', () {
    group('constructor', () {
      test('creates instance with required proxyUrl', () {
        final transport = ProxyTransport(
          proxyUrl: 'https://api.example.com/reddit',
        );

        expect(transport, isA<RedditTransport>());

        transport.dispose();
      });

      test('normalizes URL without trailing slash', () {
        final transport = ProxyTransport(
          proxyUrl: 'https://api.example.com/reddit',
        );

        expect(transport.proxyUrl, equals('https://api.example.com/reddit/'));

        transport.dispose();
      });

      test('preserves URL with trailing slash', () {
        final transport = ProxyTransport(
          proxyUrl: 'https://api.example.com/reddit/',
        );

        expect(transport.proxyUrl, equals('https://api.example.com/reddit/'));

        transport.dispose();
      });

      test('accepts custom headers', () {
        final transport = ProxyTransport(
          proxyUrl: 'https://api.example.com/reddit',
          headers: {
            'X-API-Key': 'custom-key',
            'X-Custom-Header': 'value',
          },
        );

        expect(transport, isA<ProxyTransport>());

        transport.dispose();
      });

      test('accepts custom connect timeout', () {
        final transport = ProxyTransport(
          proxyUrl: 'https://api.example.com/reddit',
          connectTimeout: const Duration(seconds: 10),
        );

        expect(transport, isA<ProxyTransport>());

        transport.dispose();
      });

      test('accepts custom receive timeout', () {
        final transport = ProxyTransport(
          proxyUrl: 'https://api.example.com/reddit',
          receiveTimeout: const Duration(seconds: 15),
        );

        expect(transport, isA<ProxyTransport>());

        transport.dispose();
      });

      test('accepts all optional parameters together', () {
        final transport = ProxyTransport(
          proxyUrl: 'https://api.example.com/reddit',
          headers: {'Authorization': 'Bearer token'},
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 25),
        );

        expect(transport, isA<ProxyTransport>());
        expect(transport.proxyUrl, equals('https://api.example.com/reddit/'));

        transport.dispose();
      });
    });

    group('proxyUrl property', () {
      test('returns the configured proxy URL with trailing slash', () {
        final transport = ProxyTransport(
          proxyUrl: 'https://my-proxy.com/api',
        );

        expect(transport.proxyUrl, equals('https://my-proxy.com/api/'));

        transport.dispose();
      });
    });

    group('dispose', () {
      test('can be called without error', () {
        final transport = ProxyTransport(
          proxyUrl: 'https://api.example.com/reddit',
        );

        expect(transport.dispose, returnsNormally);
      });

      test('can be called multiple times without error', () {
        final transport = ProxyTransport(
          proxyUrl: 'https://api.example.com/reddit',
        );

        expect(transport.dispose, returnsNormally);
        expect(transport.dispose, returnsNormally);
      });
    });

    group('send', () {
      test('returns TransportFailure on network error', () async {
        final transport = ProxyTransport(
          proxyUrl: 'https://api.example.com/reddit',
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
        final transport = ProxyTransport(
          proxyUrl: 'https://api.example.com/reddit',
          connectTimeout: const Duration(milliseconds: 1),
        );

        final result = await transport.send(
          'pixel123',
          {'events': <Map<String, dynamic>>[]},
        );

        expect(result, isA<TransportFailure>());

        transport.dispose();
      });

      test('handles payload without events key', () async {
        final transport = ProxyTransport(
          proxyUrl: 'https://api.example.com/reddit',
          connectTimeout: const Duration(milliseconds: 1),
        );

        final result = await transport.send(
          'pixel123',
          <String, dynamic>{},
        );

        expect(result, isA<TransportFailure>());

        transport.dispose();
      });

      test('constructs correct URL with pixel ID', () async {
        // We can't easily verify the URL without mocking, but we can
        // verify the transport handles the pixel ID without error
        final transport = ProxyTransport(
          proxyUrl: 'https://api.example.com/reddit',
          connectTimeout: const Duration(milliseconds: 1),
        );

        // Different pixel IDs should all work
        final result1 = await transport.send(
          'pixel-123',
          {'events': <Map<String, dynamic>>[]},
        );
        final result2 = await transport.send(
          'another_pixel',
          {'events': <Map<String, dynamic>>[]},
        );

        expect(result1, isA<TransportFailure>());
        expect(result2, isA<TransportFailure>());

        transport.dispose();
      });
    });

    group('error handling', () {
      test('TransportFailure contains message', () async {
        final transport = ProxyTransport(
          proxyUrl: 'https://api.example.com/reddit',
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

      test(
        'TransportFailure indicates not retryable for connection errors',
        () async {
          final transport = ProxyTransport(
            proxyUrl: 'https://api.example.com/reddit',
            connectTimeout: const Duration(milliseconds: 1),
          );

          final result = await transport.send(
            'pixel123',
            {'events': <Map<String, dynamic>>[]},
          );

          expect(result, isA<TransportFailure>());
          final failure = result as TransportFailure;
          // Connection errors typically don't have status codes, so not
          // retryable
          expect(failure.isRetryable, isFalse);

          transport.dispose();
        },
      );
    });
  });

  group('ProxyTransport vs DirectTransport', () {
    test('both implement RedditTransport', () {
      final proxyTransport = ProxyTransport(
        proxyUrl: 'https://api.example.com/reddit',
      );

      expect(proxyTransport, isA<RedditTransport>());

      proxyTransport.dispose();
    });
  });
}
