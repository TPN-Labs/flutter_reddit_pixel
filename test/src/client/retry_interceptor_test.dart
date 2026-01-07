import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:reddit_pixel/src/client/retry_interceptor.dart';

class MockDio extends Mock implements Dio {}

class FakeRequestOptions extends Fake implements RequestOptions {}

class FakeOptions extends Fake implements Options {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeRequestOptions());
    registerFallbackValue(FakeOptions());
  });

  group('RetryInterceptor', () {
    late MockDio mockDio;
    late RetryInterceptor interceptor;

    setUp(() {
      mockDio = MockDio();
      interceptor = RetryInterceptor(dio: mockDio);
    });

    group('constructor', () {
      test('has default maxRetries of 3', () {
        final interceptor = RetryInterceptor(dio: mockDio);
        expect(interceptor.maxRetries, equals(3));
      });

      test('has default baseDelay of 1 second', () {
        final interceptor = RetryInterceptor(dio: mockDio);
        expect(interceptor.baseDelay, equals(const Duration(seconds: 1)));
      });

      test('accepts custom maxRetries', () {
        final interceptor = RetryInterceptor(dio: mockDio, maxRetries: 5);
        expect(interceptor.maxRetries, equals(5));
      });

      test('accepts custom baseDelay', () {
        final interceptor = RetryInterceptor(
          dio: mockDio,
          baseDelay: const Duration(milliseconds: 500),
        );
        expect(
          interceptor.baseDelay,
          equals(const Duration(milliseconds: 500)),
        );
      });

      test('stores dio instance', () {
        final interceptor = RetryInterceptor(dio: mockDio);
        expect(interceptor.dio, equals(mockDio));
      });
    });

    group('retry behavior on server errors (5xx)', () {
      test('retries on 500 Internal Server Error', () async {
        final requestOptions = RequestOptions(path: '/test');
        final response = Response(
          requestOptions: requestOptions,
          statusCode: 500,
        );
        final error = DioException(
          requestOptions: requestOptions,
          response: response,
        );

        when(
          () => mockDio.request<dynamic>(
            any(),
            data: any(named: 'data'),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: requestOptions,
            statusCode: 200,
          ),
        );

        final interceptor = RetryInterceptor(
          dio: mockDio,
          baseDelay: Duration.zero,
        );
        final handler = ErrorInterceptorHandler();

        await interceptor.onError(error, handler);

        verify(
          () => mockDio.request<dynamic>(
            any(),
            data: any(named: 'data'),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          ),
        ).called(1);
      });

      test('retries on 502 Bad Gateway', () async {
        final requestOptions = RequestOptions(path: '/test');
        final response = Response(
          requestOptions: requestOptions,
          statusCode: 502,
        );
        final error = DioException(
          requestOptions: requestOptions,
          response: response,
        );

        when(
          () => mockDio.request<dynamic>(
            any(),
            data: any(named: 'data'),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: requestOptions,
            statusCode: 200,
          ),
        );

        final interceptor = RetryInterceptor(
          dio: mockDio,
          baseDelay: Duration.zero,
        );
        final handler = ErrorInterceptorHandler();

        await interceptor.onError(error, handler);

        verify(
          () => mockDio.request<dynamic>(
            any(),
            data: any(named: 'data'),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          ),
        ).called(1);
      });

      test('retries on 503 Service Unavailable', () async {
        final requestOptions = RequestOptions(path: '/test');
        final response = Response(
          requestOptions: requestOptions,
          statusCode: 503,
        );
        final error = DioException(
          requestOptions: requestOptions,
          response: response,
        );

        when(
          () => mockDio.request<dynamic>(
            any(),
            data: any(named: 'data'),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: requestOptions,
            statusCode: 200,
          ),
        );

        final interceptor = RetryInterceptor(
          dio: mockDio,
          baseDelay: Duration.zero,
        );
        final handler = ErrorInterceptorHandler();

        await interceptor.onError(error, handler);

        verify(
          () => mockDio.request<dynamic>(
            any(),
            data: any(named: 'data'),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          ),
        ).called(1);
      });

      test('retries on 599 status code', () async {
        final requestOptions = RequestOptions(path: '/test');
        final response = Response(
          requestOptions: requestOptions,
          statusCode: 599,
        );
        final error = DioException(
          requestOptions: requestOptions,
          response: response,
        );

        when(
          () => mockDio.request<dynamic>(
            any(),
            data: any(named: 'data'),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: requestOptions,
            statusCode: 200,
          ),
        );

        final interceptor = RetryInterceptor(
          dio: mockDio,
          baseDelay: Duration.zero,
        );
        final handler = ErrorInterceptorHandler();

        await interceptor.onError(error, handler);

        verify(
          () => mockDio.request<dynamic>(
            any(),
            data: any(named: 'data'),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          ),
        ).called(1);
      });
    });

    group('retry count tracking', () {
      test('increments retry count in request options', () async {
        final requestOptions = RequestOptions(
          path: '/test',
          extra: {},
        );
        final response = Response(
          requestOptions: requestOptions,
          statusCode: 500,
        );
        final error = DioException(
          requestOptions: requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
        );

        when(
          () => mockDio.request<dynamic>(
            any(),
            data: any(named: 'data'),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: requestOptions,
            statusCode: 200,
          ),
        );

        final interceptor = RetryInterceptor(
          dio: mockDio,
          baseDelay: Duration.zero,
        );

        final handler = ErrorInterceptorHandler();

        await interceptor.onError(error, handler);

        final captured = verify(
          () => mockDio.request<dynamic>(
            any(),
            data: any(named: 'data'),
            queryParameters: any(named: 'queryParameters'),
            options: captureAny(named: 'options'),
          ),
        ).captured;

        expect(captured, isNotEmpty);
        final options = captured.first as Options;
        expect(options.extra?['retry_count'], equals(1));
      });
    });

    group('request cloning', () {
      test('preserves original request method', () async {
        final requestOptions = RequestOptions(
          path: '/test',
          method: 'POST',
        );
        final response = Response(
          requestOptions: requestOptions,
          statusCode: 500,
        );
        final error = DioException(
          requestOptions: requestOptions,
          response: response,
        );

        when(
          () => mockDio.request<dynamic>(
            any(),
            data: any(named: 'data'),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: requestOptions,
            statusCode: 200,
          ),
        );

        final interceptor = RetryInterceptor(
          dio: mockDio,
          baseDelay: Duration.zero,
        );
        final handler = ErrorInterceptorHandler();

        await interceptor.onError(error, handler);

        final captured = verify(
          () => mockDio.request<dynamic>(
            any(),
            data: any(named: 'data'),
            queryParameters: any(named: 'queryParameters'),
            options: captureAny(named: 'options'),
          ),
        ).captured;

        final options = captured.first as Options;
        expect(options.method, equals('POST'));
      });

      test('preserves original request headers', () async {
        final requestOptions = RequestOptions(
          path: '/test',
          headers: {'Authorization': 'Bearer token123'},
        );
        final response = Response(
          requestOptions: requestOptions,
          statusCode: 500,
        );
        final error = DioException(
          requestOptions: requestOptions,
          response: response,
        );

        when(
          () => mockDio.request<dynamic>(
            any(),
            data: any(named: 'data'),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: requestOptions,
            statusCode: 200,
          ),
        );

        final interceptor = RetryInterceptor(
          dio: mockDio,
          baseDelay: Duration.zero,
        );
        final handler = ErrorInterceptorHandler();

        await interceptor.onError(error, handler);

        final captured = verify(
          () => mockDio.request<dynamic>(
            any(),
            data: any(named: 'data'),
            queryParameters: any(named: 'queryParameters'),
            options: captureAny(named: 'options'),
          ),
        ).captured;

        final options = captured.first as Options;
        expect(options.headers?['Authorization'], equals('Bearer token123'));
      });

      test('preserves original request data', () async {
        final requestData = {'key': 'value'};
        final requestOptions = RequestOptions(
          path: '/test',
          data: requestData,
        );
        final response = Response(
          requestOptions: requestOptions,
          statusCode: 500,
        );
        final error = DioException(
          requestOptions: requestOptions,
          response: response,
        );

        when(
          () => mockDio.request<dynamic>(
            any(),
            data: any(named: 'data'),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: requestOptions,
            statusCode: 200,
          ),
        );

        final interceptor = RetryInterceptor(
          dio: mockDio,
          baseDelay: Duration.zero,
        );
        final handler = ErrorInterceptorHandler();

        await interceptor.onError(error, handler);

        verify(
          () => mockDio.request<dynamic>(
            any(),
            data: requestData,
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          ),
        ).called(1);
      });

      test('preserves original query parameters', () async {
        final queryParams = {'page': '1', 'limit': '10'};
        final requestOptions = RequestOptions(
          path: '/test',
          queryParameters: queryParams,
        );
        final response = Response(
          requestOptions: requestOptions,
          statusCode: 500,
        );
        final error = DioException(
          requestOptions: requestOptions,
          response: response,
        );

        when(
          () => mockDio.request<dynamic>(
            any(),
            data: any(named: 'data'),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: requestOptions,
            statusCode: 200,
          ),
        );

        final interceptor = RetryInterceptor(
          dio: mockDio,
          baseDelay: Duration.zero,
        );
        final handler = ErrorInterceptorHandler();

        await interceptor.onError(error, handler);

        verify(
          () => mockDio.request<dynamic>(
            any(),
            data: any(named: 'data'),
            queryParameters: queryParams,
            options: any(named: 'options'),
          ),
        ).called(1);
      });

      test('preserves original path', () async {
        final requestOptions = RequestOptions(path: '/api/v3/events');
        final response = Response(
          requestOptions: requestOptions,
          statusCode: 500,
        );
        final error = DioException(
          requestOptions: requestOptions,
          response: response,
        );

        when(
          () => mockDio.request<dynamic>(
            any(),
            data: any(named: 'data'),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: requestOptions,
            statusCode: 200,
          ),
        );

        final interceptor = RetryInterceptor(
          dio: mockDio,
          baseDelay: Duration.zero,
        );
        final handler = ErrorInterceptorHandler();

        await interceptor.onError(error, handler);

        verify(
          () => mockDio.request<dynamic>(
            '/api/v3/events',
            data: any(named: 'data'),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          ),
        ).called(1);
      });
    });

    group('exponential backoff calculation', () {
      test('first retry has 1x base delay', () async {
        final requestOptions = RequestOptions(path: '/test');
        final response = Response(
          requestOptions: requestOptions,
          statusCode: 500,
        );
        final error = DioException(
          requestOptions: requestOptions,
          response: response,
        );

        when(
          () => mockDio.request<dynamic>(
            any(),
            data: any(named: 'data'),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: requestOptions,
            statusCode: 200,
          ),
        );

        final interceptor = RetryInterceptor(
          dio: mockDio,
          baseDelay: const Duration(milliseconds: 10),
        );
        final handler = ErrorInterceptorHandler();

        final stopwatch = Stopwatch()..start();
        await interceptor.onError(error, handler);
        stopwatch.stop();

        // Should wait approximately 10ms (1 * base)
        expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(8));
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
      });
    });
  });
}
