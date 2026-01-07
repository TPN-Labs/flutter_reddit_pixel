import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:reddit_pixel/src/data/hive_queue.dart';
import 'package:reddit_pixel/src/domain/event.dart';
import 'package:reddit_pixel/src/domain/user_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late HiveEventQueue queue;

  setUp(() async {
    // Create a temporary directory for Hive
    tempDir = await Directory.systemTemp.createTemp('hive_test_');
    Hive.init(tempDir.path);

    // Use unique box name for each test
    queue = HiveEventQueue(
      boxName: 'test_events_${DateTime.now().microsecondsSinceEpoch}',
    );
  });

  tearDown(() async {
    await queue.dispose();
    await Hive.close();

    // Clean up temp directory
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('HiveEventQueue', () {
    group('initialization', () {
      test('isInitialized returns false before initialize', () {
        final newQueue = HiveEventQueue(boxName: 'uninit_box');
        expect(newQueue.isInitialized, isFalse);
      });

      test('isInitialized returns true after initialize', () async {
        await queue.initialize();
        expect(queue.isInitialized, isTrue);
      });

      test('initialize can be called multiple times safely', () async {
        await queue.initialize();
        await queue.initialize();
        await queue.initialize();

        expect(queue.isInitialized, isTrue);
      });
    });

    group('enqueue', () {
      test('throws StateError when not initialized', () async {
        expect(
          () => queue.enqueue(PurchaseEvent()),
          throwsStateError,
        );
      });

      test('enqueues PurchaseEvent successfully', () async {
        await queue.initialize();

        final event = PurchaseEvent(value: 99.99);
        await queue.enqueue(event);

        final count = await queue.pendingCount;
        expect(count, equals(1));
      });

      test('enqueues SignUpEvent successfully', () async {
        await queue.initialize();

        final event = SignUpEvent();
        await queue.enqueue(event);

        final count = await queue.pendingCount;
        expect(count, equals(1));
      });

      test('enqueues multiple events', () async {
        await queue.initialize();

        await queue.enqueue(PurchaseEvent());
        await queue.enqueue(SignUpEvent());
        await queue.enqueue(LeadEvent());

        final count = await queue.pendingCount;
        expect(count, equals(3));
      });

      test('enqueues event with user data', () async {
        await queue.initialize();

        final event = PurchaseEvent(
          userData: const RedditUserData(
            email: 'test@example.com',
            externalId: 'ext-123',
          ),
        );

        await queue.enqueue(event);

        final events = await queue.dequeue();
        expect(events, hasLength(1));
        expect(events.first, isA<PurchaseEvent>());
        final retrieved = events.first as PurchaseEvent;
        expect(retrieved.userData?.email, equals('test@example.com'));
      });

      test('enqueues event with custom data', () async {
        await queue.initialize();

        final event = CustomEvent(
          customEventName: 'test_event',
          customData: {'key': 'value', 'number': 42},
        );

        await queue.enqueue(event);

        final events = await queue.dequeue();
        expect(events, hasLength(1));
        final retrieved = events.first as CustomEvent;
        expect(retrieved.customEventName, equals('test_event'));
        expect(retrieved.customData?['key'], equals('value'));
        expect(retrieved.customData?['number'], equals(42));
      });
    });

    group('dequeue', () {
      test('throws StateError when not initialized', () async {
        expect(
          () => queue.dequeue(),
          throwsStateError,
        );
      });

      test('returns empty list when queue is empty', () async {
        await queue.initialize();

        final events = await queue.dequeue();
        expect(events, isEmpty);
      });

      test('returns all queued events', () async {
        await queue.initialize();

        final event1 = PurchaseEvent(value: 10);
        final event2 = PurchaseEvent(value: 20);
        final event3 = PurchaseEvent(value: 30);

        await queue.enqueue(event1);
        await queue.enqueue(event2);
        await queue.enqueue(event3);

        final events = await queue.dequeue();

        expect(events, hasLength(3));

        // Verify all events are present (order may vary based on UUID keys)
        final eventIds = events.map((e) => e.eventId).toSet();
        expect(eventIds, contains(event1.eventId));
        expect(eventIds, contains(event2.eventId));
        expect(eventIds, contains(event3.eventId));
      });

      test('respects maxBatch parameter', () async {
        await queue.initialize();

        // Enqueue 10 events
        for (var i = 0; i < 10; i++) {
          await queue.enqueue(PurchaseEvent(value: i.toDouble()));
        }

        final events = await queue.dequeue(maxBatch: 3);
        expect(events, hasLength(3));

        // Queue should still have 10 events (dequeue doesn't remove)
        final count = await queue.pendingCount;
        expect(count, equals(10));
      });

      test('defaults to maxBatch of 500', () async {
        await queue.initialize();

        // Enqueue 5 events
        for (var i = 0; i < 5; i++) {
          await queue.enqueue(PurchaseEvent());
        }

        // Should return all 5 since less than 500
        final events = await queue.dequeue();
        expect(events, hasLength(5));
      });

      test('does not remove events from queue', () async {
        await queue.initialize();

        await queue.enqueue(PurchaseEvent());

        // First dequeue
        final events1 = await queue.dequeue();
        expect(events1, hasLength(1));

        // Second dequeue should return same event
        final events2 = await queue.dequeue();
        expect(events2, hasLength(1));
        expect(events2.first.eventId, equals(events1.first.eventId));
      });
    });

    group('markSent', () {
      test('throws StateError when not initialized', () async {
        expect(
          () => queue.markSent(['event-id']),
          throwsStateError,
        );
      });

      test('removes events by ID', () async {
        await queue.initialize();

        final event1 = PurchaseEvent();
        final event2 = SignUpEvent();

        await queue.enqueue(event1);
        await queue.enqueue(event2);

        expect(await queue.pendingCount, equals(2));

        await queue.markSent([event1.eventId]);

        expect(await queue.pendingCount, equals(1));

        final remaining = await queue.dequeue();
        expect(remaining, hasLength(1));
        expect(remaining.first.eventId, equals(event2.eventId));
      });

      test('handles multiple event IDs', () async {
        await queue.initialize();

        final events = <RedditEvent>[];
        for (var i = 0; i < 5; i++) {
          final event = PurchaseEvent();
          events.add(event);
          await queue.enqueue(event);
        }

        expect(await queue.pendingCount, equals(5));

        // Mark first 3 as sent
        await queue.markSent([
          events[0].eventId,
          events[1].eventId,
          events[2].eventId,
        ]);

        expect(await queue.pendingCount, equals(2));
      });

      test('handles non-existent event IDs gracefully', () async {
        await queue.initialize();

        await queue.enqueue(PurchaseEvent());

        // Should not throw
        await queue.markSent(['non-existent-id']);

        // Original event should still be there
        expect(await queue.pendingCount, equals(1));
      });

      test('handles empty list', () async {
        await queue.initialize();

        await queue.enqueue(PurchaseEvent());

        await queue.markSent([]);

        expect(await queue.pendingCount, equals(1));
      });
    });

    group('pendingCount', () {
      test('throws StateError when not initialized', () async {
        expect(
          () => queue.pendingCount,
          throwsStateError,
        );
      });

      test('returns 0 for empty queue', () async {
        await queue.initialize();

        expect(await queue.pendingCount, equals(0));
      });

      test('reflects number of enqueued events', () async {
        await queue.initialize();

        expect(await queue.pendingCount, equals(0));

        await queue.enqueue(PurchaseEvent());
        expect(await queue.pendingCount, equals(1));

        await queue.enqueue(SignUpEvent());
        expect(await queue.pendingCount, equals(2));

        await queue.enqueue(LeadEvent());
        expect(await queue.pendingCount, equals(3));
      });

      test('decreases after markSent', () async {
        await queue.initialize();

        final event = PurchaseEvent();
        await queue.enqueue(event);

        expect(await queue.pendingCount, equals(1));

        await queue.markSent([event.eventId]);

        expect(await queue.pendingCount, equals(0));
      });
    });

    group('clear', () {
      test('throws StateError when not initialized', () async {
        expect(
          () => queue.clear(),
          throwsStateError,
        );
      });

      test('removes all events', () async {
        await queue.initialize();

        await queue.enqueue(PurchaseEvent());
        await queue.enqueue(SignUpEvent());
        await queue.enqueue(LeadEvent());

        expect(await queue.pendingCount, equals(3));

        await queue.clear();

        expect(await queue.pendingCount, equals(0));
      });

      test('works on empty queue', () async {
        await queue.initialize();

        await queue.clear();

        expect(await queue.pendingCount, equals(0));
      });
    });

    group('dispose', () {
      test('sets isInitialized to false', () async {
        await queue.initialize();
        expect(queue.isInitialized, isTrue);

        await queue.dispose();
        expect(queue.isInitialized, isFalse);
      });

      test('can be called multiple times safely', () async {
        await queue.initialize();

        await queue.dispose();
        await queue.dispose();
        await queue.dispose();

        expect(queue.isInitialized, isFalse);
      });

      test('can reinitialize after dispose', () async {
        await queue.initialize();
        await queue.enqueue(PurchaseEvent());
        await queue.dispose();

        await queue.initialize();
        expect(queue.isInitialized, isTrue);
        // Note: events persist after reinitialize
      });
    });

    group('all event types', () {
      test('handles all event types correctly', () async {
        await queue.initialize();

        final events = [
          PurchaseEvent(value: 100),
          SignUpEvent(),
          LeadEvent(),
          AddToCartEvent(itemCount: 2),
          AddToWishlistEvent(),
          SearchEvent(searchString: 'test'),
          ViewContentEvent(contentId: 'content-1'),
          PageVisitEvent(pageUrl: 'https://example.com'),
          CustomEvent(customEventName: 'custom'),
        ];

        for (final event in events) {
          await queue.enqueue(event);
        }

        expect(await queue.pendingCount, equals(9));

        final retrieved = await queue.dequeue();
        expect(retrieved, hasLength(9));

        // Verify all event types are present (order may vary)
        final types = retrieved.map((e) => e.runtimeType).toSet();
        expect(types, contains(PurchaseEvent));
        expect(types, contains(SignUpEvent));
        expect(types, contains(LeadEvent));
        expect(types, contains(AddToCartEvent));
        expect(types, contains(AddToWishlistEvent));
        expect(types, contains(SearchEvent));
        expect(types, contains(ViewContentEvent));
        expect(types, contains(PageVisitEvent));
        expect(types, contains(CustomEvent));
      });
    });
  });
}
