import 'package:flutter_test/flutter_test.dart';
import 'package:reddit_pixel/src/platform/identity_provider.dart';

void main() {
  group('RedditIdentityProvider', () {
    test('is an abstract class', () {
      // Verify that RedditIdentityProvider defines the expected interface
      // by checking that NullIdentityProvider implements it
      const provider = NullIdentityProvider();
      expect(provider, isA<RedditIdentityProvider>());
    });
  });

  group('NullIdentityProvider', () {
    late NullIdentityProvider provider;

    setUp(() {
      provider = const NullIdentityProvider();
    });

    group('getAdvertisingId', () {
      test('returns null', () async {
        final result = await provider.getAdvertisingId();
        expect(result, isNull);
      });

      test('completes immediately', () async {
        // Verify the future completes quickly (no real async operation)
        final stopwatch = Stopwatch()..start();
        await provider.getAdvertisingId();
        stopwatch.stop();

        expect(stopwatch.elapsedMilliseconds, lessThan(100));
      });
    });

    group('isTrackingEnabled', () {
      test('returns false', () async {
        final result = await provider.isTrackingEnabled();
        expect(result, isFalse);
      });

      test('completes immediately', () async {
        final stopwatch = Stopwatch()..start();
        await provider.isTrackingEnabled();
        stopwatch.stop();

        expect(stopwatch.elapsedMilliseconds, lessThan(100));
      });
    });

    group('const constructor', () {
      test('can be created as const', () {
        const provider1 = NullIdentityProvider();
        const provider2 = NullIdentityProvider();

        // Const instances should be identical
        expect(identical(provider1, provider2), isTrue);
      });

      test('multiple instances behave identically', () async {
        const provider1 = NullIdentityProvider();
        const provider2 = NullIdentityProvider();

        final id1 = await provider1.getAdvertisingId();
        final id2 = await provider2.getAdvertisingId();
        final enabled1 = await provider1.isTrackingEnabled();
        final enabled2 = await provider2.isTrackingEnabled();

        expect(id1, equals(id2));
        expect(enabled1, equals(enabled2));
      });
    });
  });

  group('Custom identity provider', () {
    test('can implement RedditIdentityProvider interface', () async {
      final customProvider = _TestIdentityProvider();

      expect(customProvider, isA<RedditIdentityProvider>());
      expect(
        await customProvider.getAdvertisingId(),
        equals('test-advertising-id'),
      );
      expect(await customProvider.isTrackingEnabled(), isTrue);
    });

    test('can return different values based on state', () async {
      final provider = _StatefulIdentityProvider();

      expect(await provider.isTrackingEnabled(), isFalse);

      provider.enableTracking();
      expect(await provider.isTrackingEnabled(), isTrue);

      provider.updateAdvertisingId('custom-id-123');
      expect(await provider.getAdvertisingId(), equals('custom-id-123'));
    });
  });
}

/// Test implementation that returns fixed values.
class _TestIdentityProvider implements RedditIdentityProvider {
  @override
  Future<String?> getAdvertisingId() async => 'test-advertising-id';

  @override
  Future<bool> isTrackingEnabled() async => true;
}

/// Test implementation with mutable state.
class _StatefulIdentityProvider implements RedditIdentityProvider {
  String? _advertisingId;
  bool _trackingEnabled = false;

  void enableTracking() => _trackingEnabled = true;
  void disableTracking() => _trackingEnabled = false;
  // ignore: use_setters_to_change_properties, Test helper method.
  void updateAdvertisingId(String? id) => _advertisingId = id;

  @override
  Future<String?> getAdvertisingId() async => _advertisingId;

  @override
  Future<bool> isTrackingEnabled() async => _trackingEnabled;
}
