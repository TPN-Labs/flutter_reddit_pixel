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

/// Main entry point for the Reddit Pixel library.
class RedditPixel {
  RedditPixel._({
    required String pixelId,
    required RedditTransport transport,
    required HiveEventQueue queue,
    required EventDispatcher dispatcher,
    required RedditIdentityProvider identityProvider,
    required bool testMode,
  }) : _pixelId = pixelId,
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

    RedditPixelLogger.setDebugMode(enabled: debug);
    RedditPixelLogger.info('Initializing RedditPixel for pixel: $pixelId');

    await Hive.initFlutter();

    final effectiveTransport =
        transport ??
        _createTransport(
          token: token,
          proxyUrl: proxyUrl,
        );

    final queue = HiveEventQueue();
    await queue.initialize();

    final dispatcher = EventDispatcher(
      transport: effectiveTransport,
      queue: queue,
      pixelId: pixelId,
      flushInterval: flushInterval,
      testMode: testMode,
    );

    await dispatcher.start();

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
  Future<void> track(RedditEvent event) async {
    RedditPixelLogger.debug('Tracking event: ${event.eventName}');

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
  Future<void> flush() async {
    RedditPixelLogger.debug('Manual flush requested');
    await _dispatcher.flush();
  }

  /// Returns the number of events pending in the queue.
  Future<int> get pendingEventCount => _queue.pendingCount;

  /// Disposes of the library and releases all resources.
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
    final isEnabled = await _identityProvider.isTrackingEnabled();
    if (!isEnabled) return event;

    final adId = await _identityProvider.getAdvertisingId();
    if (adId == null) return event;

    final currentUserData = event.userData ?? const RedditUserData();

    final enrichedUserData = currentUserData.copyWith(
      idfa: currentUserData.idfa ?? adId,
      aaid: currentUserData.aaid ?? adId,
    );

    return switch (event) {
      PurchaseEvent(
        :final value,
        :final currency,
        :final itemCount,
        :final eventAt,
        :final eventId,
        :final customData,
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
        :final customData,
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
        :final customData,
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
        :final customData,
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
        :final customData,
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
        :final customData,
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
        :final customData,
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
