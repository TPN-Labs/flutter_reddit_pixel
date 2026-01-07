/// Result of a transport operation.
///
/// This sealed class represents the outcome of sending events to Reddit's
/// API. Use pattern matching to handle success and failure cases.
///
/// Example:
/// ```dart
/// final result = await transport.send(pixelId, payload);
/// switch (result) {
///   case TransportSuccess():
///     print('Events sent successfully');
///   case TransportFailure(:final statusCode, :final message):
///     print('Failed: $statusCode - $message');
/// }
/// ```
sealed class TransportResult {
  const TransportResult();
}

/// Indicates successful event transmission.
final class TransportSuccess extends TransportResult {
  /// Creates a success result.
  const TransportSuccess({
    this.statusCode = 200,
    this.responseBody,
  });

  /// The HTTP status code returned by the server.
  final int statusCode;

  /// The response body, if any.
  final String? responseBody;

  @override
  String toString() => 'TransportSuccess(statusCode: $statusCode)';
}

/// Indicates failed event transmission.
final class TransportFailure extends TransportResult {
  /// Creates a failure result.
  const TransportFailure({
    required this.message,
    this.statusCode,
    this.error,
    this.isRetryable = false,
  });

  /// Human-readable error message.
  final String message;

  /// The HTTP status code, if available.
  final int? statusCode;

  /// The underlying error, if available.
  final Object? error;

  /// Whether this failure is potentially recoverable with a retry.
  ///
  /// Server errors (5xx) are typically retryable, while client errors (4xx)
  /// are not.
  final bool isRetryable;

  @override
  String toString() =>
      'TransportFailure('
      'message: $message, '
      'statusCode: $statusCode, '
      'isRetryable: $isRetryable)';
}

/// Abstract interface for event transport strategies.
///
/// This interface defines the contract for sending events to Reddit's
/// Conversions API. Two implementations are provided:
///
/// - `DirectTransport`: Sends directly to Reddit's API (requires token in app)
/// - `ProxyTransport`: Sends to a proxy server (recommended for production)
///
/// The Strategy Pattern allows switching between transport modes without
/// changing the rest of the library's code.
///
/// Example custom implementation:
/// ```dart
/// class CustomTransport implements RedditTransport {
///   @override
///   Future<TransportResult> send(
///     String pixelId,
///     Map<String, dynamic> payload,
///   ) async {
///     // Custom implementation
///   }
///
///   @override
///   void dispose() {
///     // Cleanup resources
///   }
/// }
/// ```
abstract class RedditTransport {
  /// Sends events to Reddit's Conversions API.
  ///
  /// Parameters:
  /// - [pixelId]: The Reddit pixel ID to send events to
  /// - [payload]: The event payload in Reddit CAPI v3 format
  ///
  /// Returns a [TransportResult] indicating success or failure.
  Future<TransportResult> send(
    String pixelId,
    Map<String, dynamic> payload,
  );

  /// Releases any resources held by this transport.
  ///
  /// Call this when you're done with the transport to clean up
  /// connections and other resources.
  void dispose();
}
