import '../abstractions/log_level.dart';
import '../abstractions/logger.dart';

/// Adds tag-based logging convenience methods to every [Logger] implementation.
///
/// Tags provide a lightweight secondary classification for log entries,
/// orthogonal to the existing [Logger.category] or [LogLevel] routing.
///
/// Tags are stored in the event's `properties` map under the reserved key
/// [LoggerTagExtension.tagKey] (`'tag'`), making them visible to every
/// provider and queryable via `MemoryLogStore.eventsForTag` without requiring
/// any changes to the core [Logger] interface.
///
/// ```dart
/// logger.logTagged(LogLevel.info, 'auth', 'User signed in',
///     properties: {'userId': 42});
///
/// logger.infoTagged('lifecycle', 'App resumed');
/// ```
extension LoggerTagExtension on Logger {
  /// Reserved property key used to store a tag on a log entry.
  ///
  /// Consumers that inspect events manually can read the tag via
  /// `event.properties[LoggerTagExtension.tagKey]`.
  static const String tagKey = 'tag';

  /// Emits a structured log entry at [level] with the supplied [tag].
  ///
  /// The [tag] is stored under [tagKey] in the event's `properties` map.
  /// Any additional [properties] are merged with the tag; if [properties]
  /// already contains a `'tag'` key it is **overwritten** by [tag].
  void logTagged(
    LogLevel level,
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? properties,
  }) =>
      log(
        level,
        message,
        error: error,
        stackTrace: stackTrace,
        properties: {if (properties != null) ...properties, tagKey: tag},
      );

  /// Emits a [LogLevel.trace] entry with the supplied [tag].
  void traceTagged(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? properties,
  }) =>
      logTagged(
        LogLevel.trace,
        tag,
        message,
        error: error,
        stackTrace: stackTrace,
        properties: properties,
      );

  /// Emits a [LogLevel.debug] entry with the supplied [tag].
  void debugTagged(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? properties,
  }) =>
      logTagged(
        LogLevel.debug,
        tag,
        message,
        error: error,
        stackTrace: stackTrace,
        properties: properties,
      );

  /// Emits a [LogLevel.info] entry with the supplied [tag].
  void infoTagged(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? properties,
  }) =>
      logTagged(
        LogLevel.info,
        tag,
        message,
        error: error,
        stackTrace: stackTrace,
        properties: properties,
      );

  /// Emits a [LogLevel.warning] entry with the supplied [tag].
  void warningTagged(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? properties,
  }) =>
      logTagged(
        LogLevel.warning,
        tag,
        message,
        error: error,
        stackTrace: stackTrace,
        properties: properties,
      );

  /// Emits a [LogLevel.error] entry with the supplied [tag].
  void errorTagged(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? properties,
  }) =>
      logTagged(
        LogLevel.error,
        tag,
        message,
        error: error,
        stackTrace: stackTrace,
        properties: properties,
      );

  /// Emits a [LogLevel.critical] entry with the supplied [tag].
  void criticalTagged(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? properties,
  }) =>
      logTagged(
        LogLevel.critical,
        tag,
        message,
        error: error,
        stackTrace: stackTrace,
        properties: properties,
      );
}
