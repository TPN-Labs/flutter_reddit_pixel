import 'package:reddit_pixel/src/domain/user_data.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Base sealed class for all Reddit conversion events.
///
/// Reddit supports both standard event types (Purchase, SignUp, Lead, etc.)
/// and custom events. Each event captures:
/// - When the event occurred ([eventAt])
/// - A unique identifier ([eventId])
/// - Optional user data for attribution ([userData])
/// - Optional custom data ([customData])
///
/// Use the specific event subclasses for standard events, or [CustomEvent]
/// for custom event tracking.
///
/// Example:
/// ```dart
/// final event = PurchaseEvent(
///   value: 99.99,
///   currency: 'USD',
///   userData: RedditUserData(email: 'user@example.com'),
/// );
///
/// await RedditPixel.instance.track(event);
/// ```
sealed class RedditEvent {
  /// Creates a new Reddit event.
  ///
  /// If [eventAt] is not provided, the current time is used.
  /// If [eventId] is not provided, a UUID v4 is generated.
  RedditEvent({
    DateTime? eventAt,
    String? eventId,
    this.userData,
    this.customData,
  })  : eventAt = eventAt ?? DateTime.now(),
        eventId = eventId ?? _uuid.v4();

  /// The name of this event type for the Reddit API.
  String get eventName;

  /// When the event occurred.
  ///
  /// This timestamp is captured at event creation, not at send time,
  /// to ensure accurate attribution even when events are queued.
  final DateTime eventAt;

  /// Unique identifier for this event.
  ///
  /// Used for deduplication by Reddit's API.
  final String eventId;

  /// User data for attribution.
  ///
  /// Include as much user data as available to improve attribution accuracy.
  /// PII fields will be normalized and hashed before sending.
  final RedditUserData? userData;

  /// Custom data to include with the event.
  ///
  /// This can include any additional context about the event.
  final Map<String, dynamic>? customData;

  /// Converts this event to a JSON map for the Reddit API.
  Map<String, dynamic> toJson() {
    return {
      'event_name': eventName,
      'event_at': eventAt.toUtc().toIso8601String(),
      'event_metadata': {
        'event_id': eventId,
        'action_source': 'APP',
        if (customData != null) 'custom_data': customData,
      },
      if (userData != null) 'user_data': userData!.toJson(),
    };
  }

  /// Creates a [RedditEvent] from a JSON map.
  ///
  /// This factory handles all event type variants based on [event_name].
  factory RedditEvent.fromJson(Map<String, dynamic> json) {
    final eventName = json['event_name'] as String;
    final eventAt = DateTime.parse(json['event_at'] as String);
    final metadata = json['event_metadata'] as Map<String, dynamic>?;
    final eventId = metadata?['event_id'] as String?;
    final customData = metadata?['custom_data'] as Map<String, dynamic>?;
    final userDataJson = json['user_data'] as Map<String, dynamic>?;
    final userData =
        userDataJson != null ? RedditUserData.fromJson(userDataJson) : null;

    return switch (eventName) {
      'Purchase' => PurchaseEvent._fromJson(
          eventAt: eventAt,
          eventId: eventId,
          userData: userData,
          customData: customData,
        ),
      'SignUp' => SignUpEvent(
          eventAt: eventAt,
          eventId: eventId,
          userData: userData,
          customData: customData,
        ),
      'Lead' => LeadEvent(
          eventAt: eventAt,
          eventId: eventId,
          userData: userData,
          customData: customData,
        ),
      'AddToCart' => AddToCartEvent._fromJson(
          eventAt: eventAt,
          eventId: eventId,
          userData: userData,
          customData: customData,
        ),
      'AddToWishlist' => AddToWishlistEvent._fromJson(
          eventAt: eventAt,
          eventId: eventId,
          userData: userData,
          customData: customData,
        ),
      'Search' => SearchEvent._fromJson(
          eventAt: eventAt,
          eventId: eventId,
          userData: userData,
          customData: customData,
        ),
      'ViewContent' => ViewContentEvent._fromJson(
          eventAt: eventAt,
          eventId: eventId,
          userData: userData,
          customData: customData,
        ),
      'PageVisit' => PageVisitEvent._fromJson(
          eventAt: eventAt,
          eventId: eventId,
          userData: userData,
          customData: customData,
        ),
      _ => CustomEvent(
          customEventName: eventName,
          eventAt: eventAt,
          eventId: eventId,
          userData: userData,
          customData: customData,
        ),
    };
  }
}

