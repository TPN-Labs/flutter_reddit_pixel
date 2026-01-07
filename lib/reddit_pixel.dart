/// Reddit Pixel - A privacy-centric Flutter library for Reddit Conversions API.
///
/// This library provides a simple, secure way to track conversion events
/// using Reddit's Conversions API (CAPI) v3.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:reddit_pixel/reddit_pixel.dart';
///
/// // Initialize with proxy mode (recommended for production)
/// await RedditPixel.initialize(
///   pixelId: 'your-pixel-id',
///   proxyUrl: 'https://your-server.com/api/reddit-events',
/// );
///
/// // Track a purchase
/// await RedditPixel.instance.trackPurchase(
///   value: 99.99,
///   currency: 'USD',
///   userData: RedditUserData(email: 'customer@example.com'),
/// );
/// ```
///
/// ## Features
///
/// - **Backend-agnostic**: Use direct mode for development or proxy mode
///   for production security.
/// - **Privacy-centric**: No tracking dependencies by default. IDFA/AAID
///   support requires explicit opt-in via [RedditIdentityProvider].
/// - **Offline-first**: Events are queued locally and sent when online.
/// - **Performance-optimized**: PII hashing runs in isolates to avoid
///   blocking the UI thread.
///
/// ## Transport Modes
///
/// **Proxy Mode (Recommended):**
/// Events are sent to your backend server, which forwards them to Reddit.
/// Your Reddit API token stays secure on your server.
///
/// **Direct Mode:**
/// Events are sent directly to Reddit's API. Your token is embedded in
/// the app binary, which is less secure.
library;

import 'package:hive_flutter/hive_flutter.dart';
import 'package:reddit_pixel/src/client/direct_transport.dart';
import 'package:reddit_pixel/src/client/proxy_transport.dart';
import 'package:reddit_pixel/src/client/transport_strategy.dart';
import 'package:reddit_pixel/src/core/logger.dart';
import 'package:reddit_pixel/src/data/hive_queue.dart';
import 'package:reddit_pixel/src/dispatcher/event_dispatcher.dart';
import 'package:reddit_pixel/src/domain/event.dart';
import 'package:reddit_pixel/src/domain/user_data.dart';
import 'package:reddit_pixel/src/platform/identity_provider.dart';

// Public exports
export 'package:reddit_pixel/src/client/transport_strategy.dart'
    show RedditTransport, TransportFailure, TransportResult, TransportSuccess;
export 'package:reddit_pixel/src/domain/event.dart';
export 'package:reddit_pixel/src/domain/user_data.dart';
export 'package:reddit_pixel/src/platform/identity_provider.dart';

/// Main entry point for the Reddit Pixel library.
///
/// Use [RedditPixel.initialize] to set up the library, then access
/// the singleton instance via [RedditPixel.instance].
///
/// Example:
/// ```dart
/// // Initialize once at app startup
/// await RedditPixel.initialize(
///   pixelId: 'your-pixel-id',
///   proxyUrl: 'https://your-server.com/api/reddit-events',
///   debug: true, // Enable for development
/// );
///
/// // Track events anywhere in your app
/// await RedditPixel.instance.trackPurchase(value: 99.99);
/// ```
class RedditPixel {
  RedditPixel._({
    required String pixelId,
    required RedditTransport transport,
    required HiveEventQueue queue,
    required EventDispatcher dispatcher,
    required RedditIdentityProvider identityProvider,
    required bool testMode,
  })  : _pixelId = pixelId,
        _transport = transport,
        _queue = queue,
        _dispatcher = dispatcher,
        _identityProvider = identityProvider,
        _testMode = testMode;

  static RedditPixel? _instance;

  final String _pixelId;
  final RedditTransport _transport;
  final HiveEventQueue _queue;
  final EventDispatcher _dispatcher;
  final RedditIdentityProvider _identityProvider;
  final bool _testMode;

