import 'package:dio/dio.dart';
import 'package:reddit_pixel/src/client/retry_interceptor.dart';
import 'package:reddit_pixel/src/client/transport_strategy.dart';
import 'package:reddit_pixel/src/core/logger.dart';

/// Transport that sends events directly to Reddit's Conversions API.
///
/// **Security Warning:** This transport requires embedding your Reddit API
/// access token in the mobile application. This exposes your token to potential
/// extraction from the app binary.
///
/// **Recommendation:** Use `ProxyTransport` for production applications.
/// [DirectTransport] is suitable for:
/// - Development and testing
/// - Proof-of-concept implementations
/// - Scenarios where server infrastructure is not available
///
/// Example:
/// ```dart
/// final transport = DirectTransport(token: 'your-reddit-api-token');
/// final result = await transport.send(pixelId, payload);
/// ```
class DirectTransport implements RedditTransport {
  /// Creates a direct transport.
  ///
  /// Prints a security warning to the console on creation.
  DirectTransport({
    required String token,
    Duration? connectTimeout,
    Duration? receiveTimeout,
  })  : _token = token,
        _dio = Dio(
          BaseOptions(
            baseUrl: _baseUrl,
            connectTimeout: connectTimeout ?? const Duration(seconds: 30),
            receiveTimeout: receiveTimeout ?? const Duration(seconds: 30),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          ),
        ) {
    _dio.interceptors.add(RetryInterceptor(dio: _dio));
    _printSecurityWarning();
  }

  static const _baseUrl = 'https://ads-api.reddit.com';

  final String _token;
  final Dio _dio;

  void _printSecurityWarning() {
    RedditPixelLogger.warning(
      '⚠️  SECURITY WARNING: DirectTransport is configured.\n'
      '   Your Reddit API token is embedded in the app binary.\n'
      '   This token can potentially be extracted by malicious actors.\n'
      '   For production apps, use ProxyTransport with a backend server\n'
      '   that securely stores and uses the token.',
    );
  }

  @override
  Future<TransportResult> send(
    String pixelId,
    Map<String, dynamic> payload,
  ) async {
    final path = '/api/v3/pixels/$pixelId/conversion_events';

    final events = payload['events'] as List<dynamic>?;
    RedditPixelLogger.debug(
      'DirectTransport: Sending ${events?.length ?? 0} events to $path',
    );

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        data: payload,
      );

      RedditPixelLogger.debug(
        'DirectTransport: Response ${response.statusCode}',
      );

      return TransportSuccess(
        statusCode: response.statusCode ?? 200,
        responseBody: response.data?.toString(),
      );
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final message = _extractErrorMessage(e);
      final isRetryable = statusCode != null && statusCode >= 500;

      RedditPixelLogger.error(
        'DirectTransport: Request failed - $message',
        error: e,
      );

      return TransportFailure(
        message: message,
        statusCode: statusCode,
        error: e,
        isRetryable: isRetryable,
      );
    }
  }

  String _extractErrorMessage(DioException e) {
    // Try to extract error message from response
    final responseData = e.response?.data;
    if (responseData is Map<String, dynamic>) {
      final error = responseData['error'] as String?;
      final message = responseData['message'] as String?;
      if (error != null) return error;
      if (message != null) return message;
    }

    // Fall back to Dio's message
    return e.message ?? 'Unknown error occurred';
  }

  @override
  void dispose() {
    _dio.close();
  }

  /// The Reddit API token (for debugging purposes only).
  ///
  /// **Warning:** Do not log or expose this value.
  String get token => _token;
}
