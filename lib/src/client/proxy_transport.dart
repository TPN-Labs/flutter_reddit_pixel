import 'package:dio/dio.dart';
import 'package:reddit_pixel/src/client/retry_interceptor.dart';
import 'package:reddit_pixel/src/client/transport_strategy.dart';
import 'package:reddit_pixel/src/core/logger.dart';

/// Transport that sends events through a proxy server.
///
/// **Recommended for Production:** This transport sends events to your own
/// backend server, which then forwards them to Reddit's API. This keeps
/// your Reddit API token secure on your server.
///
/// Your proxy server should:
/// 1. Receive the event payload from this library
/// 2. Add the Reddit API authorization header
/// 3. Forward the request to Reddit's Conversions API
/// 4. Return the response
///
/// Example proxy endpoint (Node.js/Express):
/// ```javascript
/// app.post('/api/reddit-events/:pixelId', async (req, res) => {
///   const response = await fetch(
///     `https://ads-api.reddit.com/api/v3/pixels/${req.params.pixelId}/conversion_events`,
///     {
///       method: 'POST',
///       headers: {
///         'Content-Type': 'application/json',
///         'Authorization': `Bearer ${process.env.REDDIT_API_TOKEN}`,
///       },
///       body: JSON.stringify(req.body),
///     }
///   );
///   res.status(response.status).json(await response.json());
/// });
/// ```
///
/// Usage:
/// ```dart
/// final transport = ProxyTransport(
///   proxyUrl: 'https://your-server.com/api/reddit-events',
/// );
/// final result = await transport.send(pixelId, payload);
/// // Sends to: https://your-server.com/api/reddit-events/{pixelId}
/// ```
class ProxyTransport implements RedditTransport {
  /// Creates a proxy transport.
  ///
  /// Parameters:
  /// - [proxyUrl]: Base URL of your proxy server endpoint.
  ///   The pixel ID will be appended as a path segment.
  /// - [headers]: Additional headers to include in requests.
  /// - [connectTimeout]: Connection timeout (default: 30 seconds).
  /// - [receiveTimeout]: Response timeout (default: 30 seconds).
  ProxyTransport({
    required String proxyUrl,
    Map<String, String>? headers,
    Duration? connectTimeout,
    Duration? receiveTimeout,
  })  : _proxyUrl = proxyUrl.endsWith('/') ? proxyUrl : '$proxyUrl/',
        _dio = Dio(
          BaseOptions(
            connectTimeout: connectTimeout ?? const Duration(seconds: 30),
            receiveTimeout: receiveTimeout ?? const Duration(seconds: 30),
            headers: {
              'Content-Type': 'application/json',
              ...?headers,
            },
          ),
        ) {
    _dio.interceptors.add(RetryInterceptor(dio: _dio));

    RedditPixelLogger.info(
      'ProxyTransport configured with endpoint: $_proxyUrl',
    );
  }

  final String _proxyUrl;
  final Dio _dio;

  @override
  Future<TransportResult> send(
    String pixelId,
    Map<String, dynamic> payload,
  ) async {
    final url = '$_proxyUrl$pixelId';

    final events = payload['events'] as List<dynamic>?;
    RedditPixelLogger.debug(
      'ProxyTransport: Sending ${events?.length ?? 0} events to $url',
    );

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        url,
        data: payload,
      );

      RedditPixelLogger.debug(
        'ProxyTransport: Response ${response.statusCode}',
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
        'ProxyTransport: Request failed - $message',
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

  /// The configured proxy URL (for debugging).
  String get proxyUrl => _proxyUrl;
}
