# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
