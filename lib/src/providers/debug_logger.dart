import 'dart:developer' as developer;

import '../abstractions/log_event.dart';
import '../abstractions/log_level.dart';
import '../abstractions/logger.dart';
import '../abstractions/logger_provider.dart';
import '../core/filter_rules.dart';
import '../core/logger_factory_impl.dart';
import '../core/logger_impl.dart';
import '../core/logging_scope.dart';
import '../formatting/log_formatter.dart';
import '../formatting/simple_formatter.dart';
import '../utils/timestamp_provider.dart';

// ── Severity mapping ───────────────────────────────────────────────────────

/// Maps [LogLevel] to `dart:developer` severity integers.
///
/// The `dart:developer` log API uses the same integer levels as
/// `java.util.logging`:
/// - 300  : FINEST
/// - 400  : FINER
/// - 500  : FINE
/// - 700  : CONFIG
/// - 800  : INFO
/// - 900  : WARNING
/// - 1000 : SEVERE
/// - 1200 : SHOUT
/// - 2000 : OFF  (no events are logged)
int _devSeverity(LogLevel level) => switch (level) {
      LogLevel.trace => 300,
      LogLevel.debug => 500,
      LogLevel.info => 800,
      LogLevel.warning => 900,
      LogLevel.error => 1000,
      LogLevel.critical => 1200,
      LogLevel.none =>
        2000, // OFF – should never reach the provider, just in case
    };

// ── DebugLoggerProvider ───────────────────────────────────────────────────

/// [LoggerProvider] that writes to the Dart/Flutter developer log stream.
///
/// Output is visible in:
/// - Flutter's **Debug Console** in VS Code / Android Studio.
/// - Dart's `dart:developer` inspector.
/// - `dart run --observe` via the VM service protocol.
///
/// Unlike `ConsoleLoggerProvider`, `DebugLoggerProvider` is platform-agnostic
/// and works on all Dart targets including Flutter Web.
///
/// ### Registration
///
/// ```dart
/// LoggingBuilder().addDebug().build();
/// ```
final class DebugLoggerProvider implements LoggerProvider {
  /// Creates a [DebugLoggerProvider].
  ///
  /// [formatter] defaults to [SimpleFormatter].
  DebugLoggerProvider({LogFormatter? formatter})
      : _formatter = formatter ?? const SimpleFormatter();

  final LogFormatter _formatter;
  final Map<String, _DebugLogger> _cache = {};

  @override
  Logger createLogger(String category) => _cache.putIfAbsent(
        category,
        () => _DebugLogger(
          category: category,
          formatter: _formatter,
          rules: FilterRuleSet(const <FilterRule>[], LogLevel.trace),
          timestampProvider: const UtcTimestampProvider(),
        ),
      );

  @override
  void dispose() => _cache.clear();
}

// ── _DebugLogger ───────────────────────────────────────────────────────────

final class _DebugLogger implements EventLogger {
  _DebugLogger({
    required String category,
    required LogFormatter formatter,
    required FilterRuleSet rules,
    required TimestampProvider timestampProvider,
  })  : _category = category,
        _formatter = formatter,
        _rules = rules,
        _timestampProvider = timestampProvider;

  final String _category;
  final LogFormatter _formatter;
  final FilterRuleSet _rules;
  final TimestampProvider _timestampProvider;

  @override
  String get category => _category;

  @override
  bool isEnabled(LogLevel level) =>
      level != LogLevel.none &&
      _rules.isEnabled(DebugLoggerProvider, _category, level);

  @override
  void write(LogEvent event) {
    developer.log(
      _formatter.format(event),
      name: event.category,
      level: _devSeverity(event.level),
      error: event.error,
      stackTrace: event.stackTrace,
      time: event.timestamp,
    );
  }

  @override
  void log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? properties,
  }) {
    if (!isEnabled(level)) return;

    final activeScope = LoggingScope.current;
    final scopeProps = activeScope != null
        ? activeScope.effectiveProperties
        : const <String, Object?>{};

    write(
      LogEvent(
        level: level,
        category: _category,
        message: message,
        timestamp: _timestampProvider.now(),
        properties: properties ?? const <String, Object?>{},
        scopeProperties: scopeProps,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }

  @override
  LoggingScope beginScope(Map<String, Object?> properties) =>
      LoggingScope.create(properties);
}

// ── LoggingBuilder extension ──────────────────────────────────────────────

/// Extension on [LoggingBuilder] that registers a [DebugLoggerProvider].
extension LoggingBuilderDebugExtension on LoggingBuilder {
  /// Adds a [DebugLoggerProvider] to the logging pipeline.
  ///
  /// [formatter] controls the output format. Defaults to [SimpleFormatter].
  ///
  /// ```dart
  /// LoggingBuilder().addDebug().build();
  /// ```
  LoggingBuilder addDebug({LogFormatter? formatter}) =>
      addProvider(DebugLoggerProvider(formatter: formatter));
}
