# davianspace_logging

Enterprise-grade structured logging framework for Dart and Flutter.
Conceptually equivalent to **Microsoft.Extensions.Logging**, expressed idiomatically in Dart.

[![pub.dev](https://img.shields.io/pub/v/davianspace_logging)](https://pub.dev/packages/davianspace_logging)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## Features

| Capability | Description |
|---|---|
| **Structured logging** | Properties stored separately from messages; providers decide formatting |
| **Multiple providers** | Console, debug, memory, and custom providers run simultaneously |
| **Log-level filtering** | Global floor, category-prefix rules, and provider-specific rules |
| **Scoped contexts** | Zone-aware async-safe scopes automatically inject contextual properties |
| **Logger factory** | Category-based logger creation with lifetime management |
| **Pluggable formatters** | Simple text and JSON out of the box; implement `LogFormatter` for custom |
| **Zero allocations** | Fast-path exits before allocating when log level is disabled |
| **No dependencies** | Pure Dart; works on all platforms (CLI, Flutter, server) |

---

## Quick start

```dart
import 'package:davianspace_logging/davianspace_logging.dart';

void main() {
  final factory = LoggingBuilder()
    .addConsole()
    .setMinimumLevel(LogLevel.info)
    .build();

  final logger = factory.createLogger('MyApp');

  logger.info('Application started');
  logger.info('User logged in', properties: {'userId': 42, 'role': 'admin'});
  logger.warning('Disk space low', properties: {'freeGb': 1.2});
  logger.error('Unexpected failure', error: exception, stackTrace: st);

  factory.dispose();
}
```

---

## Architecture

```
LoggingBuilder
    │
    ▼
LoggerFactory (LoggerFactoryImpl)
    ├── FilterRuleSet         ← routing decisions
    ├── TimestampProvider     ← injectable clock
    └── List<LoggerProvider>
            ├── ConsoleLoggerProvider ── ConsoleLogger (stdout + ANSI color)
            ├── DebugLoggerProvider   ── DebugLogger   (dart:developer)
            └── MemoryLoggerProvider  ── MemoryLogger  (in-memory store)

LoggerFactory.createLogger("Category")
    └── LoggerImpl  ←── active LoggingScope (Zone-propagated)
            │
            ▼
          LogEvent (immutable, shared across providers)
            ├── level, category, message, timestamp
            ├── properties     ← caller-supplied structured data
            └── scopeProperties ← merged from LoggingScope chain
```

---

## Log levels

```dart
enum LogLevel { trace, debug, info, warning, error, critical, none }
```

Levels are ordered; `none` suppresses all output:

```dart
logger.isEnabled(LogLevel.debug);   // true / false depending on config
```

---

## Structured properties

Properties are kept separate from the message so every provider can decide
whether to render them inline (text) or persist them as structured fields (JSON):

```dart
logger.info(
  'Order placed',
  properties: {
    'orderId': 1042,
    'amount':  299.99,
    'currency': 'USD',
  },
);
```

---

## Log filtering

```dart
final factory = LoggingBuilder()
  .addConsole()
  .setMinimumLevel(LogLevel.debug)                // global floor
  .addFilterRule(FilterRule(
      categoryPrefix: 'network',
      minimumLevel:   LogLevel.error,             // noisy subsystem override
  ))
  .addFilterRule(FilterRule(
      providerType:   ConsoleLoggerProvider,
      categoryPrefix: 'metrics',
      minimumLevel:   LogLevel.none,              // silence metrics on console
  ))
  .build();
```

Rule specificity (highest wins):
1. Provider type **and** category prefix
2. Category prefix only
3. Provider type only
4. Global minimum (catch-all)

---

## Scoped logging

Scopes carry contextual properties through an entire async call chain via Dart's
`Zone` mechanism — no manual threading required:

```dart
final scope = logger.beginScope({
  'requestId': request.id,
  'userId':    request.userId,
});

await scope.runAsync(() async {
  logger.info('Processing');          // ← includes requestId + userId
  await callDownstream();
  logger.info('Done');                // ← still includes requestId + userId
});
```

Scopes nest; child properties override parent properties with the same key.

---

## Formatters

### Simple (default)

```
2026-02-25T14:23:01.123456Z [INFO ] OrderService » Order placed  {orderId: 1042}
```

### JSON

```json
{"timestamp":"2026-02-25T14:23:01.123456Z","level":"info","category":"OrderService","message":"Order placed","properties":{"orderId":1042}}
```

Register a formatter on any provider:

```dart
LoggingBuilder()
  .addConsole(formatter: JsonFormatter())
  .build();
```

Custom formatters implement `LogFormatter`:

```dart
final class MyFormatter implements LogFormatter {
  @override
  String format(LogEvent event) =>
      '[${event.level.label}] ${event.message}';
}
```

---

## Custom providers

```dart
final class SyslogProvider implements LoggerProvider {
  @override
  Logger createLogger(String category) =>
      SyslogLogger(category: category);

  @override
  void dispose() { /* close socket */ }
}

// Register:
LoggingBuilder().addProvider(SyslogProvider()).build();
```

Implement `EventLogger` (extends `Logger`) to receive a pre-built `LogEvent`
including scope-merged properties:

```dart
final class SyslogLogger implements EventLogger {
  @override
  void write(LogEvent event) => syslog(event.level.label, event.message);
  // …
}
```

---

## Testing

Use `MemoryLoggerProvider` + `MemoryLogStore` to assert log output in unit tests:

```dart
test('logs order placed at info level', () {
  final store = MemoryLogStore();
  final factory = LoggingBuilder()
      .addMemory(store: store)
      .setMinimumLevel(LogLevel.trace)
      .build();

  OrderService(factory.createLogger('OrderService'))
      .placeOrder(Order(1, 99.99));

  final event = store.events.single;
  expect(event.level, equals(LogLevel.info));
  expect(event.properties['orderId'], equals(1));
  factory.dispose();
});
```

---

## Performance

- **Zero allocations** when a log level is disabled — `isEnabled` check exits before any object is created.
- **Single `LogEvent` allocation** per `log()` call, shared across all providers.
- **Zone-local scope lookup** — O(1) read, no contention.
- **No reflection** — category names are plain strings; no `dart:mirrors`.
- **Lazy initialisation** — provider caches are populated on first access.

Use the `isEnabled` guard for expensive message construction:

```dart
if (logger.isEnabled(LogLevel.debug)) {
  logger.debug('Snapshot: ${expensiveDump()}');
}
```

---

## Migration from Microsoft.Extensions.Logging

| MEL (C#) | davianspace_logging (Dart) |
|---|---|
| `ILogger` | `Logger` (abstract interface) |
| `ILoggerFactory` | `LoggerFactory` (abstract interface) |
| `ILoggerProvider` | `LoggerProvider` (abstract interface) |
| `ILoggingBuilder` | `LoggingBuilder` (concrete builder) |
| `LogLevel` enum | `LogLevel` enum (same names, lowercase) |
| `ILogger.BeginScope(state)` | `logger.beginScope(properties)` |
| `ILoggerFactory.CreateLogger<T>()` | `factory.createLogger('TypeName')` |
| `using var scope = …` | `await scope.runAsync(() async { … })` |
| `AddConsole()` | `.addConsole()` on `LoggingBuilder` |
| Structured logging templates | Plain message + `properties` map |
| `IDisposable` | `dispose()` method on factory and providers |

### Key differences

- Dart has no `IDisposable` / `using`; use `scope.run(...)` / `scope.runAsync(...)` instead of relying on disposal for scope lifetime.
- Structured properties use a `Map<String, Object?>` instead of C# message templates.
- No dependency injection container required — `LoggingBuilder` covers DI composition.
- Providers register extensions on `LoggingBuilder` rather than via `IServiceCollection`.

---

## License

MIT © 2026 Davian Space
