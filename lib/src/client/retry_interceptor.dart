import 'dart:async';

import 'package:dio/dio.dart';
import 'package:reddit_pixel/src/core/logger.dart';

/// Dio interceptor that implements exponential backoff retry for server errors.
///
/// This interceptor automatically retries requests that fail with 5xx status
/// codes using exponential backoff delays. Client errors (4xx) are not retried
/// as they indicate issues with the request itself.
///
/// Retry schedule (default):
/// - Attempt 1: Immediate
/// - Attempt 2: After 1 second
/// - Attempt 3: After 2 seconds
/// - Attempt 4: After 4 seconds
///
/// Example:
/// ```dart
/// final dio = Dio();
/// dio.interceptors.add(RetryInterceptor(dio: dio));
/// ```
class RetryInterceptor extends Interceptor {
  /// Creates a retry interceptor.
  ///
  /// Parameters:
  /// - [dio]: The Dio instance to use for retries
  /// - [maxRetries]: Maximum number of retry attempts (default: 3)
  /// - [baseDelay]: Initial delay before first retry (default: 1 second)
  RetryInterceptor({
    required this.dio,
    this.maxRetries = 3,
    this.baseDelay = const Duration(seconds: 1),
  });

  /// The Dio instance used for retries.
  final Dio dio;

  /// Maximum number of retry attempts.
  final int maxRetries;

  /// Base delay for exponential backoff.
  final Duration baseDelay;

  /// Key for tracking retry count in request options.
  static const _retryCountKey = 'retry_count';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final statusCode = err.response?.statusCode;
    final currentRetry = err.requestOptions.extra[_retryCountKey] as int? ?? 0;

    // Only retry on server errors (5xx) and if we haven't exceeded max retries
    if (_shouldRetry(statusCode) && currentRetry < maxRetries) {
      final nextRetry = currentRetry + 1;
      final delay = _calculateDelay(nextRetry);

      RedditPixelLogger.debug(
        'Request failed with $statusCode. '
        'Retrying in ${delay.inMilliseconds}ms '
        '(attempt $nextRetry of $maxRetries)',
      );

      await Future<void>.delayed(delay);

      try {
        // Clone the request with updated retry count
        final options = Options(
          method: err.requestOptions.method,
          headers: err.requestOptions.headers,
          extra: {
            ...err.requestOptions.extra,
            _retryCountKey: nextRetry,
          },
        );

        final response = await dio.request<dynamic>(
          err.requestOptions.path,
          data: err.requestOptions.data,
          queryParameters: err.requestOptions.queryParameters,
          options: options,
        );

        handler.resolve(response);
        return;
      } on DioException catch (e) {
        // Let the error propagate for further handling
        handler.next(e);
        return;
      }
    }

    // Don't retry, pass the error through
    handler.next(err);
  }

  bool _shouldRetry(int? statusCode) {
    if (statusCode == null) return false;
    // Retry on server errors (5xx)
    return statusCode >= 500 && statusCode < 600;
  }

  Duration _calculateDelay(int retryCount) {
    // Exponential backoff: 1s, 2s, 4s, 8s...
    final multiplier = 1 << (retryCount - 1); // 2^(retryCount-1)
    return baseDelay * multiplier;
  }
}
