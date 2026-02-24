import 'dart:async';

/// An active logging scope that carries structured key/value properties.
///
/// Scopes allow contextual information (e.g. a request ID or a transaction ID)
/// to be automatically injected into every `LogEvent` emitted within their
/// dynamic extent.
///
/// Scopes are **Zone-aware**: because the active scope is stored in the current
/// [Zone], any asynchronous work started inside [run] or [runAsync] inherits
/// the same scope context without any manual threading.
///
/// ## Usage
///
/// ```dart
/// final scope = logger.beginScope({'requestId': requestId, 'userId': userId});
/// await scope.runAsync(() async {
///   logger.info('Handling request');      // includes requestId + userId
///   await processRequest();
///   logger.info('Request complete');      // still includes requestId + userId
/// });
/// ```
///
/// ## Nesting
///
/// Scopes nest naturally: calling `beginScope`(Logger.beginScope) from within an active scope
/// creates a child scope whose properties **override** same-named parent
/// properties, while unique parent properties are still visible.
///
/// ```dart
/// await outerScope.runAsync(() async {
///   final inner = logger.beginScope({'loop': i});
///   await inner.runAsync(() async {
///     logger.debug('Iteration');  // has both outer and 'loop' properties
///   });
/// });
/// ```
final class LoggingScope {
  LoggingScope._(this.properties, this.parent);

  static const Object _zoneKey = #_davianspace_logging_scope;

  /// The properties directly carried by this scope (not merged with parents).
  final Map<String, Object?> properties;

  /// The parent scope in the scope chain, or `null` for the outermost scope.
  final LoggingScope? parent;

  late final Zone _zone = Zone.current.fork(
    zoneValues: {_zoneKey: this},
  );

  // ── Static accessors ───────────────────────────────────────────────────────

  /// Returns the innermost [LoggingScope] active in the current [Zone], or
  /// `null` if no scope is active.
  static LoggingScope? get current => Zone.current[_zoneKey] as LoggingScope?;

  /// Creates a new [LoggingScope] with [properties] and the current scope as
  /// its parent.
  ///
  /// This is called internally by `Logger.beginScope`; prefer that API over
  /// constructing scopes directly.
  // ignore: library_private_types_in_public_api
  static LoggingScope create(Map<String, Object?> properties) =>
      LoggingScope._(Map.unmodifiable(properties), current);

  // ── Property resolution ────────────────────────────────────────────────────

  /// Returns merged properties from the entire scope chain (root → leaf).
  ///
  /// Child properties override parent properties with the same key.
  ///
  /// The result is computed lazily on first access and cached for the lifetime
  /// of this scope (the chain is immutable once created).
  late final Map<String, Object?> effectiveProperties = parent == null
      ? properties
      : Map.unmodifiable(<String, Object?>{
          ...parent!.effectiveProperties,
          ...properties,
        });

  // ── Execution helpers ──────────────────────────────────────────────────────

  /// Executes [body] synchronously within this scope.
  ///
  /// All log calls made inside [body] will have this scope's properties
  /// (merged with any parent scope) injected into the `LogEvent`.
  T run<T>(T Function() body) => _zone.run(body);

  /// Executes [body] asynchronously within this scope.
  ///
  /// Returns a [Future] that completes with the result of [body]. Async
  /// continuations within [body] automatically inherit the scope.
  Future<T> runAsync<T>(Future<T> Function() body) => _zone.run(body);
}
