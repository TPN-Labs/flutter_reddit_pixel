import 'package:flutter_test/flutter_test.dart';
import 'package:reddit_pixel/src/data/event_adapter.dart';
import 'package:reddit_pixel/src/domain/event.dart';
import 'package:reddit_pixel/src/domain/user_data.dart';

void main() {
  group('StoredEvent', () {
    group('fromEvent', () {
      test('creates StoredEvent from PurchaseEvent', () {
        final event = PurchaseEvent(
          value: 99.99,
          currency: 'USD',
          itemCount: 2,
        );

        final stored = StoredEvent.fromEvent(event);

        expect(stored.eventId, equals(event.eventId));
        expect(stored.eventJson, isNotEmpty);
        expect(stored.createdAt, isNotNull);
      });

      test('creates StoredEvent from SignUpEvent', () {
        final event = SignUpEvent(
          userData: const RedditUserData(email: 'test@example.com'),
        );

        final stored = StoredEvent.fromEvent(event);

        expect(stored.eventId, equals(event.eventId));
        expect(stored.eventJson, contains('SignUp'));
      });

      test('creates StoredEvent from CustomEvent', () {
        final event = CustomEvent(
          customEventName: 'my_custom_event',
          customData: {'key': 'value'},
        );

        final stored = StoredEvent.fromEvent(event);

        expect(stored.eventId, equals(event.eventId));
        expect(stored.eventJson, contains('my_custom_event'));
      });

      test('sets createdAt to current time', () {
        final before = DateTime.now();
        final event = PurchaseEvent();
        final stored = StoredEvent.fromEvent(event);
        final after = DateTime.now();

        expect(
          stored.createdAt.isAfter(
            before.subtract(const Duration(seconds: 1)),
          ),
          isTrue,
        );
        expect(
          stored.createdAt.isBefore(after.add(const Duration(seconds: 1))),
          isTrue,
        );
      });
    });

    group('fromMap', () {
      test('creates StoredEvent from valid map', () {
        final map = {
          'eventId': 'test-event-id',
          'eventJson': '{"event_name":"Purchase"}',
          'createdAt': '2024-01-15T10:30:00.000Z',
        };

        final stored = StoredEvent.fromMap(map);

        expect(stored.eventId, equals('test-event-id'));
        expect(stored.eventJson, equals('{"event_name":"Purchase"}'));
        expect(
          stored.createdAt,
          equals(DateTime.parse('2024-01-15T10:30:00.000Z')),
        );
      });

      test('handles dynamic map keys', () {
        final map = <dynamic, dynamic>{
          'eventId': 'dynamic-id',
          'eventJson': '{}',
          'createdAt': '2024-01-01T00:00:00.000Z',
        };

        final stored = StoredEvent.fromMap(map);
        expect(stored.eventId, equals('dynamic-id'));
      });
    });

    group('toEvent', () {
      test('deserializes back to PurchaseEvent', () {
        final original = PurchaseEvent(
          value: 49.99,
          currency: 'EUR',
          itemCount: 1,
        );

        final stored = StoredEvent.fromEvent(original);
        final restored = stored.toEvent();

        expect(restored, isA<PurchaseEvent>());
        final purchase = restored as PurchaseEvent;
        expect(purchase.eventId, equals(original.eventId));
        expect(purchase.value, equals(49.99));
        expect(purchase.currency, equals('EUR'));
        expect(purchase.itemCount, equals(1));
      });

      test('deserializes back to SignUpEvent', () {
        final original = SignUpEvent();
        final stored = StoredEvent.fromEvent(original);
        final restored = stored.toEvent();

        expect(restored, isA<SignUpEvent>());
        expect(restored.eventId, equals(original.eventId));
      });

      test('deserializes back to LeadEvent', () {
        final original = LeadEvent();
        final stored = StoredEvent.fromEvent(original);
        final restored = stored.toEvent();

        expect(restored, isA<LeadEvent>());
      });

      test('deserializes back to AddToCartEvent', () {
        final original = AddToCartEvent(
          value: 25,
          itemCount: 3,
        );

        final stored = StoredEvent.fromEvent(original);
        final restored = stored.toEvent();

        expect(restored, isA<AddToCartEvent>());
        final cart = restored as AddToCartEvent;
        expect(cart.value, equals(25.0));
        expect(cart.itemCount, equals(3));
      });

      test('deserializes back to AddToWishlistEvent', () {
        final original = AddToWishlistEvent(value: 15);
        final stored = StoredEvent.fromEvent(original);
        final restored = stored.toEvent();

        expect(restored, isA<AddToWishlistEvent>());
      });

      test('deserializes back to SearchEvent', () {
        final original = SearchEvent(searchString: 'flutter packages');
        final stored = StoredEvent.fromEvent(original);
        final restored = stored.toEvent();

        expect(restored, isA<SearchEvent>());
        final search = restored as SearchEvent;
        expect(search.searchString, equals('flutter packages'));
      });

      test('deserializes back to ViewContentEvent', () {
        final original = ViewContentEvent(
          contentId: 'content-123',
          contentName: 'Product Details',
        );

        final stored = StoredEvent.fromEvent(original);
        final restored = stored.toEvent();

        expect(restored, isA<ViewContentEvent>());
        final view = restored as ViewContentEvent;
        expect(view.contentId, equals('content-123'));
        expect(view.contentName, equals('Product Details'));
      });

      test('deserializes back to PageVisitEvent', () {
        final original = PageVisitEvent(pageUrl: 'https://example.com/page');
        final stored = StoredEvent.fromEvent(original);
        final restored = stored.toEvent();

        expect(restored, isA<PageVisitEvent>());
        final page = restored as PageVisitEvent;
        expect(page.pageUrl, equals('https://example.com/page'));
      });

      test('deserializes back to CustomEvent', () {
        final original = CustomEvent(
          customEventName: 'test_event',
          customData: {'key': 'value'},
        );

        final stored = StoredEvent.fromEvent(original);
        final restored = stored.toEvent();

        expect(restored, isA<CustomEvent>());
        final custom = restored as CustomEvent;
        expect(custom.customEventName, equals('test_event'));
        expect(custom.customData, equals({'key': 'value'}));
      });

      test('preserves userData through serialization', () {
        final original = PurchaseEvent(
          userData: const RedditUserData(
            email: 'user@test.com',
            externalId: 'ext-123',
          ),
        );

        final stored = StoredEvent.fromEvent(original);
        final restored = stored.toEvent() as PurchaseEvent;

        expect(restored.userData, isNotNull);
        expect(restored.userData!.email, equals('user@test.com'));
        expect(restored.userData!.externalId, equals('ext-123'));
      });

      test('throws FormatException for invalid JSON', () {
        final stored = StoredEvent(
          eventId: 'bad-event',
          eventJson: 'not valid json',
          createdAt: DateTime.now(),
        );

        expect(stored.toEvent, throwsFormatException);
      });
    });

    group('toMap', () {
      test('converts to map correctly', () {
        final createdAt = DateTime.parse('2024-06-15T12:00:00.000Z');
        final stored = StoredEvent(
          eventId: 'map-test-id',
          eventJson: '{"test": true}',
          createdAt: createdAt,
        );

        final map = stored.toMap();

        expect(map['eventId'], equals('map-test-id'));
        expect(map['eventJson'], equals('{"test": true}'));
        expect(map['createdAt'], equals('2024-06-15T12:00:00.000Z'));
      });

      test('toMap and fromMap are inverse operations', () {
        final original = StoredEvent(
          eventId: 'roundtrip-id',
          eventJson: '{"event_name":"Test"}',
          createdAt: DateTime.parse('2024-03-20T08:30:00.000Z'),
        );

        final map = original.toMap();
        final restored = StoredEvent.fromMap(map);

        expect(restored.eventId, equals(original.eventId));
        expect(restored.eventJson, equals(original.eventJson));
        expect(restored.createdAt, equals(original.createdAt));
      });
    });

    group('round-trip serialization', () {
      test('all event types survive complete round-trip', () {
        final events = <RedditEvent>[
          PurchaseEvent(value: 100, currency: 'GBP'),
          SignUpEvent(),
          LeadEvent(),
          AddToCartEvent(itemCount: 5),
          AddToWishlistEvent(),
          SearchEvent(searchString: 'test query'),
          ViewContentEvent(contentId: 'id-1'),
          PageVisitEvent(pageUrl: 'https://test.com'),
          CustomEvent(customEventName: 'custom'),
        ];

        for (final original in events) {
          final stored = StoredEvent.fromEvent(original);
          final map = stored.toMap();
          final restoredStored = StoredEvent.fromMap(map);
          final restoredEvent = restoredStored.toEvent();

          expect(
            restoredEvent.eventId,
            equals(original.eventId),
            reason: 'Event ID mismatch for ${original.eventName}',
          );
          expect(
            restoredEvent.eventName,
            equals(original.eventName),
            reason: 'Event name mismatch for ${original.eventName}',
          );
        }
      });
    });
  });

  group('RedditEventAdapter', () {
    test('has typeId 0', () {
      final adapter = RedditEventAdapter();
      expect(adapter.typeId, equals(0));
    });
  });

  group('RedditUserDataAdapter', () {
    test('has typeId 1', () {
      final adapter = RedditUserDataAdapter();
      expect(adapter.typeId, equals(1));
    });
  });

  group('StoredEventAdapter', () {
    test('has typeId 2', () {
      final adapter = StoredEventAdapter();
      expect(adapter.typeId, equals(2));
    });
  });
}
