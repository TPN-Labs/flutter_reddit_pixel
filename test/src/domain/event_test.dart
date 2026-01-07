import 'package:flutter_test/flutter_test.dart';
import 'package:reddit_pixel/src/domain/event.dart';
import 'package:reddit_pixel/src/domain/user_data.dart';

void main() {
  group('RedditEvent', () {
    group('PurchaseEvent', () {
      test('creates with all fields', () {
        final event = PurchaseEvent(
          value: 99.99,
          currency: 'USD',
          itemCount: 2,
          userData: const RedditUserData(email: 'test@example.com'),
          customData: const {'promo': 'summer2024'},
        );

        expect(event.eventName, equals('Purchase'));
        expect(event.value, equals(99.99));
        expect(event.currency, equals('USD'));
        expect(event.itemCount, equals(2));
        expect(event.userData?.email, equals('test@example.com'));
        expect(event.customData?['promo'], equals('summer2024'));
      });

      test('generates event ID if not provided', () {
        final event = PurchaseEvent();

        expect(event.eventId, isNotEmpty);
        expect(event.eventId.length, equals(36)); // UUID v4 format
      });

      test('uses provided event ID', () {
        final event = PurchaseEvent(eventId: 'custom-id-123');

        expect(event.eventId, equals('custom-id-123'));
      });

      test('uses current time if eventAt not provided', () {
        final before = DateTime.now();
        final event = PurchaseEvent();
        final after = DateTime.now();

        expect(
          event.eventAt.isAfter(before.subtract(const Duration(seconds: 1))),
          isTrue,
        );
        expect(
          event.eventAt.isBefore(after.add(const Duration(seconds: 1))),
          isTrue,
        );
      });

      test('toJson produces correct format', () {
        final eventAt = DateTime.utc(2024, 1, 15, 10, 30);
        final event = PurchaseEvent(
          value: 49.99,
          currency: 'EUR',
          itemCount: 1,
          eventAt: eventAt,
          eventId: 'evt-123',
        );

        final json = event.toJson();

        expect(json['event_name'], equals('Purchase'));
        expect(json['event_at'], equals('2024-01-15T10:30:00.000Z'));
        final metadata = json['event_metadata'] as Map<String, dynamic>;
        expect(metadata['event_id'], equals('evt-123'));
        expect(metadata['action_source'], equals('APP'));
        final customData = metadata['custom_data'] as Map<String, dynamic>;
        expect(customData['value'], equals(49.99));
        expect(customData['currency'], equals('EUR'));
        expect(customData['item_count'], equals(1));
      });
    });

    group('SignUpEvent', () {
      test('creates correctly', () {
        final event = SignUpEvent(
          userData: const RedditUserData(email: 'newuser@example.com'),
        );

        expect(event.eventName, equals('SignUp'));
        expect(event.userData?.email, equals('newuser@example.com'));
      });

      test('toJson produces correct format', () {
        final event = SignUpEvent(eventId: 'evt-456');

        final json = event.toJson();

        expect(json['event_name'], equals('SignUp'));
        final metadata = json['event_metadata'] as Map<String, dynamic>;
        expect(metadata['event_id'], equals('evt-456'));
      });
    });

    group('LeadEvent', () {
      test('creates correctly', () {
        final event = LeadEvent(
          customData: {'lead_source': 'form'},
        );

        expect(event.eventName, equals('Lead'));
        expect(event.customData?['lead_source'], equals('form'));
      });
    });

    group('AddToCartEvent', () {
      test('creates with value and currency', () {
        final event = AddToCartEvent(
          value: 29.99,
          currency: 'USD',
          itemCount: 1,
        );

        expect(event.eventName, equals('AddToCart'));
        expect(event.value, equals(29.99));
        expect(event.currency, equals('USD'));
        expect(event.itemCount, equals(1));
      });

      test('toJson includes custom data', () {
        final event = AddToCartEvent(
          value: 15,
          currency: 'GBP',
          eventId: 'evt-cart',
        );

        final json = event.toJson();
        final metadata = json['event_metadata'] as Map<String, dynamic>;
        final customData = metadata['custom_data'] as Map<String, dynamic>;

        expect(customData['value'], equals(15));
        expect(customData['currency'], equals('GBP'));
      });
    });

    group('AddToWishlistEvent', () {
      test('creates correctly', () {
        final event = AddToWishlistEvent(
          value: 199.99,
          currency: 'USD',
        );

        expect(event.eventName, equals('AddToWishlist'));
        expect(event.value, equals(199.99));
        expect(event.currency, equals('USD'));
      });
    });

    group('SearchEvent', () {
      test('creates with search string', () {
        final event = SearchEvent(
          searchString: 'wireless headphones',
        );

        expect(event.eventName, equals('Search'));
        expect(event.searchString, equals('wireless headphones'));
      });

      test('toJson includes search string', () {
        final event = SearchEvent(
          searchString: 'test query',
          eventId: 'evt-search',
        );

        final json = event.toJson();
        final metadata = json['event_metadata'] as Map<String, dynamic>;
        final customData = metadata['custom_data'] as Map<String, dynamic>;

        expect(customData['search_string'], equals('test query'));
      });
    });

    group('ViewContentEvent', () {
      test('creates with content details', () {
        final event = ViewContentEvent(
          contentId: 'product-123',
          contentName: 'Premium Widget',
        );

        expect(event.eventName, equals('ViewContent'));
        expect(event.contentId, equals('product-123'));
        expect(event.contentName, equals('Premium Widget'));
      });
    });

    group('PageVisitEvent', () {
      test('creates with page URL', () {
        final event = PageVisitEvent(
          pageUrl: '/checkout',
        );

        expect(event.eventName, equals('PageVisit'));
        expect(event.pageUrl, equals('/checkout'));
      });
    });

    group('CustomEvent', () {
      test('creates with custom event name', () {
        final event = CustomEvent(
          customEventName: 'VideoWatched',
          customData: {'video_id': 'vid-123', 'duration': 120},
        );

        expect(event.eventName, equals('VideoWatched'));
        expect(event.customData?['video_id'], equals('vid-123'));
        expect(event.customData?['duration'], equals(120));
      });
    });

    group('fromJson', () {
      test('deserializes PurchaseEvent', () {
        final json = {
          'event_name': 'Purchase',
          'event_at': '2024-01-15T10:30:00.000Z',
          'event_metadata': {
            'event_id': 'evt-123',
            'custom_data': {
              'value': 99.99,
              'currency': 'USD',
              'item_count': 2,
            },
          },
        };

        final event = RedditEvent.fromJson(json);

        expect(event, isA<PurchaseEvent>());
        final purchase = event as PurchaseEvent;
        expect(purchase.value, equals(99.99));
        expect(purchase.currency, equals('USD'));
        expect(purchase.itemCount, equals(2));
      });

      test('deserializes SignUpEvent', () {
        final json = {
          'event_name': 'SignUp',
          'event_at': '2024-01-15T10:30:00.000Z',
          'event_metadata': {'event_id': 'evt-456'},
        };

        final event = RedditEvent.fromJson(json);

        expect(event, isA<SignUpEvent>());
        expect(event.eventId, equals('evt-456'));
      });

      test('deserializes LeadEvent', () {
        final json = {
          'event_name': 'Lead',
          'event_at': '2024-01-15T10:30:00.000Z',
          'event_metadata': {'event_id': 'evt-lead'},
        };

        final event = RedditEvent.fromJson(json);

        expect(event, isA<LeadEvent>());
      });

      test('deserializes unknown event as CustomEvent', () {
        final json = {
          'event_name': 'UnknownEventType',
          'event_at': '2024-01-15T10:30:00.000Z',
          'event_metadata': {'event_id': 'evt-unknown'},
        };

        final event = RedditEvent.fromJson(json);

        expect(event, isA<CustomEvent>());
        expect(event.eventName, equals('UnknownEventType'));
      });

      test('deserializes with user data', () {
        final json = {
          'event_name': 'Purchase',
          'event_at': '2024-01-15T10:30:00.000Z',
          'event_metadata': {'event_id': 'evt-with-user'},
          'user_data': {
            'email': 'test@example.com',
            'external_id': 'user-123',
          },
        };

        final event = RedditEvent.fromJson(json);

        expect(event.userData, isNotNull);
        expect(event.userData?.email, equals('test@example.com'));
        expect(event.userData?.externalId, equals('user-123'));
      });

      test('round-trips correctly', () {
        final original = PurchaseEvent(
          value: 99.99,
          currency: 'USD',
          itemCount: 3,
          eventId: 'roundtrip-test',
          eventAt: DateTime.utc(2024, 6, 15, 12),
          userData: const RedditUserData(
            email: 'roundtrip@example.com',
            externalId: 'rt-123',
          ),
        );

        final json = original.toJson();
        final restored = RedditEvent.fromJson(json);

        expect(restored, isA<PurchaseEvent>());
        final purchase = restored as PurchaseEvent;
        expect(purchase.eventId, equals('roundtrip-test'));
        expect(purchase.value, equals(99.99));
        expect(purchase.currency, equals('USD'));
        expect(purchase.itemCount, equals(3));
        expect(purchase.userData?.email, equals('roundtrip@example.com'));
      });
    });

    group('pattern matching', () {
      test('works with switch expression', () {
        final events = <RedditEvent>[
          PurchaseEvent(value: 100),
          SignUpEvent(),
          LeadEvent(),
          CustomEvent(customEventName: 'Test'),
        ];

        final names = events.map((event) {
          return switch (event) {
            PurchaseEvent(:final value) => 'Purchase: $value',
            SignUpEvent() => 'SignUp',
            LeadEvent() => 'Lead',
            AddToCartEvent() => 'AddToCart',
            AddToWishlistEvent() => 'AddToWishlist',
            SearchEvent() => 'Search',
            ViewContentEvent() => 'ViewContent',
            PageVisitEvent() => 'PageVisit',
            CustomEvent(:final customEventName) => 'Custom: $customEventName',
          };
        }).toList();

        expect(names[0], equals('Purchase: 100.0'));
        expect(names[1], equals('SignUp'));
        expect(names[2], equals('Lead'));
        expect(names[3], equals('Custom: Test'));
      });
    });
  });
}