/// A purchase conversion event.
///
/// Track when a user completes a purchase. This is one of the most valuable
/// events for Reddit ad attribution.
///
/// Example:
/// ```dart
/// final event = PurchaseEvent(
///   value: 49.99,
///   currency: 'USD',
///   itemCount: 2,
///   userData: RedditUserData(email: 'buyer@example.com'),
/// );
/// ```
final class PurchaseEvent extends RedditEvent {
  /// Creates a purchase event.
  PurchaseEvent({
    this.value,
    this.currency,
    this.itemCount,
    super.eventAt,
    super.eventId,
    super.userData,
    super.customData,
  });

  factory PurchaseEvent._fromJson({
    required DateTime eventAt,
    String? eventId,
    RedditUserData? userData,
    Map<String, dynamic>? customData,
  }) {
    return PurchaseEvent(
      value: customData?['value'] as double?,
      currency: customData?['currency'] as String?,
      itemCount: customData?['item_count'] as int?,
      eventAt: eventAt,
      eventId: eventId,
      userData: userData,
    );
  }

  @override
  String get eventName => 'Purchase';

  /// The monetary value of the purchase.
  final double? value;

  /// The currency code (ISO 4217, e.g., 'USD', 'EUR').
  final String? currency;

  /// The number of items purchased.
  final int? itemCount;

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    final metadata = json['event_metadata'] as Map<String, dynamic>;
    metadata['custom_data'] = {
      ...?customData,
      if (value != null) 'value': value,
      if (currency != null) 'currency': currency,
      if (itemCount != null) 'item_count': itemCount,
    };
    return json;
  }
}

/// A sign-up conversion event.
///
/// Track when a user creates an account or registers.
///
/// Example:
/// ```dart
/// final event = SignUpEvent(
///   userData: RedditUserData(
///     email: 'newuser@example.com',
///     externalId: 'user-456',
///   ),
/// );
/// ```
final class SignUpEvent extends RedditEvent {
  /// Creates a sign-up event.
  SignUpEvent({
    super.eventAt,
    super.eventId,
    super.userData,
    super.customData,
  });

  @override
  String get eventName => 'SignUp';
}

/// A lead generation conversion event.
///
/// Track when a user submits a lead form, requests a quote, or shows
/// intent to purchase.
///
/// Example:
/// ```dart
/// final event = LeadEvent(
///   userData: RedditUserData(email: 'lead@example.com'),
///   customData: {'lead_type': 'demo_request'},
/// );
/// ```
final class LeadEvent extends RedditEvent {
  /// Creates a lead event.
  LeadEvent({
    super.eventAt,
    super.eventId,
    super.userData,
    super.customData,
  });

  @override
  String get eventName => 'Lead';
}

/// An add-to-cart conversion event.
///
/// Track when a user adds an item to their shopping cart.
///
/// Example:
/// ```dart
/// final event = AddToCartEvent(
///   value: 29.99,
///   currency: 'USD',
///   itemCount: 1,
/// );
/// ```
final class AddToCartEvent extends RedditEvent {
  /// Creates an add-to-cart event.
  AddToCartEvent({
    this.value,
    this.currency,
    this.itemCount,
    super.eventAt,
    super.eventId,
    super.userData,
    super.customData,
  });

  factory AddToCartEvent._fromJson({
    required DateTime eventAt,
    String? eventId,
    RedditUserData? userData,
    Map<String, dynamic>? customData,
  }) {
    return AddToCartEvent(
      value: customData?['value'] as double?,
      currency: customData?['currency'] as String?,
      itemCount: customData?['item_count'] as int?,
      eventAt: eventAt,
      eventId: eventId,
      userData: userData,
    );
  }

  @override
  String get eventName => 'AddToCart';

  /// The monetary value of items added.
  final double? value;

  /// The currency code (ISO 4217).
  final String? currency;

  /// The number of items added.
  final int? itemCount;

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    final metadata = json['event_metadata'] as Map<String, dynamic>;
    metadata['custom_data'] = {
      ...?customData,
      if (value != null) 'value': value,
      if (currency != null) 'currency': currency,
      if (itemCount != null) 'item_count': itemCount,
    };
    return json;
  }
}

/// An add-to-wishlist conversion event.
///
/// Track when a user adds an item to their wishlist or favorites.
///
/// Example:
/// ```dart
/// final event = AddToWishlistEvent(
///   value: 199.99,
///   currency: 'USD',
/// );
/// ```
final class AddToWishlistEvent extends RedditEvent {
  /// Creates an add-to-wishlist event.
  AddToWishlistEvent({
    this.value,
    this.currency,
    super.eventAt,
    super.eventId,
    super.userData,
    super.customData,
  });

  factory AddToWishlistEvent._fromJson({
    required DateTime eventAt,
    String? eventId,
    RedditUserData? userData,
    Map<String, dynamic>? customData,
  }) {
    return AddToWishlistEvent(
      value: customData?['value'] as double?,
      currency: customData?['currency'] as String?,
      eventAt: eventAt,
      eventId: eventId,
      userData: userData,
    );
  }