  /// Returns the singleton instance.
  ///
  /// Throws [StateError] if [initialize] has not been called.
  static RedditPixel get instance {
    if (_instance == null) {
      throw StateError(
        'RedditPixel not initialized. Call RedditPixel.initialize() first.',
      );
    }
    return _instance!;
  }

  /// Whether the library has been initialized.
  static bool get isInitialized => _instance != null;

  /// Initializes the Reddit Pixel library.
  ///
  /// Must be called before using [instance]. Typically called once
  /// at app startup.
  ///
  /// **Parameters:**
  ///
  /// - [pixelId]: Your Reddit Pixel ID (required).
  ///
  /// - [token]: Reddit API access token for direct mode.
  ///   **Warning:** Embeds token in app binary. Use [proxyUrl] instead
  ///   for production.
  ///
  /// - [proxyUrl]: URL of your proxy server for proxy mode (recommended).
  ///   The pixel ID will be appended to this URL.
  ///
  /// - [transport]: Custom transport implementation. If provided,
  ///   [token] and [proxyUrl] are ignored.
  ///
  /// - [identityProvider]: Provider for advertising IDs. Defaults to
  ///   [NullIdentityProvider] (no tracking).
  ///
  /// - [testMode]: If true, events are sent in test mode and won't
  ///   affect production data.
  ///
  /// - [debug]: If true, enables debug logging.
  ///
  /// - [flushInterval]: How often to flush queued events (default: 30s).
  ///
  /// **Example with proxy (recommended):**
  /// ```dart
  /// await RedditPixel.initialize(
  ///   pixelId: 'abc123',
  ///   proxyUrl: 'https://api.myapp.com/reddit-events',
  /// );
  /// ```
  ///
  /// **Example with direct mode (development only):**
  /// ```dart
  /// await RedditPixel.initialize(
  ///   pixelId: 'abc123',
  ///   token: 'your-reddit-api-token',
  ///   testMode: true,
  ///   debug: true,
  /// );
  /// ```
  static Future<void> initialize({
    required String pixelId,
    String? token,
    String? proxyUrl,
    RedditTransport? transport,
    RedditIdentityProvider? identityProvider,
    bool testMode = false,
    bool debug = false,
    Duration flushInterval = const Duration(seconds: 30),
  }) async {
    if (_instance != null) {
      RedditPixelLogger.warning(
        'RedditPixel already initialized. '
        'Call dispose() first to reinitialize.',
      );
      return;
    }

    // Configure logging
    RedditPixelLogger.setDebugMode(enabled: debug);

    RedditPixelLogger.info('Initializing RedditPixel for pixel: $pixelId');

    // Initialize Hive
    await Hive.initFlutter();

    // Create transport
    final effectiveTransport = transport ??
        _createTransport(
          token: token,
          proxyUrl: proxyUrl,
        );

    // Create queue
    final queue = HiveEventQueue();
    await queue.initialize();

    // Create dispatcher
    final dispatcher = EventDispatcher(
      transport: effectiveTransport,
      queue: queue,
      pixelId: pixelId,
      flushInterval: flushInterval,
      testMode: testMode,
    );

    // Start dispatcher
    await dispatcher.start();

    // Create instance
    _instance = RedditPixel._(
      pixelId: pixelId,
      transport: effectiveTransport,
      queue: queue,
      dispatcher: dispatcher,
      identityProvider: identityProvider ?? const NullIdentityProvider(),
      testMode: testMode,
    );

    RedditPixelLogger.info('RedditPixel initialized successfully');
  }

  static RedditTransport _createTransport({
    String? token,
    String? proxyUrl,
  }) {
    if (token != null && proxyUrl != null) {
      RedditPixelLogger.warning(
        'Both token and proxyUrl provided. Using proxyUrl (recommended).',
      );
      return ProxyTransport(proxyUrl: proxyUrl);
    }

    if (proxyUrl != null) {
      return ProxyTransport(proxyUrl: proxyUrl);
    }

    if (token != null) {
      return DirectTransport(token: token);
    }

    throw ArgumentError(
      'Either token, proxyUrl, or transport must be provided.',
    );
  }

