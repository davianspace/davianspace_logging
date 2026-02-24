import 'logger.dart';
import 'logger_provider.dart';

/// Creates [Logger] instances scoped to named categories and manages the
/// registered [LoggerProvider] collection.
///
/// Obtain a factory via `LoggingBuilder`:
///
/// ```dart
/// final factory = LoggingBuilder()
///   .addConsole()
///   .setMinimumLevel(LogLevel.info)
///   .build();
///
/// final logger = factory.createLogger('OrderService');
/// ```
///
/// The factory maintains one [Logger] per category and caches them for the
/// application lifetime. Loggers are lightweight facade objects; the actual
/// work is performed by the registered providers.
///
/// **Disposal:** Call [dispose] when the application shuts down to release
/// provider resources.
abstract interface class LoggerFactory {
  /// Returns a [Logger] for the given [category].
  ///
  /// Repeated calls with the same [category] return a cached instance.
  /// The [category] string is conventionally a class name or dotted namespace
  /// (e.g. `'com.example.AuthService'`).
  Logger createLogger(String category);

  /// Adds [provider] to the factory's provider collection.
  ///
  /// Loggers already created before this call will begin routing to the new
  /// provider on their next [Logger.log] invocation.
  void addProvider(LoggerProvider provider);

  /// Releases all resources held by the factory and its providers.
  ///
  /// After disposal, calls to [createLogger] and [addProvider] throw a
  /// [StateError]. Any [Logger] instances already obtained from this factory
  /// become no-ops: they continue to accept calls but produce no output,
  /// because their internal provider list has been cleared.
  void dispose();
}
