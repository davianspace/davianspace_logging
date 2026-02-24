import 'logger.dart';

/// A pluggable logging back-end that knows how to create [Logger] instances
/// for a given category.
///
/// Extend or implement this class to add a custom logging destination (e.g. a
/// remote telemetry service, a file sink, or a database writer).
///
/// Providers are registered with `LoggingBuilder` before the factory is built:
///
/// ```dart
/// LoggingBuilder()
///   .addConsole()
///   .addProvider(MyCustomProvider())
///   .build();
/// ```
///
/// Each call to [createLogger] may return a cached instance — providers are
/// responsible for their own caching strategy.
///
/// Providers that own resources (file handles, sockets, timers) should
/// override `dispose` to release them when the `LoggerFactory` is disposed.
///
/// Extending `LoggerProvider` gives a free no-op `dispose` implementation:
///
/// ```dart
/// class MyProvider extends LoggerProvider {
///   @override
///   Logger createLogger(String category) => MyLogger(category);
///   // dispose() is a no-op unless you override it.
/// }
/// ```
abstract class LoggerProvider {
  /// Default constructor.
  const LoggerProvider();

  /// Creates or retrieves a [Logger] for the given [category].
  ///
  /// [category] is the fully-qualified name passed to `LoggerFactory.createLogger`,
  /// typically a class name or a dotted namespace string.
  Logger createLogger(String category);

  /// Releases all resources held by this provider.
  ///
  /// Called automatically when the parent `LoggerFactory` is disposed.
  /// The default implementation is a no-op. Overrides **must** be idempotent.
  void dispose() {}
}
