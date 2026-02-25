import '../abstractions/log_level.dart';
import '../abstractions/logger.dart';

/// Adds structured exception-logging helpers to every [Logger] implementation.
///
/// `logException` automatically formats the error chain and attaches the
/// stack trace to a standard log entry, reducing boilerplate at call sites.
///
/// ```dart
/// try {
///   await fetchOrder(id);
/// } catch (e, st) {
///   logger.logException(e, st,
///       message: 'Failed to fetch order',
///       properties: {'orderId': id});
/// }
/// ```
extension LoggerExceptionExtension on Logger {
  /// Emits a structured log entry for [error] and its [stackTrace].
  ///
  /// [level] defaults to [LogLevel.error], matching the most common use case.
  ///
  /// [message] provides a human-readable context description. When omitted,
  /// the message is derived automatically from `error.toString()`.
  ///
  /// [properties] are additional structured key/value pairs attached to the
  /// event alongside the built-in `errorType` and `errorMessage` properties.
  ///
  /// The following properties are always added to every call:
  /// - `errorType`    — `runtimeType` of the error object as a string.
  /// - `errorMessage` — `error.toString()`.
  ///
  /// Additional [properties] are merged on top; they can override the
  /// built-in keys if needed.
  void logException(
    Object error,
    StackTrace stackTrace, {
    LogLevel level = LogLevel.error,
    String? message,
    Map<String, Object?>? properties,
  }) {
    final resolvedMessage = message ?? _formatError(error);
    final mergedProperties = _buildProperties(error, properties);
    log(
      level,
      resolvedMessage,
      error: error,
      stackTrace: stackTrace,
      properties: mergedProperties,
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String _formatError(Object error) {
    final type = error.runtimeType.toString();
    final msg = error.toString();
    // Avoid redundant "SomeType: SomeType: …" duplication when toString()
    // already starts with the type name followed by a colon.
    if (msg.startsWith('$type:')) return msg;
    return '$type: $msg';
  }

  static Map<String, Object?> _buildProperties(
    Object error,
    Map<String, Object?>? extra,
  ) {
    final props = <String, Object?>{
      'errorType': error.runtimeType.toString(),
      'errorMessage': error.toString(),
    };
    if (extra != null) props.addAll(extra);
    return props;
  }
}