  /// Tracks a generic Reddit event.
  ///
  /// Use this method for any [RedditEvent] subclass. For convenience,
  /// prefer the specific track methods like [trackPurchase].
  ///
  /// The event is queued for delivery and sent when online.
  ///
  /// Example:
  /// ```dart
  /// await RedditPixel.instance.track(
  ///   CustomEvent(customEventName: 'VideoWatched'),
  /// );
  /// ```
  Future<void> track(RedditEvent event) async {
    RedditPixelLogger.debug('Tracking event: ${event.eventName}');

    // Enrich with advertising ID if available
    final enrichedEvent = await _enrichWithAdId(event);

    await _dispatcher.sendNow(enrichedEvent);
  }

  /// Tracks a purchase conversion.
  Future<void> trackPurchase({
    double? value,
    String? currency,
    int? itemCount,
    RedditUserData? userData,
    Map<String, dynamic>? customData,
  }) async {
    await track(
      PurchaseEvent(
        value: value,
        currency: currency,
        itemCount: itemCount,
        userData: userData,
        customData: customData,
      ),
    );
  }

  /// Tracks a sign-up conversion.
  Future<void> trackSignUp({
    RedditUserData? userData,
    Map<String, dynamic>? customData,
  }) async {
    await track(
      SignUpEvent(
        userData: userData,
        customData: customData,
      ),
    );
  }

  /// Tracks a lead generation conversion.
  Future<void> trackLead({
    RedditUserData? userData,
    Map<String, dynamic>? customData,
  }) async {
    await track(
      LeadEvent(
        userData: userData,
        customData: customData,
      ),
    );
  }

  /// Tracks an add-to-cart event.
  Future<void> trackAddToCart({
    double? value,
    String? currency,
    int? itemCount,
    RedditUserData? userData,
    Map<String, dynamic>? customData,
  }) async {
    await track(
      AddToCartEvent(
        value: value,
        currency: currency,
        itemCount: itemCount,
        userData: userData,
        customData: customData,
      ),
    );
  }

  /// Tracks an add-to-wishlist event.
  Future<void> trackAddToWishlist({
    double? value,
    String? currency,
    RedditUserData? userData,
    Map<String, dynamic>? customData,
  }) async {
    await track(
      AddToWishlistEvent(
        value: value,
        currency: currency,
        userData: userData,
        customData: customData,
      ),
    );
  }

  /// Tracks a search event.
  Future<void> trackSearch({
    String? searchString,
    RedditUserData? userData,
    Map<String, dynamic>? customData,
  }) async {
    await track(
      SearchEvent(
        searchString: searchString,
        userData: userData,
        customData: customData,
      ),
    );
  }

  /// Tracks a view content event.
  Future<void> trackViewContent({
    String? contentId,
    String? contentName,
    RedditUserData? userData,
    Map<String, dynamic>? customData,
  }) async {
    await track(
      ViewContentEvent(
        contentId: contentId,
        contentName: contentName,
        userData: userData,
        customData: customData,
      ),
    );
  }

  /// Tracks a page visit event.
  Future<void> trackPageVisit({
    String? pageUrl,
    RedditUserData? userData,
    Map<String, dynamic>? customData,
  }) async {
    await track(
      PageVisitEvent(
        pageUrl: pageUrl,
        userData: userData,
        customData: customData,
      ),
    );
  }

  /// Tracks a custom event.
  Future<void> trackCustom(
    String eventName, {
    RedditUserData? userData,
    Map<String, dynamic>? customData,
  }) async {
    await track(
      CustomEvent(
        customEventName: eventName,
        userData: userData,
        customData: customData,
      ),
    );
  }

  /// Forces an immediate flush of all queued events.
  ///
  /// Call this before app termination to ensure all events are sent.
  Future<void> flush() async {
    RedditPixelLogger.debug('Manual flush requested');
    await _dispatcher.flush();
  }

  /// Returns the number of events pending in the queue.
  Future<int> get pendingEventCount => _queue.pendingCount;

