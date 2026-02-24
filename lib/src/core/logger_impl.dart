import '../abstractions/log_event.dart';
import '../abstractions/log_level.dart';
import '../abstractions/logger.dart';
import '../utils/timestamp_provider.dart';
import 'filter_rules.dart';
import 'logging_scope.dart';

// ── Internal event-aware interface ─────────────────────────────────────────

/// Internal interface implemented by all built-in provider loggers.
///
/// [LoggerImpl] checks for this interface to pass a pre-built [LogEvent]
/// (which already carries scope properties) rather than raw parameters.
/// External providers that return plain [Logger] instances are supported via
/// the standard [Logger.log] fallback, but will not receive scope-merged data.
abstract interface class EventLogger implements Logger {
  /// Writes a fully-resolved [LogEvent] to the underlying provider sink.
  void write(LogEvent event);
}

// ── Entry type ─────────────────────────────────────────────────────────────

/// Associates a cached provider-level [Logger] with its [providerType] for
/// filter-rule lookups.
final class LoggerEntry {
  const LoggerEntry(this.providerType, this.logger);

  final Type providerType;
  final Logger logger;
}

// ── LoggerImpl ─────────────────────────────────────────────────────────────

/// High-performance [Logger] that broadcasts log entries to all registered
/// provider loggers.
///
/// ### Zero-allocation fast-path
///
/// [log] first checks whether **any** provider accepts the entry. If all
/// providers filter it out, the method returns immediately — no [LogEvent]
/// is allocated.
///
/// ### Single-allocation broadcast
///
/// When at least one provider accepts the entry, a single [LogEvent] is
/// created and shared across all accepting providers.
///
/// ### Scope injection
///
/// Active [LoggingScope] properties are merged into [LogEvent.scopeProperties]
/// at the call site, making them available to every provider automatically.
final class LoggerImpl implements Logger {
  /// Creates a [LoggerImpl].
  ///
  /// [entries] is populated by `LoggerFactoryImpl` and extended in-place when
  /// new providers are added via `LoggerFactory.addProvider`.
  LoggerImpl({
    required String category,
    required List<LoggerEntry> entries,
    required FilterRuleSet rules,
    required TimestampProvider timestampProvider,
  })  : _category = category,
        _entries = entries,
        _rules = rules,
        _timestampProvider = timestampProvider;

  final String _category;
  final List<LoggerEntry> _entries;
  final FilterRuleSet _rules;
  final TimestampProvider _timestampProvider;

  @override
  String get category => _category;

  // ── Filtering ──────────────────────────────────────────────────────────────

  @override
  bool isEnabled(LogLevel level) {
    if (level == LogLevel.none) return false;
    for (final e in _entries) {
      if (_rules.isEnabled(e.providerType, _category, level)) return true;
    }
    return false;
  }

  // ── Core dispatch ──────────────────────────────────────────────────────────

  @override
  void log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? properties,
  }) {
    if (level == LogLevel.none) return;

    // Zero-allocation fast-path: bail if nothing is enabled.
    var anyEnabled = false;
    for (final e in _entries) {
      if (_rules.isEnabled(e.providerType, _category, level)) {
        anyEnabled = true;
        break;
      }
    }
    if (!anyEnabled) return;

    // Resolve scope properties once (no allocation when no scope is active).
    final activeScope = LoggingScope.current;
    final scopeProps = activeScope != null
        ? activeScope.effectiveProperties
        : const <String, Object?>{};

    // Allocate one LogEvent shared across all providers.
    final event = LogEvent(
      level: level,
      category: _category,
      message: message,
      timestamp: _timestampProvider.now(),
      properties: properties ?? const <String, Object?>{},
      scopeProperties: scopeProps,
      error: error,
      stackTrace: stackTrace,
    );

    // Dispatch to each enabled provider.
    for (final e in _entries) {
      if (!_rules.isEnabled(e.providerType, _category, level)) continue;
      final logger = e.logger;
      if (logger is EventLogger) {
        logger.write(event);
      } else {
        // Fallback for external providers: scope properties are not forwarded.
        logger.log(
          level,
          message,
          error: error,
          stackTrace: stackTrace,
          properties: properties,
        );
      }
    }
  }

  @override
  LoggingScope beginScope(Map<String, Object?> properties) =>
      LoggingScope.create(properties);
}

// ── ProviderLogger ─────────────────────────────────────────────────────────

/// Base [EventLogger] used by all built-in providers.
///
/// Accepts [LogEvent] from [LoggerImpl] and forwards it to the provider's
/// [_sink]. Also implements the raw [Logger] interface so providers can be
/// used standalone in unit tests without a full factory.
final class ProviderLogger implements EventLogger {
  /// Creates a [ProviderLogger].
  ProviderLogger({
    required String category,
    required void Function(LogEvent event) sink,
    required FilterRuleSet rules,
    required Type providerType,
    required TimestampProvider timestampProvider,
  })  : _category = category,
        _sink = sink,
        _rules = rules,
        _providerType = providerType,
        _timestampProvider = timestampProvider;

  final String _category;
  final void Function(LogEvent event) _sink;
  final FilterRuleSet _rules;
  final Type _providerType;
  final TimestampProvider _timestampProvider;

  @override
  String get category => _category;

  @override
  bool isEnabled(LogLevel level) =>
      level != LogLevel.none &&
      _rules.isEnabled(_providerType, _category, level);

  /// Hot path: accepts an already-assembled [LogEvent] with no extra work.
  @override
  void write(LogEvent event) => _sink(event);

  /// Constructs a [LogEvent] from raw parameters (standalone / test path).
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
