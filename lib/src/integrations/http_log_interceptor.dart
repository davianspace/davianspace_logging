import '../abstractions/log_level.dart';
import '../abstractions/logger.dart';

// ── HttpLogInterceptor ──────────────────────────────────────────────────────

/// A framework-agnostic HTTP logging helper.
///
/// `HttpLogInterceptor` wraps a [Logger] and exposes [onRequest],
/// [onResponse], and [onError] callbacks that can be wired into any HTTP
/// client interceptor without introducing a direct dependency on `dio`,
/// `http`, or any other network package.
///
/// ### Dio example
///
/// ```dart
/// import 'package:dio/dio.dart';
/// import 'package:davianspace_logging/davianspace_logging.dart';
///
/// class DioLoggingInterceptor extends Interceptor {
///   DioLoggingInterceptor(Logger logger)
///       : _http = HttpLogInterceptor(logger);
///   final HttpLogInterceptor _http;
///
///   @override
///   void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
///     _http.onRequest(options.method, options.uri.toString(),
///         headers: Map.from(options.headers));
///     handler.next(options);
///   }
///
///   @override
///   void onResponse(Response response, ResponseInterceptorHandler handler) {
///     _http.onResponse(
///         response.statusCode ?? 0, response.realUri.toString());
///     handler.next(response);
///   }
///
///   @override
///   void onError(DioException err, ErrorInterceptorHandler handler) {
///     _http.onError(
///         err.requestOptions.method, err.requestOptions.uri.toString(),
///         err, err.stackTrace ?? StackTrace.current);
///     handler.next(err);
///   }
/// }
/// ```
///
/// ### `package:http` example
///
/// ```dart
/// import 'package:http/http.dart' as http;
/// import 'package:davianspace_logging/davianspace_logging.dart';
///
/// class LoggingClient extends http.BaseClient {
///   LoggingClient(Logger logger, http.Client inner)
///       : _http = HttpLogInterceptor(logger), _inner = inner;
///   final HttpLogInterceptor _http;
///   final http.Client _inner;
///
///   @override
///   Future<http.StreamedResponse> send(http.BaseRequest request) async {
///     _http.onRequest(request.method, request.url.toString());
///     try {
///       final response = await _inner.send(request);
///       _http.onResponse(response.statusCode, request.url.toString());
///       return response;
///     } catch (e, st) {
///       _http.onError(request.method, request.url.toString(), e, st);
///       rethrow;
///     }
///   }
/// }
/// ```
class HttpLogInterceptor {
  /// Creates an [HttpLogInterceptor].
  ///
  /// `logger` receives all HTTP log entries.
  ///
  /// [requestLevel] controls the level used for outgoing request entries.
  /// Defaults to [LogLevel.debug].
  ///
  /// [responseLevel] controls the level used for received response entries.
  /// Defaults to [LogLevel.debug].
  ///
  /// [errorLevel] controls the level used for HTTP error entries.
  /// Defaults to [LogLevel.error].
  ///
  /// Set `logHeaders` to `true` to include request/response headers in the
  /// structured `properties`. **Do not enable in production** when headers
  /// may contain secrets such as `Authorization` tokens.
  ///
  /// Set `logBody` to `true` to include request/response bodies in the
  /// structured `properties`. **Use with caution** — bodies may be large or
  /// contain sensitive data.
  const HttpLogInterceptor(
    this._logger, {
    LogLevel requestLevel = LogLevel.debug,
    LogLevel responseLevel = LogLevel.debug,
    LogLevel errorLevel = LogLevel.error,
    bool logHeaders = false,
    bool logBody = false,
  })  : _requestLevel = requestLevel,
        _responseLevel = responseLevel,
        _errorLevel = errorLevel,
        _logHeaders = logHeaders,
        _logBody = logBody;

  final Logger _logger;
  final LogLevel _requestLevel;
  final LogLevel _responseLevel;
  final LogLevel _errorLevel;
  final bool _logHeaders;
  final bool _logBody;

  // ── Request ────────────────────────────────────────────────────────────────

  /// Logs an outgoing HTTP request.
  ///
  /// Call this from the request phase of your HTTP client's interceptor.
  ///
  /// [method] is the HTTP verb (e.g. `'GET'`, `'POST'`).
  /// [url] is the full request URL as a string.
  /// [headers] are the request headers (only logged when `logHeaders` is `true`).
  /// [body] is the request body (only logged when `logBody` is `true`).
  void onRequest(
    String method,
    String url, {
    Map<String, Object?>? headers,
    Object? body,
  }) {
    if (!_logger.isEnabled(_requestLevel)) return;

    final props = <String, Object?>{
      'http.method': method.toUpperCase(),
      'http.url': url,
    };
    if (_logHeaders && headers != null && headers.isNotEmpty) {
      props['http.request.headers'] = headers;
    }
    if (_logBody && body != null) {
      props['http.request.body'] = body.toString();
    }

    _logger.log(
      _requestLevel,
      '→ ${method.toUpperCase()} $url',
      properties: props,
    );
  }

  // ── Response ───────────────────────────────────────────────────────────────

  /// Logs a received HTTP response.
  ///
  /// Call this from the response phase of your HTTP client's interceptor.
  ///
  /// [statusCode] is the HTTP status code (e.g. `200`, `404`).
  /// [url] is the URL that produced this response.
  /// [durationMs] is the round-trip duration in milliseconds (optional).
  /// [headers] are the response headers (only logged when `logHeaders` is `true`).
  /// [body] is the response body (only logged when `logBody` is `true`).
  void onResponse(
    int statusCode,
    String url, {
    int? durationMs,
    Map<String, Object?>? headers,
    Object? body,
  }) {
    if (!_logger.isEnabled(_responseLevel)) return;

    final props = <String, Object?>{
      'http.status': statusCode,
      'http.url': url,
    };
    if (durationMs != null) props['http.durationMs'] = durationMs;
    if (_logHeaders && headers != null && headers.isNotEmpty) {
      props['http.response.headers'] = headers;
    }
    if (_logBody && body != null) {
      props['http.response.body'] = body.toString();
    }

    _logger.log(
      _responseLevel,
      '← $statusCode $url',
      properties: props,
    );
  }

  // ── Error ──────────────────────────────────────────────────────────────────

  /// Logs an HTTP error.
  ///
  /// Call this from the error phase of your HTTP client's interceptor.
  ///
  /// [method] is the HTTP verb (e.g. `'GET'`).
  /// [url] is the URL that produced the error.
  /// [error] is the exception or error object.
  /// [stackTrace] is the associated stack trace.
  /// [statusCode] is the HTTP status code if one was received before the
  /// failure (optional).
  void onError(
    String method,
    String url,
    Object error,
    StackTrace stackTrace, {
    int? statusCode,
  }) {
    if (!_logger.isEnabled(_errorLevel)) return;

    final props = <String, Object?>{
      'http.method': method.toUpperCase(),
      'http.url': url,
    };
    if (statusCode != null) props['http.status'] = statusCode;

    _logger.log(
      _errorLevel,
      '✕ ${method.toUpperCase()} $url',
      error: error,
      stackTrace: stackTrace,
      properties: props,
    );
  }
}
