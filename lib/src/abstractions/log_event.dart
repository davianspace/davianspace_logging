import 'log_level.dart';

/// An immutable, structured log entry.
///
/// `LogEvent` is the central data carrier passed between `Logger`
/// implementations and `LoggerProvider`s. It decouples message creation from
/// rendering, allowing each provider to format the data as needed.
///
/// Structured properties are stored separately from the human-readable
/// `message` so providers can persist them as machine-readable data (e.g. JSON)
/// without parsing string templates.
///
/// **Immutability guarantee:** `properties` and `scopeProperties` maps are
/// defensively copied on construction and wrapped in an unmodifiable view.
/// Mutating the source maps after logging has no effect on stored events.
///
/// Example:
/// ```dart
/// final event = LogEvent(
///   level: LogLevel.info,
///   category: 'OrderService',
///   message: 'Order placed',
///   timestamp: DateTime.timestamp(),
///   properties: {'orderId': 42, 'amount': 99.99},
/// );
/// ```
final class LogEvent {
  /// Creates a new [LogEvent].
  ///
  /// [properties] and [scopeProperties] are defensively copied; mutating the
  /// source maps after construction has no effect on this event.
  LogEvent({
    required this.level,
    required this.category,
    required this.message,
    required this.timestamp,
    Map<String, Object?> properties = const <String, Object?>{},
    Map<String, Object?> scopeProperties = const <String, Object?>{},
    this.error,
    this.stackTrace,
  })  : properties = properties.isEmpty
            ? const <String, Object?>{}
            : Map.unmodifiable(Map.of(properties)),
        scopeProperties = scopeProperties.isEmpty
            ? const <String, Object?>{}
            : Map.unmodifiable(Map.of(scopeProperties));

  /// The severity of this event.
  final LogLevel level;

  /// The logger category that emitted this event (e.g. class or module name).
  final String category;

  /// The human-readable log message.
  final String message;

  /// The UTC timestamp when this event was created.
  final DateTime timestamp;

  /// Caller-supplied structured properties (not interpolated into [message]).
  ///
  /// Keys are property names; values are arbitrary serializable objects.
  /// The map is unmodifiable; it is a defensive copy of the source map.
  final Map<String, Object?> properties;

  /// Merged properties collected from the active `LoggingScope` chain.
  ///
  /// Scope properties are automatically injected by `LoggerImpl` when an
  /// active scope exists. Child scope properties override parent scope
  /// properties with the same key. The map is unmodifiable.
  final Map<String, Object?> scopeProperties;

  /// The exception or error associated with this event, if any.
  final Object? error;

  /// The stack trace associated with `error`, if any.
  final StackTrace? stackTrace;

  // ── Value semantics ────────────────────────────────────────────────────────

  /// Returns a copy of this event with the specified fields replaced.
  ///
  /// Nullable fields [error] and [stackTrace] are inherited from the original
  /// when omitted; pass an explicit value to override them.
  LogEvent copyWith({
    LogLevel? level,
    String? category,
    String? message,
    DateTime? timestamp,
    Map<String, Object?>? properties,
    Map<String, Object?>? scopeProperties,
    Object? error,
    StackTrace? stackTrace,
  }) =>
      LogEvent(
        level: level ?? this.level,
        category: category ?? this.category,
        message: message ?? this.message,
        timestamp: timestamp ?? this.timestamp,
        properties: properties ?? this.properties,
        scopeProperties: scopeProperties ?? this.scopeProperties,
        error: error ?? this.error,
        stackTrace: stackTrace ?? this.stackTrace,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LogEvent) return false;
    return level == other.level &&
        category == other.category &&
        message == other.message &&
        timestamp == other.timestamp &&
        error == other.error &&
        stackTrace == other.stackTrace &&
        _mapsEqual(properties, other.properties) &&
        _mapsEqual(scopeProperties, other.scopeProperties);
  }

  @override
  int get hashCode => Object.hash(
        level,
        category,
        message,
        timestamp,
        error,
        stackTrace,
      );

  @override
  String toString() {
    final buf = StringBuffer(
        'LogEvent(${level.label}, $category, "$message", $timestamp');
    if (error != null) buf.write(', error: $error');
    buf.write(')');
    return buf.toString();
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────

bool _mapsEqual(Map<String, Object?> a, Map<String, Object?> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final MapEntry(:key, :value) in a.entries) {
    if (!b.containsKey(key) || b[key] != value) return false;
  }
  return true;
}
