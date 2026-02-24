import 'dart:collection' show ListQueue;

import '../abstractions/log_event.dart';
import '../abstractions/log_level.dart';
import '../abstractions/logger.dart';
import '../abstractions/logger_provider.dart';
import '../core/filter_rules.dart';
import '../core/logger_factory_impl.dart';
import '../core/logger_impl.dart';
import '../core/logging_scope.dart';
import '../utils/timestamp_provider.dart';

// ── MemoryLogStore ─────────────────────────────────────────────────────────

/// An in-memory store of [LogEvent]s, primarily intended for unit testing.
///
/// Inject a [MemoryLogStore] into [MemoryLoggerProvider] and use it to
/// assert the log output produced by application code under test:
///
/// ```dart
/// final store = MemoryLogStore();
/// final factory = LoggingBuilder()
///   .addMemory(store: store)
///   .build();
///
/// // … run code …
///
/// expect(store.events, hasLength(2));
/// expect(store.events.first.level, equals(LogLevel.info));
/// expect(store.events.first.message, equals('Order placed'));
/// ```
///
/// ### Bounded capacity
///
/// Pass [maxCapacity] to cap the store at a fixed number of events. When the
/// store is full, the **oldest** event is evicted before the new one is added
/// (ring-buffer / FIFO eviction). This prevents unbounded memory growth in
/// long-running test suites.
///
/// ```dart
/// final store = MemoryLogStore(maxCapacity: 1000);
/// ```
final class MemoryLogStore {
  /// Creates a [MemoryLogStore].
  ///
  /// [maxCapacity] is the maximum number of events retained. When the limit
  /// is reached the oldest event is evicted to make room for the new one.
  /// Omit (or pass `null`) for an unbounded store.
  MemoryLogStore({this.maxCapacity});

  /// The maximum number of events this store retains.
  ///
  /// `null` means unlimited (the default).
  final int? maxCapacity;

  final ListQueue<LogEvent> _events = ListQueue<LogEvent>();

  /// All events recorded by this store in the order they were received.
  List<LogEvent> get events => List.unmodifiable(_events);

  /// Returns all events whose [LogEvent.level] is at least [minimum].
  List<LogEvent> eventsAtOrAbove(LogLevel minimum) =>
      _events.where((e) => e.level.isAtLeast(minimum)).toList();

  /// Returns all events emitted by [category].
  List<LogEvent> eventsForCategory(String category) =>
      _events.where((e) => e.category == category).toList();

  /// Removes all stored events.
  void clear() => _events.clear();

  /// Adds [event] to the store.
  ///
  /// When [maxCapacity] is set and the store is full, the oldest event is
  /// removed before the new one is appended.
  ///
  /// Called internally by [_MemoryLogger.write]; not intended for direct use.
  void add(LogEvent event) {
    final cap = maxCapacity;
    if (cap != null && _events.length >= cap) {
      _events.removeFirst(); // O(1): evict oldest event
    }
    _events.add(event);
  }

  /// The total number of events stored.
  int get length => _events.length;

  /// `true` if no events have been recorded yet.
  bool get isEmpty => _events.isEmpty;

  /// `true` if at least one event has been recorded.
  bool get isNotEmpty => _events.isNotEmpty;
}

// ── MemoryLoggerProvider ───────────────────────────────────────────────────

/// [LoggerProvider] that stores all log entries in a [MemoryLogStore].
///
/// Designed for unit testing; not suitable for production use.
///
/// ### Registration
///
/// ```dart
/// final store = MemoryLogStore();
/// final factory = LoggingBuilder()
///   .addMemory(store: store)
///   .build();
/// ```
///
/// Omitting [store] creates a new private store, accessible via
/// [MemoryLoggerProvider.store]:
///
/// ```dart
/// final provider = MemoryLoggerProvider();
/// final factory = LoggingBuilder().addProvider(provider).build();
/// // inspect provider.store after use
/// ```
final class MemoryLoggerProvider implements LoggerProvider {
  /// Creates a [MemoryLoggerProvider].
  ///
  /// Provide [store] to share the store across multiple tests or inspect it
  /// after building the factory.
  MemoryLoggerProvider({MemoryLogStore? store})
      : store = store ?? MemoryLogStore();

  /// The store into which all log events are written.
  final MemoryLogStore store;

  final Map<String, _MemoryLogger> _cache = {};

  @override
  Logger createLogger(String category) => _cache.putIfAbsent(
        category,
        () => _MemoryLogger(
          category: category,
          store: store,
          rules: FilterRuleSet(const <FilterRule>[], LogLevel.trace),
          timestampProvider: const UtcTimestampProvider(),
        ),
      );

  @override
  void dispose() => _cache.clear();
}

// ── _MemoryLogger ──────────────────────────────────────────────────────────

final class _MemoryLogger implements EventLogger {
  _MemoryLogger({
    required String category,
    required MemoryLogStore store,
    required FilterRuleSet rules,
    required TimestampProvider timestampProvider,
  })  : _category = category,
        _store = store,
        _rules = rules,
        _timestampProvider = timestampProvider;

  final String _category;
  final MemoryLogStore _store;
  final FilterRuleSet _rules;
  final TimestampProvider _timestampProvider;

  @override
  String get category => _category;

  @override
  bool isEnabled(LogLevel level) =>
      level != LogLevel.none &&
      _rules.isEnabled(MemoryLoggerProvider, _category, level);

  @override
  void write(LogEvent event) => _store.add(event);

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

/// Extension on [LoggingBuilder] that registers a [MemoryLoggerProvider].
extension LoggingBuilderMemoryExtension on LoggingBuilder {
  /// Adds a [MemoryLoggerProvider] to the logging pipeline.
  ///
  /// Pass a pre-created [store] to inspect events after the logger is used,
  /// or omit [store] and access it via [MemoryLoggerProvider.store] directly.
  ///
  /// ```dart
  /// final store = MemoryLogStore();
  /// LoggingBuilder().addMemory(store: store).build();
  /// ```
  LoggingBuilder addMemory({MemoryLogStore? store}) =>
      addProvider(MemoryLoggerProvider(store: store));
}
