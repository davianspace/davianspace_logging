import '../core/logging_scope.dart';
import 'log_level.dart';

/// The primary interface for emitting structured log entries.
///
/// Obtain a `Logger` instance via `LoggerFactory.createLogger`. The category
/// string (typically a class or sub-system name) scopes log output so that
/// filters and providers can route entries precisely.
///
/// **Convenience methods** delegate to [log] with a fixed [LogLevel]:
/// - [trace], [debug], [info], [warning], [error], [critical]
///
/// **Performance tip:** Guard expensive calls with [isEnabled] to avoid
/// unnecessary work when a level is disabled:
///
/// ```dart
/// if (logger.isEnabled(LogLevel.debug)) {
///   logger.debug('Cache snapshot: ${cache.dump()}');
/// }
/// ```
abstract interface class Logger {
  /// The category label associated with this logger instance.
  String get category;

  /// Returns `true` if [level] will produce output given the current filter
  /// configuration.
  ///
  /// Use this guard before performing expensive message construction.
  bool isEnabled(LogLevel level);

  /// Emits a structured log entry at the specified [level].
  ///
  /// [message] is the human-readable description; avoid string interpolation
  /// of domain objects — place them in [properties] so providers can handle
  /// them as structured data.
  ///
  /// [properties] are key/value pairs stored separately from [message].
  /// [error] is the exception that caused this log entry, if any.
  /// [stackTrace] is the stack trace associated with [error].
  void log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? properties,
  });

  /// Begins a new logging scope that merges [properties] into every log entry
  /// emitted within the scope.
  ///
  /// Scopes are Zone-aware: all async continuations started inside
  /// `LoggingScope.run` or `LoggingScope.runAsync` automatically inherit the
  /// active scope.
  ///
  /// ```dart
  /// final scope = logger.beginScope({'requestId': requestId});
  /// await scope.runAsync(() async {
  ///   logger.info('Processing request'); // includes requestId
  ///   await handleRequest();
  /// });
  /// ```
  LoggingScope beginScope(Map<String, Object?> properties);
}

// ── Convenience extension ──────────────────────────────────────────────────

/// Adds typed convenience methods to every [Logger] implementation.
///
/// These methods delegate to [Logger.log] with a fixed [LogLevel], making
/// call sites more readable:
///
/// ```dart
/// logger.info('Server started');          // instead of logger.log(LogLevel.info, ...)
/// logger.error('Crash', error: ex);       // instead of logger.log(LogLevel.error, ...)
/// ```
///
/// Extension methods are automatically available on any object that implements
/// [Logger] without requiring subclassing or re-implementation.
extension LoggerConvenienceExtension on Logger {
  /// Emits a [LogLevel.trace] entry.
  void trace(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? properties,
  }) =>
      log(
        LogLevel.trace,
        message,
        error: error,
        stackTrace: stackTrace,
        properties: properties,
      );

  /// Emits a [LogLevel.debug] entry.
  void debug(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? properties,
  }) =>
      log(
        LogLevel.debug,
        message,
        error: error,
        stackTrace: stackTrace,
        properties: properties,
      );

  /// Emits a [LogLevel.info] entry.
  void info(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? properties,
  }) =>
      log(
        LogLevel.info,
        message,
        error: error,
        stackTrace: stackTrace,
        properties: properties,
      );

  /// Emits a [LogLevel.warning] entry.
  void warning(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? properties,
  }) =>
      log(
        LogLevel.warning,
        message,
        error: error,
        stackTrace: stackTrace,
        properties: properties,
      );

  /// Emits a [LogLevel.error] entry.
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? properties,
  }) =>
      log(
        LogLevel.error,
        message,
        error: error,
        stackTrace: stackTrace,
        properties: properties,
      );

  /// Emits a [LogLevel.critical] entry.
  void critical(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? properties,
  }) =>
      log(
        LogLevel.critical,
        message,
        error: error,
        stackTrace: stackTrace,
        properties: properties,
      );
}
