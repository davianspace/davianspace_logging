import '../abstractions/log_level.dart';
import '../abstractions/logger.dart';
import '../abstractions/logger_factory.dart';
import '../abstractions/logger_provider.dart';
import '../utils/timestamp_provider.dart';
import 'filter_rules.dart';
import 'logger_impl.dart';

// ── LoggerFactoryImpl ──────────────────────────────────────────────────────

/// Default [LoggerFactory] implementation.
///
/// Manages a registered set of [LoggerProvider]s, a shared [FilterRuleSet],
/// and a per-category [Logger] cache. Thread-safety is provided implicitly by
/// Dart's single-threaded isolate model; the factory is safe to share across
/// async code within a single isolate.
///
/// Obtain instances via [LoggingBuilder.build]:
///
/// ```dart
/// final factory = LoggingBuilder()
///   .addConsole()
///   .setMinimumLevel(LogLevel.info)
///   .build();
/// ```
final class LoggerFactoryImpl implements LoggerFactory {
  /// Creates a [LoggerFactoryImpl] with the supplied [providers], [rules], and
  /// [timestampProvider].
  ///
  /// Prefer using [LoggingBuilder] rather than constructing this directly.
  LoggerFactoryImpl({
    required List<LoggerProvider> providers,
    required FilterRuleSet rules,
    required TimestampProvider timestampProvider,
  })  : _providers = List.of(providers),
        _rules = rules,
        _timestampProvider = timestampProvider;

  final List<LoggerProvider> _providers;
  final FilterRuleSet _rules;
  final TimestampProvider _timestampProvider;

  /// Cache of category → per-category [LoggerEntry] lists.
  ///
  /// Each [LoggerImpl] stores a *reference* to its entry list so that live
  /// additions via [addProvider] are reflected without recreating loggers.
  final Map<String, List<LoggerEntry>> _entryCache = {};

  /// Cache of category → [LoggerImpl].
  final Map<String, LoggerImpl> _loggerCache = {};

  bool _disposed = false;

  // ── LoggerFactory interface ────────────────────────────────────────────────

  @override
  Logger createLogger(String category) {
    if (_disposed) throw StateError('LoggerFactory has been disposed.');
    return _loggerCache.putIfAbsent(category, () {
      final entries = _buildEntries(category);
      _entryCache[category] = entries;
      return LoggerImpl(
        category: category,
        entries: entries,
        rules: _rules,
        timestampProvider: _timestampProvider,
      );
    });
  }

  @override
  void addProvider(LoggerProvider provider) {
    if (_disposed) throw StateError('LoggerFactory has been disposed.');
    _providers.add(provider);
    // Extend every existing entry list so live-added providers are immediately
    // visible to already-created loggers.
    for (final entry in _entryCache.entries) {
      entry.value.add(_buildEntry(entry.key, provider));
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final provider in _providers) {
      provider.dispose();
    }
    _providers.clear();
    // Clear the entry list contents so any LoggerImpl instances that hold
    // references to those lists become inert after disposal.
    for (final entries in _entryCache.values) {
      entries.clear();
    }
    _loggerCache.clear();
    _entryCache.clear();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  List<LoggerEntry> _buildEntries(String category) =>
      [for (final p in _providers) _buildEntry(category, p)];

  LoggerEntry _buildEntry(String category, LoggerProvider provider) =>
      LoggerEntry(provider.runtimeType, provider.createLogger(category));
}

// ── LoggingBuilder ─────────────────────────────────────────────────────────

/// Fluent builder for configuring and constructing a [LoggerFactory].
///
/// ## Minimal setup
///
/// ```dart
/// final factory = LoggingBuilder()
///   .addConsole()
///   .build();
/// ```
///
/// ## Full configuration
///
/// ```dart
/// final store = MemoryLogStore();
///
/// final factory = LoggingBuilder()
///   .addConsole(formatter: JsonFormatter())
///   .addMemory(store: store)
///   .setMinimumLevel(LogLevel.debug)
///   .addFilterRule(FilterRule(
///       categoryPrefix: 'network',
///       minimumLevel: LogLevel.warning,
///   ))
///   .build();
/// ```
///
/// Providers are evaluated in registration order. The first matching
/// [FilterRule] wins; the global minimum level set via [setMinimumLevel]
/// acts as a catch-all floor.
final class LoggingBuilder {
  final List<LoggerProvider> _providers = [];
  final List<FilterRule> _rules = [];
  LogLevel _minimumLevel = LogLevel.trace;
  TimestampProvider _timestampProvider = const UtcTimestampProvider();

  // ── Provider registration ──────────────────────────────────────────────────

  /// Adds an arbitrary [LoggerProvider] to the pipeline.
  ///
  /// Use the typed helpers (`addConsole`, `addDebug`, `addMemory`) for
  /// built-in providers.
  LoggingBuilder addProvider(LoggerProvider provider) {
    _providers.add(provider);
    return this;
  }

  // ── Named provider helpers (defined in providers layer, referenced here) ───
  // Concrete helpers are defined as extension methods on [LoggingBuilder] in
  // each provider file to keep this file free of provider-specific imports.
  // See:
  //   providers/console_logger.dart  → LoggingBuilderConsoleExtension
  //   providers/debug_logger.dart    → LoggingBuilderDebugExtension
  //   providers/memory_logger.dart   → LoggingBuilderMemoryExtension

  // ── Filtering ──────────────────────────────────────────────────────────────

  /// Sets the global minimum [LogLevel].
  ///
  /// Any entry below this level is dropped before reaching providers, unless
  /// a more specific [FilterRule] overrides it.
  ///
  /// Defaults to [LogLevel.trace] (all entries pass through).
  LoggingBuilder setMinimumLevel(LogLevel level) {
    _minimumLevel = level;
    return this;
  }

  /// Registers a [FilterRule] to override the global minimum level for
  /// specific providers or category prefixes.
  ///
  /// Rules are evaluated in registration order; the most specific matching
  /// rule wins (provider + prefix > prefix only > provider only > global).
  LoggingBuilder addFilterRule(FilterRule rule) {
    _rules.add(rule);
    return this;
  }

  // ── Timestamp customisation ────────────────────────────────────────────────

  /// Replaces the default [UtcTimestampProvider] with [provider].
  ///
  /// Inject a deterministic provider in tests:
  ///
  /// ```dart
  /// LoggingBuilder().useTimestampProvider(FixedTimestampProvider(t0))
  /// ```
  LoggingBuilder useTimestampProvider(TimestampProvider provider) {
    _timestampProvider = provider;
    return this;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  /// Builds and returns a configured [LoggerFactory].
  ///
  /// The factory is ready for immediate use. Call [LoggerFactory.dispose] when
  /// the application shuts down.
  LoggerFactory build() => LoggerFactoryImpl(
        providers: _providers,
        rules: FilterRuleSet(_rules, _minimumLevel),
        timestampProvider: _timestampProvider,
      );
}
