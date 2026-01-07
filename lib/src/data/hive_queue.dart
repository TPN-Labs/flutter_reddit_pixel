import 'package:hive/hive.dart';
import 'package:reddit_pixel/src/core/logger.dart';
import 'package:reddit_pixel/src/data/event_adapter.dart';
import 'package:reddit_pixel/src/domain/event.dart';

/// Offline-first event queue backed by Hive.
///
/// This queue implements a "Store-and-Forward" mechanism for reliable
/// event delivery:
///
/// 1. Events are immediately written to persistent storage
/// 2. A background dispatcher reads batches and sends them
/// 3. Successfully sent events are removed from the queue
/// 4. Failed events remain in the queue for retry
///
/// The queue survives app restarts and handles offline scenarios
/// gracefully. Events are stored in order and retrieved in FIFO order.
///
/// Example:
/// ```dart
/// final queue = HiveEventQueue();
/// await queue.initialize();
///
/// // Queue an event
/// await queue.enqueue(PurchaseEvent(value: 99.99));
///
/// // Get batch for sending
/// final batch = await queue.dequeue(maxBatch: 100);
///
/// // Mark as sent after successful delivery
/// await queue.markSent(batch.map((e) => e.eventId).toList());
/// ```
class HiveEventQueue {
  /// Creates a new Hive event queue.
  ///
  /// Call [initialize] before using other methods.
  HiveEventQueue({
    String boxName = 'reddit_pixel_events',
  }) : _boxName = boxName;

  final String _boxName;
  Box<StoredEvent>? _box;

  bool _isInitialized = false;

  /// Whether the queue has been initialized.
  bool get isInitialized => _isInitialized;

  /// Initializes the queue and registers Hive adapters.
  ///
  /// This must be called before using other methods. It's safe to call
  /// multiple times.
  ///
  /// **Note:** Ensure [Hive.initFlutter()] has been called before this.
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Register adapters if not already registered
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(RedditEventAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(RedditUserDataAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(StoredEventAdapter());
    }

    _box = await Hive.openBox<StoredEvent>(_boxName);
    _isInitialized = true;

    RedditPixelLogger.debug(
      'HiveEventQueue initialized with ${_box!.length} pending events',
    );
  }

  /// Adds an event to the queue.
  ///
  /// The event is immediately persisted to disk.
  Future<void> enqueue(RedditEvent event) async {
    _ensureInitialized();

    final stored = StoredEvent.fromEvent(event);
    await _box!.put(event.eventId, stored);

    RedditPixelLogger.debug(
      'Enqueued event ${event.eventId} (${event.eventName}). '
      'Queue size: ${_box!.length}',
    );
  }

  /// Retrieves a batch of events from the queue without removing them.
  ///
  /// Events are returned in FIFO order (oldest first).
  ///
  /// Parameters:
  /// - [maxBatch]: Maximum number of events to retrieve (default: 500,
  ///   which is Reddit's API limit).
  ///
  /// Returns a list of events, or an empty list if the queue is empty.
  Future<List<RedditEvent>> dequeue({int maxBatch = 500}) async {
    _ensureInitialized();

    final events = <RedditEvent>[];
    final values = _box!.values.take(maxBatch);

    for (final stored in values) {
      try {
        events.add(stored.toEvent());
      } on FormatException catch (e) {
        RedditPixelLogger.error(
          'Failed to deserialize event ${stored.eventId}',
          error: e,
        );
        // Remove corrupted event
        await _box!.delete(stored.eventId);
      }
    }

    RedditPixelLogger.debug(
      'Dequeued ${events.length} events (requested max: $maxBatch)',
    );

    return events;
  }

  /// Removes successfully sent events from the queue.
  ///
  /// Call this after events have been successfully delivered to Reddit's API.
  Future<void> markSent(List<String> eventIds) async {
    _ensureInitialized();

    await _box!.deleteAll(eventIds);

    RedditPixelLogger.debug(
      'Marked ${eventIds.length} events as sent. '
      'Remaining in queue: ${_box!.length}',
    );
  }

  /// Returns the number of pending events in the queue.
  Future<int> get pendingCount async {
    _ensureInitialized();
    return _box!.length;
  }

  /// Clears all events from the queue.
  ///
  /// Use with caution - this removes all unsent events.
  Future<void> clear() async {
    _ensureInitialized();

    final count = _box!.length;
    await _box!.clear();

    RedditPixelLogger.debug('Cleared $count events from queue');
  }

  /// Closes the queue and releases resources.
  ///
  /// The queue can be reinitialized after disposal by calling [initialize].
  Future<void> dispose() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
    }
    _isInitialized = false;

    RedditPixelLogger.debug('HiveEventQueue disposed');
  }

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError(
        'HiveEventQueue not initialized. Call initialize() first.',
      );
    }
  }
}
