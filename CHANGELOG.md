# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.4] – 2026-02-26

### Added

- **Tag-based logging** (`LoggerTagExtension`) — extension on `Logger` adding
  `logTagged`, `traceTagged`, `debugTagged`, `infoTagged`, `warningTagged`,
  `errorTagged`, and `criticalTagged` helpers. Tags are stored in
  `LogEvent.properties` under the reserved key `LoggerTagExtension.tagKey`
  (`'tag'`). Fully backward-compatible; existing `log()` calls are unchanged.
- **`MemoryLogStore.eventsForTag(String tag)`** — query all stored events by
  tag, complementing the existing `eventsForCategory` and `eventsAtOrAbove`
  helpers.
- **`MemoryLogStore.exportAsJson()`** — serialise the entire in-memory event
  log to a JSON string, suitable for snapshotting test state or reporting.
  `MemoryLogStore.clear()` already existed and continues to work as before.
- **`LoggerExceptionExtension`** — extension on `Logger` adding
  `logException(Object error, StackTrace stackTrace, {LogLevel level, String?
  message, Map? properties})`. Automatically formats the error type and message
  into structured `errorType` / `errorMessage` properties and reuses the
  existing `Logger.log` infrastructure unchanged.
- **`DavianLogger`** — static quick-setup helper. `DavianLogger.quick()` returns
  a console-backed `Logger` with sensible defaults (category `'App'`, minimum
  level `LogLevel.debug`) without requiring a full `LoggingBuilder` setup.
  Also exposes `DavianLogger.quickFactory()` and `DavianLogger.disposeQuickFactory()`.
- **`HttpLogInterceptor`** — framework-agnostic HTTP logging helper. Wraps a
  `Logger` and exposes `onRequest`, `onResponse`, and `onError` callbacks that
  can be wired into Dio, `package:http`, or any other HTTP client without
  introducing a mandatory dependency on any network package.

### Improvements

- Barrel file (`davianspace_logging.dart`) updated with new export sections
  for **Extensions** (`logger_exception_extension`, `logger_tag_extension`)
  and **Integrations** (`http_log_interceptor`), and the new **Core** export
  `davian_logger`.
- Library doc comment updated to list all new public APIs.
- Zero new analyzer warnings; all 167 tests pass (120 pre-existing +
  47 new tests covering the five added feature areas).

---

## [1.0.3] – 2026-02-25

### Added

- `davianspace_dependencyinjection` integration — `addLogging()` extension on `ServiceCollection` registers a singleton `LoggerFactory` (with auto-disposal) and a transient `Logger`.

---

## [1.0.0] – 2026-02-25

### Added

- `LogLevel` – enum with `trace`, `debug`, `info`, `warning`, `error`, `critical`, `none`.
- `Logger` – abstract interface with convenience methods (`trace`, `debug`, `info`, `warning`, `error`, `critical`).
- `LogEvent` – immutable structured log entry carrying level, category, message, properties, scope chain, timestamp, error, and stack trace.
- `LoggerFactory` – abstract interface for creating category-based loggers and managing providers.
- `LoggerProvider` – abstract interface for pluggable provider implementations.
- `LoggerFactoryImpl` – thread-safe factory implementation with provider management, filtering, and disposal.
- `LoggerImpl` – high-performance logger that broadcasts to all registered providers with zero-allocation fast-path when disabled.
- `FilterRule` / `FilterRuleSet` – global, category-prefix, and provider-specific filtering rules.
- `LoggingScope` – Zone-based async-safe scope with nested scope support and automatic disposal.
- `ConsoleLogger` – colored structured output to stdout.
- `DebugLogger` – Flutter-compatible `debugPrint`-backed logger.
- `MemoryLogger` / `MemoryLoggerProvider` – in-memory log store for testing.
- `LogFormatter` – abstract formatter interface.
- `SimpleFormatter` – single-line human-readable formatter.
- `JsonFormatter` – structured JSON formatter.
- `TimestampProvider` – injectable timestamp abstraction.
- `LoggingBuilder` – fluent builder with `addConsole()`, `addDebug()`, `addMemory()`, `setMinimumLevel()`, `addFilterRule()`, and `build()`.
- Full unit test suite.
- Comprehensive dartdoc documentation.
- README with quick-start, architecture notes, and migration guide.
