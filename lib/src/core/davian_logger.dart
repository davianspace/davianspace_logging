import 'package:davianspace_logging/davianspace_logging.dart';

// ── DavianLogger ───────────────────────────────────────────────────────────

/// Static helper class providing pre-configured [Logger] and [LoggerFactory]
/// instances for common scenarios where a full [LoggingBuilder] setup is
/// unnecessary.
///
/// ## Quick console logger
///
/// ```dart
/// final logger = DavianLogger.quick();
/// logger.info('App started');
/// ```
///
/// ## Named quick logger
///
/// ```dart
/// final logger = DavianLogger.quick(
///   category: 'OrderService',
///   minimumLevel: LogLevel.warning,
/// );
/// ```
///
/// Loggers obtained from [quick] share a single internal [LoggerFactory]
/// (`_quickFactory`) backed by a [ConsoleLoggerProvider]. The factory is
/// rebuilt automatically when `minimumLevel` changes between calls.
///
/// Call [disposeQuickFactory] during application shutdown in long-running Dart
/// CLI or server processes to release underlying provider resources.
abstract final class DavianLogger {
  // ── Quick factory ──────────────────────────────────────────────────────────

  /// Returns a console-backed [Logger] configured with sensible defaults.
  ///
  /// Repeated calls with the same [category] and [minimumLevel] return a
  /// cached logger instance from the shared quick factory.
  ///
  /// [category] defaults to `'App'`.
  /// [minimumLevel] defaults to [LogLevel.debug].
  ///
  /// The logger writes formatted output to `stdout` using [SimpleFormatter].
  /// Switch to `DavianLogger.quickFactory().createLogger(...)` when you need
  /// fine-grained control over the provider or formatter.
  ///
  /// ```dart
  /// final logger = DavianLogger.quick();
  /// logger.debug('Starting…');
  /// logger.info('Ready');
  /// ```
  static Logger quick({
    String category = 'App',
    LogLevel minimumLevel = LogLevel.debug,
  }) {
    _ensureQuickFactory(minimumLevel);
    return _quickFactory!.createLogger(category);
  }

  /// Returns the shared [LoggerFactory] used by [quick].
  ///
  /// Use this when you need multiple loggers from the same pre-configured
  /// console factory without calling [LoggingBuilder] manually.
  ///
  /// ```dart
  /// final factory = DavianLogger.quickFactory();
  /// final serviceA = factory.createLogger('ServiceA');
  /// final serviceB = factory.createLogger('ServiceB');
  /// ```
  static LoggerFactory quickFactory({
    LogLevel minimumLevel = LogLevel.debug,
  }) {
    _ensureQuickFactory(minimumLevel);
    return _quickFactory!;
  }

  /// Disposes the shared quick factory and releases its resources.
  ///
  /// After this call the next invocation of [quick] or [quickFactory]
  /// automatically rebuilds the factory.
  ///
  /// Typically only needed in long-running Dart CLI or server applications
  /// that want deterministic resource cleanup on shutdown.
  static void disposeQuickFactory() {
    _quickFactory?.dispose();
    _quickFactory = null;
    _quickFactoryLevel = null;
  }

  // ── Internal state ─────────────────────────────────────────────────────────

  static LoggerFactory? _quickFactory;
  static LogLevel? _quickFactoryLevel;

  static void _ensureQuickFactory(LogLevel minimumLevel) {
    if (_quickFactory == null || _quickFactoryLevel != minimumLevel) {
      _quickFactory?.dispose();
      _quickFactory =
          LoggingBuilder().addConsole().setMinimumLevel(minimumLevel).build();
      _quickFactoryLevel = minimumLevel;
    }
  }
}
