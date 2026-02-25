import 'package:davianspace_dependencyinjection/davianspace_dependencyinjection.dart';

import '../abstractions/logger.dart';
import '../abstractions/logger_factory.dart';
import '../core/logger_factory_impl.dart';

// =============================================================================
// LoggingServiceCollectionExtensions
// =============================================================================

/// Extension methods that register `davianspace_logging` types into
/// `ServiceCollection`.
///
/// ## Quick start
///
/// ```dart
/// final provider = ServiceCollection()
///   ..addLogging((logging) => logging
///       .addConsole()
///       .setMinimumLevel(LogLevel.info))
///   .buildServiceProvider();
///
/// // Inject:
/// final factory = provider.getRequired<LoggerFactory>();
/// final logger  = factory.createLogger('OrderService');
/// logger.info('Order created', properties: {'orderId': id});
/// ```
extension LoggingServiceCollectionExtensions on ServiceCollection {
  // -------------------------------------------------------------------------
  // addLogging
  // -------------------------------------------------------------------------

  /// Registers a singleton [LoggerFactory], optionally applying [configure]
  /// to add providers, set minimum level, and configure filters.
  ///
  /// Uses try-add semantics: if [LoggerFactory] is already registered this
  /// method is a no-op (the existing registration is kept).
  ///
  /// The factory is disposed automatically when the `ServiceProvider` is
  /// disposed.
  ///
  /// ```dart
  /// services.addLogging((logging) => logging
  ///     .addConsole()
  ///     .setMinimumLevel(LogLevel.warning));
  /// ```
  ServiceCollection addLogging([
    void Function(LoggingBuilder)? configure,
  ]) {
    if (!isRegistered<LoggerFactory>()) {
      addSingletonFactory<LoggerFactory>((_) {
        final builder = LoggingBuilder();
        configure?.call(builder);
        return builder.build();
      });

      // Register a transient Logger factory resolved by runtime type name of
      // the consumer. Consumers that need a category-specific logger should
      // resolve [LoggerFactory] directly and call [LoggerFactory.createLogger].
      addTransientFactory<Logger>(
        (sp) => sp.getRequired<LoggerFactory>().createLogger('Default'),
      );
    }
    return this;
  }
}