  @override
  String get eventName => 'AddToWishlist';

  /// The monetary value of the item.
  final double? value;

  /// The currency code (ISO 4217).
  final String? currency;

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    final metadata = json['event_metadata'] as Map<String, dynamic>;
    metadata['custom_data'] = {
      ...?customData,
      if (value != null) 'value': value,
      if (currency != null) 'currency': currency,
    };
    return json;
  }
}

/// A search conversion event.
///
/// Track when a user performs a search in your app.
///
/// Example:
/// ```dart
/// final event = SearchEvent(
///   searchString: 'wireless headphones',
/// );
/// ```
final class SearchEvent extends RedditEvent {
  /// Creates a search event.
  SearchEvent({
    this.searchString,
    super.eventAt,
    super.eventId,
    super.userData,
    super.customData,
  });

  factory SearchEvent._fromJson({
    required DateTime eventAt,
    String? eventId,
    RedditUserData? userData,
    Map<String, dynamic>? customData,
  }) {
    return SearchEvent(
      searchString: customData?['search_string'] as String?,
      eventAt: eventAt,
      eventId: eventId,
      userData: userData,
    );
  }

  @override
  String get eventName => 'Search';

  /// The search query string.
  final String? searchString;

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    final metadata = json['event_metadata'] as Map<String, dynamic>;
    metadata['custom_data'] = {
      ...?customData,
      if (searchString != null) 'search_string': searchString,
    };
    return json;
  }
}

/// A view content conversion event.
///
/// Track when a user views a specific piece of content (product page,
/// article, etc.).
///
/// Example:
/// ```dart
/// final event = ViewContentEvent(
///   contentId: 'product-123',
///   contentName: 'Premium Headphones',
/// );
/// ```
final class ViewContentEvent extends RedditEvent {
  /// Creates a view content event.
  ViewContentEvent({
    this.contentId,
    this.contentName,
    super.eventAt,
    super.eventId,
    super.userData,
    super.customData,
  });

  factory ViewContentEvent._fromJson({
    required DateTime eventAt,
    String? eventId,
    RedditUserData? userData,
    Map<String, dynamic>? customData,
  }) {
    return ViewContentEvent(
      contentId: customData?['content_id'] as String?,
      contentName: customData?['content_name'] as String?,
      eventAt: eventAt,
      eventId: eventId,
      userData: userData,
    );
  }

  @override
  String get eventName => 'ViewContent';

  /// The unique identifier for the content.
  final String? contentId;

  /// The human-readable name of the content.
  final String? contentName;

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    final metadata = json['event_metadata'] as Map<String, dynamic>;
    metadata['custom_data'] = {
      ...?customData,
      if (contentId != null) 'content_id': contentId,
      if (contentName != null) 'content_name': contentName,
    };
    return json;
  }
}

/// A page visit conversion event.
///
/// Track when a user visits a specific page or screen in your app.
///
/// Example:
/// ```dart
/// final event = PageVisitEvent(
///   pageUrl: '/checkout',
/// );
/// ```
final class PageVisitEvent extends RedditEvent {
  /// Creates a page visit event.
  PageVisitEvent({
    this.pageUrl,
    super.eventAt,
    super.eventId,
    super.userData,
    super.customData,
  });

  factory PageVisitEvent._fromJson({
    required DateTime eventAt,
    String? eventId,
    RedditUserData? userData,
    Map<String, dynamic>? customData,
  }) {
    return PageVisitEvent(
      pageUrl: customData?['page_url'] as String?,
      eventAt: eventAt,
      eventId: eventId,
      userData: userData,
    );
  }

  @override
  String get eventName => 'PageVisit';

  /// The URL or path of the visited page.
  final String? pageUrl;

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    final metadata = json['event_metadata'] as Map<String, dynamic>;
    metadata['custom_data'] = {
      ...?customData,
      if (pageUrl != null) 'page_url': pageUrl,
    };
    return json;
  }
}

/// A custom conversion event.
///
/// Use this for event types not covered by the standard events.
/// The [customEventName] will be used as the event name in the Reddit API.
///
/// Example:
/// ```dart
/// final event = CustomEvent(
///   customEventName: 'VideoWatched',
///   customData: {
///     'video_id': 'vid-123',
///     'duration_seconds': 120,
///   },
/// );
/// ```
final class CustomEvent extends RedditEvent {
  /// Creates a custom event.
  CustomEvent({
    required this.customEventName,
    super.eventAt,
    super.eventId,
    super.userData,
    super.customData,
  });

  @override
  String get eventName => customEventName;

  /// The custom event name.
  final String customEventName;
}
