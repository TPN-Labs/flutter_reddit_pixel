import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:reddit_pixel/src/client/transport_strategy.dart';
import 'package:reddit_pixel/src/core/logger.dart';
import 'package:reddit_pixel/src/core/normalizer.dart';
import 'package:reddit_pixel/src/data/hive_queue.dart';
import 'package:reddit_pixel/src/domain/event.dart';

/// Background event dispatcher with immediate and periodic sending.
///
/// The dispatcher handles event delivery with the following strategy:
///
/// **Immediate dispatch:**
/// When `sendNow` is called, the event is immediately sent if online.
/// If offline or if sending fails, the event is queued for later.
///
/// **Periodic background flush:**
/// A timer runs every `flushInterval` (default: 30 seconds) to send
/// any queued events. This handles:
/// - Events that failed immediate delivery
/// - Events queued while offline
/// - Batching for efficiency
///
/// **Failure handling:**
/// Failed events remain in the queue for the next flush attempt.
/// The transport layer handles retries for transient errors.
///
/// Example:
/// ```dart
/// final dispatcher = EventDispatcher(
///   transport: ProxyTransport(proxyUrl: 'https://api.example.com/reddit'),
///   queue: HiveEventQueue(),
///   pixelId: 'pixel123',
/// );
///
/// await dispatcher.start();
/// await dispatcher.sendNow(PurchaseEvent(value: 99.99));
/// await dispatcher.stop();
/// ```
class EventDispatcher {
  /// Creates an event dispatcher.
  EventDispatcher({
    required RedditTransport transport,
    required HiveEventQueue queue,
    required String pixelId,
    Duration flushInterval = const Duration(seconds: 30),
    int maxBatchSize = 500,
    bool testMode = false,
  })  : _transport = transport,
        _queue = queue,
        _pixelId = pixelId,
        _flushInterval = flushInterval,
        _maxBatchSize = maxBatchSize,
        _testMode = testMode;

  final RedditTransport _transport;
  final HiveEventQueue _queue;
  final String _pixelId;
  final Duration _flushInterval;
  final int _maxBatchSize;
  final bool _testMode;

  Timer? _flushTimer;
  bool _isRunning = false;
  bool _isFlushing = false;

  /// Whether the dispatcher is currently running.
  bool get isRunning => _isRunning;

  /// Starts the periodic background flush.
  ///
  /// Call this when initializing the library. The dispatcher will
  /// immediately attempt to send any queued events, then continue
  /// on the periodic schedule.
  Future<void> start() async {
    if (_isRunning) return;

    _isRunning = true;

    RedditPixelLogger.debug(
      'EventDispatcher started with ${_flushInterval.inSeconds}s interval',
    );

    // Immediately flush any pending events
    await flush();

    // Start periodic timer
    _flushTimer = Timer.periodic(_flushInterval, (_) => flush());
  }

  /// Stops the periodic background flush.
  ///
  /// Call this when the library is being disposed. Any pending events
  /// remain in the queue for the next session.
  Future<void> stop() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    _isRunning = false;

    RedditPixelLogger.debug('EventDispatcher stopped');
  }

  /// Attempts to send an event immediately.
  ///
  /// If online and the send succeeds, the event is delivered.
  /// If offline or the send fails, the event is queued for later.
  ///
  /// Returns `true` if the event was sent immediately, `false` if queued.
  Future<bool> sendNow(RedditEvent event) async {
    // Always queue first for durability
    await _queue.enqueue(event);

    // Check connectivity
    if (!await _isOnline()) {
      RedditPixelLogger.debug(
        'Offline - event ${event.eventId} queued for later',
      );
      return false;
    }

    // Try to send immediately
    final success = await _sendEvents([event]);

    if (success) {
      await _queue.markSent([event.eventId]);
      RedditPixelLogger.debug('Event ${event.eventId} sent immediately');
      return true;
    }

    RedditPixelLogger.debug(
      'Immediate send failed - event ${event.eventId} remains queued',
    );
    return false;
  }

  /// Forces an immediate flush of all queued events.
  ///
  /// This is called automatically by the periodic timer, but can also
  /// be called manually (e.g., when the app is about to close).
  Future<void> flush() async {
    if (_isFlushing) {
      RedditPixelLogger.debug('Flush already in progress, skipping');
      return;
    }

    _isFlushing = true;

    try {
      // Check connectivity first
      if (!await _isOnline()) {
        RedditPixelLogger.debug('Offline - skipping flush');
        return;
      }

      // Get pending events
      final pendingCount = await _queue.pendingCount;
      if (pendingCount == 0) {
        RedditPixelLogger.debug('No pending events to flush');
        return;
      }

      RedditPixelLogger.debug('Flushing $pendingCount pending events');

      // Process in batches
      while (true) {
        final batch = await _queue.dequeue(maxBatch: _maxBatchSize);
        if (batch.isEmpty) break;

        final success = await _sendEvents(batch);

        if (success) {
          final eventIds = batch.map((e) => e.eventId).toList();
          await _queue.markSent(eventIds);
          RedditPixelLogger.debug('Sent batch of ${batch.length} events');
        } else {
          // Stop processing on failure - events remain queued
          RedditPixelLogger.debug(
            'Batch send failed - ${batch.length} events remain queued',
          );
          break;
        }
      }
    } finally {
      _isFlushing = false;
    }
  }

  Future<bool> _sendEvents(List<RedditEvent> events) async {
    if (events.isEmpty) return true;

    // Normalize user data for each event
    final normalizedEvents = await Future.wait(
      events.map(_normalizeEvent),
    );

    // Build payload
    final payload = {
      'events': normalizedEvents,
      if (_testMode) 'test_mode': true,
    };

    // Send via transport
    final result = await _transport.send(_pixelId, payload);

    return switch (result) {
      TransportSuccess() => true,
      TransportFailure() => false,
    };
  }

  Future<Map<String, dynamic>> _normalizeEvent(RedditEvent event) async {
    final json = event.toJson();

    // Normalize user data if present
    final userData = event.userData;
    if (userData != null) {
      final normalized = await RedditNormalizer.normalizeUserData(userData);
      json['user'] = normalized.toJson();
      json.remove('user_data'); // Remove raw user data
    }

    return json;
  }

  Future<bool> _isOnline() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result.any(
        (r) => r != ConnectivityResult.none,
      );
    } on Exception {
      // If we can't check connectivity, assume online
      RedditPixelLogger.debug('Connectivity check failed, assuming online');
      return true;
    }
  }
}