  /// Disposes of the library and releases all resources.
  ///
  /// Call [initialize] again to reinitialize after disposal.
  Future<void> dispose() async {
    RedditPixelLogger.info('Disposing RedditPixel');

    await _dispatcher.stop();
    await _queue.dispose();
    _transport.dispose();

    _instance = null;

    RedditPixelLogger.info('RedditPixel disposed');
  }

  /// The configured pixel ID.
  String get pixelId => _pixelId;

  /// Whether test mode is enabled.
  bool get isTestMode => _testMode;

  Future<RedditEvent> _enrichWithAdId(RedditEvent event) async {
    // Check if we can get advertising ID
    final isEnabled = await _identityProvider.isTrackingEnabled();
    if (!isEnabled) return event;

    final adId = await _identityProvider.getAdvertisingId();
    if (adId == null) return event;

    // Determine platform and add appropriate ID
    final currentUserData = event.userData ?? const RedditUserData();

    // For now, we add as both - the API will use what's appropriate
    // A more sophisticated implementation would check the platform
    final enrichedUserData = currentUserData.copyWith(
      idfa: currentUserData.idfa ?? adId,
      aaid: currentUserData.aaid ?? adId,
    );

    // Create new event with enriched user data
    return switch (event) {
      PurchaseEvent(
        :final value,
        :final currency,
        :final itemCount,
        :final eventAt,
        :final eventId,
        :final customData
      ) =>
        PurchaseEvent(
          value: value,
          currency: currency,
          itemCount: itemCount,
          eventAt: eventAt,
          eventId: eventId,
          userData: enrichedUserData,
          customData: customData,
        ),
      SignUpEvent(:final eventAt, :final eventId, :final customData) =>
        SignUpEvent(
          eventAt: eventAt,
          eventId: eventId,
          userData: enrichedUserData,
          customData: customData,
        ),
      LeadEvent(:final eventAt, :final eventId, :final customData) => LeadEvent(
          eventAt: eventAt,
          eventId: eventId,
          userData: enrichedUserData,
          customData: customData,
        ),
      AddToCartEvent(
        :final value,
        :final currency,
        :final itemCount,
        :final eventAt,
        :final eventId,
        :final customData
      ) =>
        AddToCartEvent(
          value: value,
          currency: currency,
          itemCount: itemCount,
          eventAt: eventAt,
          eventId: eventId,
          userData: enrichedUserData,
          customData: customData,
        ),
      AddToWishlistEvent(
        :final value,
        :final currency,
        :final eventAt,
        :final eventId,
        :final customData
      ) =>
        AddToWishlistEvent(
          value: value,
          currency: currency,
          eventAt: eventAt,
          eventId: eventId,
          userData: enrichedUserData,
          customData: customData,
        ),
      SearchEvent(
        :final searchString,
        :final eventAt,
        :final eventId,
        :final customData
      ) =>
        SearchEvent(
          searchString: searchString,
          eventAt: eventAt,
          eventId: eventId,
          userData: enrichedUserData,
          customData: customData,
        ),
      ViewContentEvent(
        :final contentId,
        :final contentName,
        :final eventAt,
        :final eventId,
        :final customData
      ) =>
        ViewContentEvent(
          contentId: contentId,
          contentName: contentName,
          eventAt: eventAt,
          eventId: eventId,
          userData: enrichedUserData,
          customData: customData,
        ),
      PageVisitEvent(
        :final pageUrl,
        :final eventAt,
        :final eventId,
        :final customData
      ) =>
        PageVisitEvent(
          pageUrl: pageUrl,
          eventAt: eventAt,
          eventId: eventId,
          userData: enrichedUserData,
          customData: customData,
        ),
      CustomEvent(
        :final customEventName,
        :final eventAt,
        :final eventId,
        :final customData
      ) =>
        CustomEvent(
          customEventName: customEventName,
          eventAt: eventAt,
          eventId: eventId,
          userData: enrichedUserData,
          customData: customData,
        ),
    };
  }
}
