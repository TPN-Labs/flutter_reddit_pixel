/// Abstract interface for providing device advertising identifiers.
///
/// This interface enables dependency injection for advertising ID retrieval,
/// allowing the library to remain privacy-centric by default while supporting
/// IDFA/AAID tracking when explicitly configured.
///
/// **Why Dependency Injection?**
///
/// To avoid triggering Apple's App Tracking Transparency (ATT) requirements
/// for apps that don't need user tracking, the library does not depend on
/// `app_tracking_transparency` or `advertising_id` packages directly.
/// Developers who want to use IDFA/AAID must inject their own implementation.
///
/// Example implementation with platform plugins:
/// ```dart
/// import 'package:advertising_id/advertising_id.dart';
/// import 'package:app_tracking_transparency/app_tracking_transparency.dart';
///
/// class AppIdentityProvider implements RedditIdentityProvider {
///   @override
///   Future<String?> getAdvertisingId() async {
///     try {
///       return await AdvertisingId.id(true);
///     } catch (_) {
///       return null;
///     }
///   }
///
///   @override
///   Future<bool> isTrackingEnabled() async {
///     final status =
///         await AppTrackingTransparency.trackingAuthorizationStatus;
///     return status == TrackingStatus.authorized;
///   }
/// }
/// ```
abstract class RedditIdentityProvider {
  /// Returns the device's advertising identifier.
  ///
  /// On iOS, this is the IDFA (Identifier for Advertisers).
  /// On Android, this is the AAID (Android Advertising ID).
  ///
  /// Returns `null` if:
  /// - Tracking is not authorized
  /// - The ID cannot be retrieved
  /// - The user has opted out of personalized ads
  Future<String?> getAdvertisingId();

  /// Returns whether user tracking is enabled and authorized.
  ///
  /// On iOS 14.5+, this should check App Tracking Transparency status.
  /// On Android, this should check if the user has opted out of personalized
  /// ads in device settings.
  ///
  /// Returns `false` if tracking is not authorized or cannot be determined.
  Future<bool> isTrackingEnabled();
}

/// Default identity provider that returns no tracking information.
///
/// This is the default provider used when no custom implementation is
/// injected. It ensures the library operates in privacy-first mode,
/// never collecting advertising identifiers unless explicitly configured.
///
/// Use this provider when:
/// - You don't need advertising ID tracking
/// - You want to minimize privacy implications
/// - You're testing without tracking dependencies
class NullIdentityProvider implements RedditIdentityProvider {
  /// Creates a [NullIdentityProvider] instance.
  const NullIdentityProvider();

  @override
  Future<String?> getAdvertisingId() async => null;

  @override
  Future<bool> isTrackingEnabled() async => false;
}
