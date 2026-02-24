/// davianspace_logging
/// ─────────────────────────────────────────────────────────────────────────────
/// Enterprise-grade structured logging framework for Dart and Flutter.
/// Conceptually equivalent to Microsoft.Extensions.Logging, expressed
/// idiomatically in Dart.
///
/// ## Core abstractions
/// - `LogLevel`          – trace / debug / info / warning / error / critical / none.
/// - `LogEvent`          – immutable structured log entry (the central data carrier).
/// - `Logger`            – primary logging interface with convenience methods.
/// - `LoggerFactory`     – creates `Logger` instances by category name.
/// - `LoggerProvider`    – pluggable logging back-end interface.
///
/// ## Core implementations
/// - `LoggingBuilder`       – fluent factory builder (start here).
/// - `LoggerFactoryImpl`    – default `LoggerFactory` with caching and disposal.
/// - `FilterRule`           – single provider/category/level filter rule.
/// - `FilterRuleSet`        – ordered rule collection with specificity resolution.
/// - `LoggingScope`         – Zone-aware async-safe scope context.
///
/// ## Built-in providers
/// - `ConsoleLoggerProvider` – colored `stdout` output (`dart:io`).
/// - `DebugLoggerProvider`   – `dart:developer` log output (all platforms).
/// - `MemoryLoggerProvider`  – in-memory store for testing.
/// - `MemoryLogStore`        – queryable log event store used with `MemoryLoggerProvider`.
/// - `NullLoggerProvider`    – discards all entries; useful as a null object / test stub.
/// - `NullLogger`            – no-op `Logger` for optional dependency injection.
///
/// ## Formatters
/// - `LogFormatter`     – abstract formatter interface.
/// - `SimpleFormatter`  – single-line human-readable output.
/// - `JsonFormatter`    – structured single-line JSON output.
///
/// ## Utilities
/// - `TimestampProvider`    – injectable clock abstraction.
/// - `UtcTimestampProvider` – default UTC clock implementation.
///
/// ## Quick start
///
/// ```dart
/// import 'package:davianspace_logging/davianspace_logging.dart';
///
/// void main() {
///   final factory = LoggingBuilder()
///     .addConsole()
///     .setMinimumLevel(LogLevel.debug)
///     .build();
///
///   final logger = factory.createLogger('MyApp');
///   logger.info('Application started');
///
///   logger.info(
///     'User logged in',
///     properties: {'userId': 42, 'role': 'admin'},
///   );
///
///   factory.dispose();
/// }
/// ```

library;

// ── Abstractions ───────────────────────────────────────────────────────────
export 'src/abstractions/log_event.dart';
export 'src/abstractions/log_level.dart';
export 'src/abstractions/logger.dart';
export 'src/abstractions/logger_factory.dart';
export 'src/abstractions/logger_provider.dart';
// ── Core ───────────────────────────────────────────────────────────────────
export 'src/core/filter_rules.dart';
export 'src/core/logger_factory_impl.dart';
export 'src/core/logger_impl.dart' show EventLogger, LoggerEntry;
export 'src/core/logging_scope.dart';
// ── Formatting ─────────────────────────────────────────────────────────────
export 'src/formatting/json_formatter.dart';
export 'src/formatting/log_formatter.dart';
export 'src/formatting/simple_formatter.dart';
// ── Providers ──────────────────────────────────────────────────────────────
export 'src/providers/console_logger.dart';
export 'src/providers/debug_logger.dart';
export 'src/providers/memory_logger.dart';
export 'src/providers/null_logger.dart';
// ── Utilities ──────────────────────────────────────────────────────────────
export 'src/utils/timestamp_provider.dart';
