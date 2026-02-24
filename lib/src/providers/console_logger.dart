import 'dart:io' show stdout;

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

// ── ANSI helpers ──────────────────────────────────────────────────────────

const String _reset = '\x1B[0m';
const String _bold = '\x1B[1m';
const String _gray = '\x1B[90m';
const String _cyan = '\x1B[36m';
const String _green = '\x1B[32m';
const String _yellow = '\x1B[33m';
const String _red = '\x1B[31m';
const String _brightRed = '\x1B[91m';

String _colorFor(LogLevel level) => switch (level) {
      LogLevel.trace => _gray,
      LogLevel.debug => _cyan,
      LogLevel.info => _green,
      LogLevel.warning => _yellow,
      LogLevel.error => _red,
      LogLevel.critical => '$_bold$_brightRed',
      LogLevel.none => '',
    };

// ── ConsoleLoggerProvider ─────────────────────────────────────────────────

/// [LoggerProvider] that writes formatted log entries to `stdout`.
///
/// Output is colorized using ANSI escape codes when `stdout.supportsAnsiEscapes`
/// is `true` (most terminals on macOS / Linux / Windows Terminal). Color is
/// automatically disabled on piped output.
///
/// ### Requires `dart:io`
///
/// `ConsoleLoggerProvider` depends on `dart:io` and is therefore not
/// compatible with Dart Web or Flutter Web targets. Use `DebugLoggerProvider`
/// in web contexts.
///
/// ### Registration
///
/// ```dart
/// LoggingBuilder().addConsole().build();
/// // or with a custom formatter:
/// LoggingBuilder().addConsole(formatter: JsonFormatter()).build();
/// ```
final class ConsoleLoggerProvider implements LoggerProvider {
  /// Creates a [ConsoleLoggerProvider].
  ///
  /// [formatter] defaults to [SimpleFormatter].
  ConsoleLoggerProvider({LogFormatter? formatter})
      : _formatter = formatter ?? const SimpleFormatter();

  final LogFormatter _formatter;
  final Map<String, _ConsoleLogger> _cache = {};

  @override
  Logger createLogger(String category) => _cache.putIfAbsent(
        category,
        () => _ConsoleLogger(
          category: category,
          formatter: _formatter,
          rules: FilterRuleSet(const <FilterRule>[], LogLevel.trace),
          timestampProvider: const UtcTimestampProvider(),
        ),
      );

  @override
  void dispose() => _cache.clear();
}

// ── _ConsoleLogger ─────────────────────────────────────────────────────────

final class _ConsoleLogger implements EventLogger {
  _ConsoleLogger({
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

  /// Cached once per logger instance; ANSI capability does not change at
  /// runtime for a given `stdout` handle.
  late final bool _ansiEnabled = stdout.supportsAnsiEscapes;

  @override
  String get category => _category;

  @override
  bool isEnabled(LogLevel level) =>
      level != LogLevel.none &&
      _rules.isEnabled(ConsoleLoggerProvider, _category, level);

  @override
  void write(LogEvent event) {
    final formatted = _formatter.format(event);
    if (_ansiEnabled) {
      final color = _colorFor(event.level);
      stdout.writeln('$color$formatted$_reset');
    } else {
      stdout.writeln(formatted);
    }
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

/// Extension on [LoggingBuilder] that registers a [ConsoleLoggerProvider].
extension LoggingBuilderConsoleExtension on LoggingBuilder {
  /// Adds a [ConsoleLoggerProvider] to the logging pipeline.
  ///
  /// [formatter] controls the output format. Defaults to [SimpleFormatter].
  ///
  /// ```dart
  /// LoggingBuilder().addConsole().build();
  /// ```
  LoggingBuilder addConsole({LogFormatter? formatter}) =>
      addProvider(ConsoleLoggerProvider(formatter: formatter));
}
