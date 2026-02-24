import '../abstractions/log_level.dart';
import '../abstractions/logger.dart';
import '../abstractions/logger_provider.dart';
import '../core/logger_factory_impl.dart';
import '../core/logging_scope.dart';

// ── NullLogger ─────────────────────────────────────────────────────────────

/// A no-op [Logger] that silently discards all log entries.
///
/// Useful as a **null object** for optional dependency injection: instead of
/// requiring callers to pass a fully configured logger, accept a `Logger?` and
/// fall back to `NullLogger()`:
///
/// ```dart
/// class MyService {
///   MyService({Logger? logger}) : _log = logger ?? NullLogger();
///   final Logger _log;
/// }
/// ```
///
/// `NullLogger` is safe to use from any context; it never allocates a
/// `LogEvent` and never calls any provider.
final class NullLogger implements Logger {
  /// Creates a [NullLogger] with an optional [category] label.
  const NullLogger([this.category = '']);

  @override
  final String category;

  /// Always returns `false`; [NullLogger] never produces output.
  @override
  bool isEnabled(LogLevel level) => false;

  /// Discards the log entry; this method is a no-op.
  @override
  void log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? properties,
  }) {}

  /// Still returns a valid [LoggingScope] so that scoped contexts work
  /// correctly even when a real logger is replaced by a [NullLogger].
  @override
  LoggingScope beginScope(Map<String, Object?> properties) =>
      LoggingScope.create(properties);
}

// ── NullLoggerProvider ─────────────────────────────────────────────────────

/// [LoggerProvider] that creates [NullLogger] instances.
///
/// Suppresses all log output without routing entries through the provider
/// pipeline.
///
/// Useful when you need a valid `LoggerFactory` in tests or environments where
/// no output sink is available:
///
/// ```dart
/// final factory = LoggingBuilder().addNull().build();
/// ```
final class NullLoggerProvider extends LoggerProvider {
  /// Creates a [NullLoggerProvider].
  const NullLoggerProvider();

  @override
  Logger createLogger(String category) => NullLogger(category);
  // dispose() is a no-op; inherited from LoggerProvider.
}

// ── LoggingBuilder extension ──────────────────────────────────────────────

/// Extension on [LoggingBuilder] that registers a [NullLoggerProvider].
extension LoggingBuilderNullExtension on LoggingBuilder {
  /// Adds a [NullLoggerProvider] to the logging pipeline.
  ///
  /// All log entries routed to this provider are silently discarded.
  ///
  /// ```dart
  /// LoggingBuilder().addNull().build();
  /// ```
  LoggingBuilder addNull() => addProvider(const NullLoggerProvider());
}
