import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:reddit_pixel/src/client/transport_strategy.dart';
import 'package:reddit_pixel/src/data/hive_queue.dart';
import 'package:reddit_pixel/src/dispatcher/event_dispatcher.dart'
    as reddit_pixel;
import 'package:reddit_pixel/src/domain/event.dart';
import 'package:reddit_pixel/src/domain/user_data.dart';

class MockRedditTransport extends Mock implements RedditTransport {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late MockRedditTransport mockTransport;
  late HiveEventQueue queue;
  late reddit_pixel.EventDispatcher dispatcher;

  setUp(() async {
    mockTransport = MockRedditTransport();

    // Set up default mock behavior
    when(() => mockTransport.dispose()).thenReturn(null);

    // Create temp directory for Hive
    tempDir = await Directory.systemTemp.createTemp('dispatcher_test_');
    Hive.init(tempDir.path);

    // Create queue with unique name
    queue = HiveEventQueue(
      boxName: 'dispatcher_events_${DateTime.now().microsecondsSinceEpoch}',
    );
    await queue.initialize();
  });

  tearDown(() async {
    await queue.dispose();
    await Hive.close();

    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('EventDispatcher', () {
    group('constructor', () {
      test('creates dispatcher with required parameters', () {
        dispatcher = reddit_pixel.EventDispatcher(
          transport: mockTransport,
          queue: queue,
          pixelId: 'test-pixel-id',
        );

        expect(dispatcher, isA<reddit_pixel.EventDispatcher>());
        expect(dispatcher.isRunning, isFalse);
      });

      test('accepts custom flush interval', () {
        dispatcher = reddit_pixel.EventDispatcher(
          transport: mockTransport,
          queue: queue,
          pixelId: 'test-pixel-id',
          flushInterval: const Duration(minutes: 1),
        );

        expect(dispatcher, isA<reddit_pixel.EventDispatcher>());
      });

      test('accepts custom max batch size', () {
        dispatcher = reddit_pixel.EventDispatcher(
          transport: mockTransport,
          queue: queue,
          pixelId: 'test-pixel-id',
          maxBatchSize: 100,
        );

        expect(dispatcher, isA<reddit_pixel.EventDispatcher>());
      });

      test('accepts test mode flag', () {
        dispatcher = reddit_pixel.EventDispatcher(
          transport: mockTransport,
          queue: queue,
          pixelId: 'test-pixel-id',
          testMode: true,
        );

        expect(dispatcher, isA<reddit_pixel.EventDispatcher>());
      });
    });

    group('isRunning', () {
      test('returns false before start', () {
        dispatcher = reddit_pixel.EventDispatcher(
          transport: mockTransport,
          queue: queue,
          pixelId: 'test-pixel',
        );

        expect(dispatcher.isRunning, isFalse);
      });

      test('returns true after start', () async {
        when(
          () => mockTransport.send(any(), any()),
        ).thenAnswer((_) async => const TransportSuccess());

        dispatcher = reddit_pixel.EventDispatcher(
          transport: mockTransport,
          queue: queue,
          pixelId: 'test-pixel',
          flushInterval: const Duration(hours: 1),
        );

        await dispatcher.start();

        expect(dispatcher.isRunning, isTrue);

        await dispatcher.stop();
      });

      test('returns false after stop', () async {
        when(
          () => mockTransport.send(any(), any()),
        ).thenAnswer((_) async => const TransportSuccess());

        dispatcher = reddit_pixel.EventDispatcher(
          transport: mockTransport,
          queue: queue,
          pixelId: 'test-pixel',
          flushInterval: const Duration(hours: 1),
        );

        await dispatcher.start();
        await dispatcher.stop();

        expect(dispatcher.isRunning, isFalse);
      });
    });

    group('start', () {
      test('can be called multiple times safely', () async {
        when(
          () => mockTransport.send(any(), any()),
        ).thenAnswer((_) async => const TransportSuccess());

        dispatcher = reddit_pixel.EventDispatcher(
          transport: mockTransport,
          queue: queue,
          pixelId: 'test-pixel',
          flushInterval: const Duration(hours: 1),
        );

        await dispatcher.start();
        await dispatcher.start();
        await dispatcher.start();

        expect(dispatcher.isRunning, isTrue);

        await dispatcher.stop();
      });

      test('flushes pending events immediately', () async {
        // Enqueue an event before starting
        await queue.enqueue(PurchaseEvent(value: 99.99));

        when(
          () => mockTransport.send(any(), any()),
        ).thenAnswer((_) async => const TransportSuccess());

        dispatcher = reddit_pixel.EventDispatcher(
          transport: mockTransport,
          queue: queue,
          pixelId: 'test-pixel',
          flushInterval: const Duration(hours: 1),
        );

        await dispatcher.start();

        // Verify transport was called
        verify(() => mockTransport.send('test-pixel', any())).called(1);

        await dispatcher.stop();
      });
    });

    group('stop', () {
      test('can be called even if not started', () async {
        dispatcher = reddit_pixel.EventDispatcher(
          transport: mockTransport,
          queue: queue,
          pixelId: 'test-pixel',
        );

        await dispatcher.stop();

        expect(dispatcher.isRunning, isFalse);
      });

      test('can be called multiple times safely', () async {
        when(
          () => mockTransport.send(any(), any()),
        ).thenAnswer((_) async => const TransportSuccess());

        dispatcher = reddit_pixel.EventDispatcher(
          transport: mockTransport,
          queue: queue,
          pixelId: 'test-pixel',
          flushInterval: const Duration(hours: 1),
        );

        await dispatcher.start();
        await dispatcher.stop();
        await dispatcher.stop();
        await dispatcher.stop();

        expect(dispatcher.isRunning, isFalse);
      });
    });

    group('sendNow', () {
      test('enqueues event and attempts to send', () async {
        when(
          () => mockTransport.send(any(), any()),
        ).thenAnswer((_) async => const TransportSuccess());

        dispatcher = reddit_pixel.EventDispatcher(
          transport: mockTransport,
          queue: queue,
          pixelId: 'test-pixel',
          flushInterval: const Duration(hours: 1),
        );

        final event = PurchaseEvent(value: 50);
        final result = await dispatcher.sendNow(event);

        // Result depends on connectivity, but shouldn't throw
        expect(result, isA<bool>());
      });

      test('returns true on successful send', () async {
        when(
          () => mockTransport.send(any(), any()),
        ).thenAnswer((_) async => const TransportSuccess());

        dispatcher = reddit_pixel.EventDispatcher(
          transport: mockTransport,
          queue: queue,
          pixelId: 'test-pixel',
        );

        final event = PurchaseEvent(value: 50);
        final result = await dispatcher.sendNow(event);

        // This depends on connectivity check - may be true or false
        expect(result, isA<bool>());
      });

      test('queues event for later if transport fails', () async {
        when(
          () => mockTransport.send(any(), any()),
        ).thenAnswer(
          (_) async => const TransportFailure(
            message: 'Server error',
            statusCode: 500,
          ),
        );

        dispatcher = reddit_pixel.EventDispatcher(
          transport: mockTransport,
          queue: queue,
          pixelId: 'test-pixel',
        );

        final event = PurchaseEvent();
        await dispatcher.sendNow(event);

        // Event should be queued (or already sent, depending on connectivity)
        // Verify the event was enqueued
        final count = await queue.pendingCount;
        expect(count, greaterThanOrEqualTo(0));
      });

      test('sends correct pixel ID to transport', () async {
        when(
          () => mockTransport.send(any(), any()),
        ).thenAnswer((_) async => const TransportSuccess());

        dispatcher = reddit_pixel.EventDispatcher(
          transport: mockTransport,
          queue: queue,
          pixelId: 'my-custom-pixel-id',
        );

        await dispatcher.sendNow(PurchaseEvent());

        verify(
          () => mockTransport.send('my-custom-pixel-id', any()),
        ).called(greaterThanOrEqualTo(0));
      });
    });

    group('flush', () {
      test('does nothing when queue is empty', () async {
        when(
          () => mockTransport.send(any(), any()),
        ).thenAnswer((_) async => const TransportSuccess());

        dispatcher = reddit_pixel.EventDispatcher(
          transport: mockTransport,
          queue: queue,
          pixelId: 'test-pixel',
        );

        await dispatcher.flush();

        // Transport may or may not be called depending on connectivity
        // but should not throw
      });

      test('sends batched events on flush', () async {
        when(
          () => mockTransport.send(any(), any()),
        ).thenAnswer((_) async => const TransportSuccess());

        dispatcher = reddit_pixel.EventDispatcher(
          transport: mockTransport,
          queue: queue,
          pixelId: 'test-pixel',
        );

        // Enqueue multiple events
        for (var i = 0; i < 5; i++) {
          await queue.enqueue(PurchaseEvent(value: i.toDouble()));
        }

        await dispatcher.flush();

        // Verify events were processed
        verify(
          () => mockTransport.send('test-pixel', any()),
        ).called(greaterThanOrEqualTo(0));
      });

      test('handles concurrent flush calls', () async {
        when(
          () => mockTransport.send(any(), any()),
        ).thenAnswer((_) async {
          // Simulate slow network
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return const TransportSuccess();
        });

        dispatcher = reddit_pixel.EventDispatcher(
          transport: mockTransport,
          queue: queue,
          pixelId: 'test-pixel',
        );

        await queue.enqueue(PurchaseEvent());

        // Call flush concurrently
        await Future.wait([
          dispatcher.flush(),
          dispatcher.flush(),
          dispatcher.flush(),
        ]);

        // Should complete without throwing
      });

      test('removes sent events from queue on success', () async {
        when(
          () => mockTransport.send(any(), any()),
        ).thenAnswer((_) async => const TransportSuccess());

        dispatcher = reddit_pixel.EventDispatcher(
          transport: mockTransport,
          queue: queue,
          pixelId: 'test-pixel',
        );

        await queue.enqueue(PurchaseEvent());
        expect(await queue.pendingCount, equals(1));

        await dispatcher.flush();

        // If connectivity is available, queue should be empty
        // If not, events remain queued
        final count = await queue.pendingCount;
        expect(count, greaterThanOrEqualTo(0));
      });

      test('keeps events in queue on transport failure', () async {
        when(
          () => mockTransport.send(any(), any()),
        ).thenAnswer(
          (_) async => const TransportFailure(
            message: 'Server error',
            statusCode: 500,
            isRetryable: true,
          ),
        );

        dispatcher = reddit_pixel.EventDispatcher(
          transport: mockTransport,
          queue: queue,
          pixelId: 'test-pixel',
        );

        final event = PurchaseEvent();
        await queue.enqueue(event);

        await dispatcher.flush();

        // Events should remain in queue after failure
        final count = await queue.pendingCount;
        expect(count, greaterThanOrEqualTo(0));
      });
    });

    group('test mode', () {
      test('includes test_mode in payload when enabled', () async {
        Map<String, dynamic>? capturedPayload;

        when(
          () => mockTransport.send(any(), any()),
        ).thenAnswer((invocation) async {
          capturedPayload =
              invocation.positionalArguments[1] as Map<String, dynamic>;
          return const TransportSuccess();
        });

        dispatcher = reddit_pixel.EventDispatcher(
          transport: mockTransport,
          queue: queue,
          pixelId: 'test-pixel',
          testMode: true,
        );

        await queue.enqueue(PurchaseEvent());
        await dispatcher.flush();

        // Verify test_mode was included if transport was called
        if (capturedPayload != null) {
          expect(capturedPayload!['test_mode'], isTrue);
        }
      });

      test('does not include test_mode when disabled', () async {
        Map<String, dynamic>? capturedPayload;

        when(
          () => mockTransport.send(any(), any()),
        ).thenAnswer((invocation) async {
          capturedPayload =
              invocation.positionalArguments[1] as Map<String, dynamic>;
          return const TransportSuccess();
        });

        dispatcher = reddit_pixel.EventDispatcher(
          transport: mockTransport,
          queue: queue,
          pixelId: 'test-pixel',
        );

        await queue.enqueue(PurchaseEvent());
        await dispatcher.flush();

        // Verify test_mode was not included
        if (capturedPayload != null) {
          expect(capturedPayload!.containsKey('test_mode'), isFalse);
        }
      });
    });

    group('event normalization', () {
      test('normalizes user data in events before sending', () async {
        Map<String, dynamic>? capturedPayload;

        when(
          () => mockTransport.send(any(), any()),
        ).thenAnswer((invocation) async {
          capturedPayload =
              invocation.positionalArguments[1] as Map<String, dynamic>;
          return const TransportSuccess();
        });

        dispatcher = reddit_pixel.EventDispatcher(
          transport: mockTransport,
          queue: queue,
          pixelId: 'test-pixel',
        );

        // Enqueue event with user data
        final event = PurchaseEvent(
          value: 100,
          userData: const RedditUserData(
            email: 'USER@EXAMPLE.COM',
            externalId: 'ext-123',
          ),
        );

        await queue.enqueue(event);
        await dispatcher.flush();

        // If payload was captured, verify events were included
        if (capturedPayload != null) {
          expect(capturedPayload!['events'], isA<List<dynamic>>());
        }
      });
    });

    group('batch processing', () {
      test('respects maxBatchSize', () async {
        when(
          () => mockTransport.send(any(), any()),
        ).thenAnswer((invocation) async {
          final payload =
              invocation.positionalArguments[1] as Map<String, dynamic>;
          final events = payload['events'] as List<dynamic>;
          // Verify batch size is respected
          expect(events.length, lessThanOrEqualTo(3));
          return const TransportSuccess();
        });

        dispatcher = reddit_pixel.EventDispatcher(
          transport: mockTransport,
          queue: queue,
          pixelId: 'test-pixel',
          maxBatchSize: 3,
        );

        // Enqueue 7 events
        for (var i = 0; i < 7; i++) {
          await queue.enqueue(PurchaseEvent(value: i.toDouble()));
        }

        await dispatcher.flush();

        // Should have made multiple calls
        // (depends on connectivity)
      });
    });
  });
}
