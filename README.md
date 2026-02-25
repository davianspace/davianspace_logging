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
| **Tag-based logging** | Lightweight secondary classification via `LoggerTagExtension` |
| **Exception helper** | Structured `logException` with automatic `errorType`/`errorMessage` properties |
| **HTTP interceptor** | Framework-agnostic `HttpLogInterceptor` for any HTTP client |
| **Memory export** | `MemoryLogStore.exportAsJson()` and `eventsForTag()` for testing and auditing |
| **Quick setup** | `DavianLogger.quick()` returns a console logger with zero configuration |
| **No dependencies** | Pure Dart; works on all platforms (CLI, Flutter, server) |

---

## Quick start

### Option A  One-liner with `DavianLogger.quick()`

The fastest way to get a working logger without any setup:

```dart
import 'package:davianspace_logging/davianspace_logging.dart';

void main() {
  final logger = DavianLogger.quick();          // console-backed, debug+

  logger.info('Application started');
  logger.warning('Config file not found');
  logger.error('Unexpected failure', error: exception, stackTrace: st);

  DavianLogger.disposeQuickFactory();           // release resources on exit
}
```

### Option B  Full `LoggingBuilder` setup

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
    
    
LoggerFactory (LoggerFactoryImpl)
     FilterRuleSet          routing decisions
     TimestampProvider      injectable clock
     List<LoggerProvider>
             ConsoleLoggerProvider  ConsoleLogger (stdout + ANSI color)
             DebugLoggerProvider    DebugLogger   (dart:developer)
             MemoryLoggerProvider   MemoryLogger  (in-memory store)

LoggerFactory.createLogger("Category")
     LoggerImpl   active LoggingScope (Zone-propagated)
            
            
          LogEvent (immutable, shared across providers)
             level, category, message, timestamp
             properties      caller-supplied structured data
             scopeProperties  merged from LoggingScope chain
```

---

## Log levels

```dart
enum LogLevel { trace, debug, info, warning, error, critical, none }
```

Levels are ordered from least to most severe; `none` suppresses all output:

| Level | Label | Typical use |
|---|---|---|
| `trace` | `TRCE` | Step-by-step internal flow; disabled in production by default |
| `debug` | `DBUG` | Developer diagnostics; useful during development |
| `info` | `INFO` | Normal application milestones (startup, requests, etc.) |
| `warning` | `WARN` | Recoverable, unexpected situations that deserve attention |
| `error` | `EROR` | Failures preventing the current operation from completing |
| `critical` | `CRIT` | Unrecoverable failures requiring immediate intervention |
| `none` |  | Sentinel; disables all output for the target scope |

```dart
logger.isEnabled(LogLevel.debug);   // true / false depending on config

// isAtLeast helper on the enum itself:
LogLevel.warning.isAtLeast(LogLevel.info);  // true
LogLevel.debug.isAtLeast(LogLevel.info);    // false
```

---

## Structured properties

Properties are kept separate from the message so every provider can decide
whether to render them inline (text) or persist them as structured fields (JSON):

```dart
logger.info(
  'Order placed',
  properties: {
    'orderId':  1042,
    'amount':   299.99,
    'currency': 'USD',
  },
);
```

Avoid string interpolation of domain objects inside the message itself  they
belong in `properties` so downstream consumers (log aggregators, alerting
systems) can query and index them.

---

## Quick setup  `DavianLogger`

`DavianLogger` is a static helper for scenarios where a full `LoggingBuilder`
pipeline is unnecessary. All three entry points share a single internal
`ConsoleLoggerProvider`-backed factory that is rebuilt automatically if the
minimum level changes.

```dart
// Single logger with default category ('App') and level (debug+)
final log = DavianLogger.quick();

// Named category + custom minimum level
final serviceLog = DavianLogger.quick(
  category: 'OrderService',
  minimumLevel: LogLevel.warning,
);

// Multiple loggers from the shared factory in one step
final factory = DavianLogger.quickFactory(minimumLevel: LogLevel.info);
final authLog  = factory.createLogger('Auth');
final dbLog    = factory.createLogger('Database');

// Deterministic cleanup (recommended in CLI / server apps at shutdown)
DavianLogger.disposeQuickFactory();
```

After `disposeQuickFactory()` the next call to `quick()` or `quickFactory()`
automatically rebuilds the factory.

---

## Tag-based logging  `LoggerTagExtension`

Tags provide a lightweight secondary classification for log entries, orthogonal
to category and level. Tags are stored under the reserved property key `'tag'`
and are preserved by every provider.

```dart
// Emit at a specific level with a tag
logger.logTagged(LogLevel.info, 'auth', 'User signed in',
    properties: {'userId': 42});

// Per-level convenience variants
logger.traceTagged('lifecycle', 'Widget built');
logger.debugTagged('cache',     'Cache miss for key $key');
logger.infoTagged('auth',       'Token refreshed');
logger.warningTagged('payment', 'Retry attempt 1');
logger.errorTagged('payment',   'Charge failed', error: ex, stackTrace: st);
logger.criticalTagged('database', 'Connection pool exhausted');
```

Query tagged events when using `MemoryLogStore`:

```dart
final authEvents = store.eventsForTag('auth');
```

The tag key is accessible as `LoggerTagExtension.tagKey` (`'tag'`) for
consumers that inspect `LogEvent.properties` directly.

---

## Exception helper  `LoggerExceptionExtension`

`logException` reduces the boilerplate of logging caught exceptions by
automatically deriving the message and attaching standard `errorType` /
`errorMessage` properties:

```dart
try {
  await fetchOrder(id);
} catch (e, st) {
  logger.logException(e, st,
      message: 'Failed to fetch order',
      properties: {'orderId': id});
}
```

Properties always present on every `logException` call:

| Property | Value |
|---|---|
| `errorType` | `error.runtimeType.toString()` |
| `errorMessage` | `error.toString()` |

When `message` is omitted the message is derived automatically:
- If `error.toString()` already starts with the type name (e.g. `TypeError: ...`), it is used as-is.
- Otherwise the message becomes `"TypeName: error.toString()"`.

Additional `properties` are merged on top and may override the built-in keys.

```dart
// Minimal  message auto-derived from the error
logger.logException(e, st);

// Custom level
logger.logException(e, st, level: LogLevel.critical);

// Full form
logger.logException(
  e, st,
  level: LogLevel.error,
  message: 'Order processing failed',
  properties: {'orderId': 1042, 'stage': 'payment'},
);
```

---

## HTTP interceptor  `HttpLogInterceptor`

`HttpLogInterceptor` wraps a `Logger` and exposes three callbacks  `onRequest`,
`onResponse`, and `onError`  that can be wired into any HTTP client interceptor
without a direct dependency on `dio`, `http`, or any other network package.

```dart
final interceptor = HttpLogInterceptor(
  logger,
  requestLevel:  LogLevel.debug,   // default
  responseLevel: LogLevel.debug,   // default
  errorLevel:    LogLevel.error,   // default
  logHeaders:    false,            // set true to include headers (avoid in prod)
  logBody:       false,            // set true to include bodies (use with caution)
);

// Wire into your HTTP client's lifecycle:
interceptor.onRequest('GET', 'https://api.example.com/orders/1');
interceptor.onResponse(200, 'https://api.example.com/orders/1', durationMs: 42);
interceptor.onError('GET', 'https://api.example.com/orders/1', error, st);
```

Properties stored per call:

| Method | Property keys |
|---|---|
| `onRequest` | `http.method`, `http.url`, `http.request.headers`*, `http.request.body`* |
| `onResponse` | `http.status`, `http.url`, `http.durationMs`, `http.response.headers`*, `http.response.body`* |
| `onError` | `http.method`, `http.url`, `http.status` |

\* Only when `logHeaders` / `logBody` is `true` and the value is non-null.
 Optional; omitted when not provided.

### Dio integration

```dart
import 'package:dio/dio.dart';
import 'package:davianspace_logging/davianspace_logging.dart';

class DioLoggingInterceptor extends Interceptor {
  DioLoggingInterceptor(Logger logger)
      : _http = HttpLogInterceptor(logger);
  final HttpLogInterceptor _http;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _http.onRequest(options.method, options.uri.toString(),
        headers: Map<String, Object?>.from(options.headers));
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _http.onResponse(
        response.statusCode ?? 0, response.realUri.toString());
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _http.onError(
        err.requestOptions.method, err.requestOptions.uri.toString(),
        err, err.stackTrace ?? StackTrace.current);
    handler.next(err);
  }
}
```

### `package:http` integration

```dart
import 'package:http/http.dart' as http;
import 'package:davianspace_logging/davianspace_logging.dart';

class LoggingClient extends http.BaseClient {
  LoggingClient(Logger logger, http.Client inner)
      : _http = HttpLogInterceptor(logger), _inner = inner;
  final HttpLogInterceptor _http;
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    _http.onRequest(request.method, request.url.toString());
    try {
      final response = await _inner.send(request);
      _http.onResponse(response.statusCode, request.url.toString());
      return response;
    } catch (e, st) {
      _http.onError(request.method, request.url.toString(), e, st);
      rethrow;
    }
  }
}
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

`categoryPrefix` performs a **prefix match**  `'network'` silences both
`network.http` and `network.grpc`.

---

## Scoped logging

Scopes carry contextual properties through an entire async call chain via Dart's
`Zone` mechanism  no manual threading required:

```dart
final scope = logger.beginScope({
  'requestId': request.id,
  'userId':    request.userId,
});

await scope.runAsync(() async {
  logger.info('Processing');          //  includes requestId + userId
  await callDownstream();
  logger.info('Done');                //  still includes requestId + userId
});
```

Scopes nest; child properties override parent properties with the same key.
Synchronous code is covered too:

```dart
scope.run(() {
  logger.debug('Synchronous work');
});
```

---

## Formatters

### Simple (default)

```
2026-02-25T14:23:01.123456Z [INFO ] OrderService  Order placed  {orderId: 1042}
```

Disable the timestamp for cleaner test output:

```dart
.addConsole(formatter: const SimpleFormatter(includeTimestamp: false))
```

### JSON

```json
{"timestamp":"2026-02-25T14:23:01.123456Z","level":"info","category":"OrderService","message":"Order placed","properties":{"orderId":1042}}
```

Register on any provider:

```dart
LoggingBuilder()
  .addConsole(formatter: const JsonFormatter())
  .build();
```

### Custom formatter

Implement `LogFormatter` to produce any output format:

```dart
final class MyFormatter implements LogFormatter {
  @override
  String format(LogEvent event) =>
      '[${event.level.label}] ${event.category}: ${event.message}';
}
```

---

## Providers

### Console (`ConsoleLoggerProvider`)

Writes ANSI-colored output to `stdout` via `dart:io`. Available on all platforms
except the web.

```dart
LoggingBuilder()
  .addConsole()
  .addConsole(formatter: const JsonFormatter())  // custom formatter
  .build();
```

### Debug (`DebugLoggerProvider`)

Writes to `dart:developer`'s `log()`, visible in Flutter/Dart DevTools.
Works on all platforms including the web.

```dart
LoggingBuilder()
  .addDebug()
  .build();
```

### Memory (`MemoryLoggerProvider` + `MemoryLogStore`)

Stores events in memory; primarily intended for unit and integration tests.

```dart
final store = MemoryLogStore();                  // unbounded
final store = MemoryLogStore(maxCapacity: 500);  // ring-buffer, evicts oldest
```

Query methods on `MemoryLogStore`:

```dart
store.events;                              // all events (unmodifiable list)
store.length;                              // total event count
store.isEmpty;                             // true when no events
store.isNotEmpty;                          // true when at least one event

store.eventsAtOrAbove(LogLevel.warning);   // warning + error + critical
store.eventsForCategory('OrderService');   // events from one category
store.eventsForTag('auth');               // events with properties['tag'] == 'auth'

store.exportAsJson();                      // JSON string of all events
store.clear();                             // wipe the store
```

#### `exportAsJson` format

```json
[
  {
    "timestamp":       "2026-02-25T14:23:01.123456Z",
    "level":           "info",
    "category":        "OrderService",
    "message":         "Order placed",
    "properties":      { "orderId": 1042 },
    "scopeProperties": { "requestId": "req-A" },
    "error":           "Exception: Card declined",
    "stackTrace":      "..."
  }
]
```

`properties`, `scopeProperties`, `error`, and `stackTrace` are omitted when
absent/empty. Returns `'[]'` when the store is empty.

### Null (`NullLoggerProvider` / `NullLogger`)

Discards every entry. `NullLogger` is useful as a no-op default for optional
logger dependencies.

```dart
LoggingBuilder().addProvider(NullLoggerProvider()).build();

// Use NullLogger directly for optional dependencies:
class MyService {
  MyService({Logger? logger}) : _logger = logger ?? NullLogger();
  final Logger _logger;
}
```

### Custom providers

```dart
final class SyslogProvider implements LoggerProvider {
  @override
  Logger createLogger(String category) =>
      SyslogLogger(category: category);

  @override
  void dispose() { /* close socket */ }
}

LoggingBuilder().addProvider(SyslogProvider()).build();
```

Implement `EventLogger` (extends `Logger`) to receive a fully assembled
`LogEvent` including scope-merged properties, avoiding double-allocation:

```dart
final class SyslogLogger implements EventLogger {
  SyslogLogger({required this.category});

  @override
  final String category;

  @override
  bool isEnabled(LogLevel level) => level != LogLevel.none;

  @override
  void write(LogEvent event) => syslog(event.level.label, event.message);

  @override
  LoggingScope beginScope(Map<String, Object?> properties) =>
      LoggingScope(properties);
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

  final logger = factory.createLogger('OrderService');
  logger.info('Order placed', properties: {'orderId': 1042});

  final event = store.events.single;
  expect(event.level,                 equals(LogLevel.info));
  expect(event.message,               equals('Order placed'));
  expect(event.properties['orderId'], equals(1042));
  factory.dispose();
});

test('logException captures errorType and errorMessage', () {
  final store = MemoryLogStore();
  final factory = LoggingBuilder()
      .addMemory(store: store)
      .setMinimumLevel(LogLevel.trace)
      .build();
  final logger = factory.createLogger('Service');

  final err = FormatException('bad input');
  logger.logException(err, StackTrace.current,
      message: 'Validation failed',
      properties: {'field': 'email'});

  final event = store.events.single;
  expect(event.properties['errorType'],    equals('FormatException'));
  expect(event.properties['errorMessage'], equals('bad input'));
  expect(event.properties['field'],        equals('email'));
  factory.dispose();
});

test('eventsForTag returns tagged events only', () {
  final store = MemoryLogStore();
  final factory = LoggingBuilder()
      .addMemory(store: store)
      .setMinimumLevel(LogLevel.trace)
      .build();
  final logger = factory.createLogger('App');

  logger.infoTagged('auth', 'Login');
  logger.info('Untagged event');

  expect(store.eventsForTag('auth'), hasLength(1));
  factory.dispose();
});
```

---

## Performance

- **Zero allocations** when a log level is disabled  `isEnabled` exits before any object is created.
- **Single `LogEvent` allocation** per `log()` call, shared across all providers.
- **Zone-local scope lookup**  O(1) read, no contention.
- **No reflection**  category names are plain strings; no `dart:mirrors`.
- **Lazy initialisation**  provider caches are populated on first access.
- **O(1) eviction** in `MemoryLogStore`  uses `ListQueue` for front removal.

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
| `using var scope = ` | `await scope.runAsync(() async {  })` |
| `AddConsole()` | `.addConsole()` on `LoggingBuilder` |
| `AddDebug()` | `.addDebug()` on `LoggingBuilder` |
| Structured logging templates | Plain message + `properties` map |
| `IDisposable` | `dispose()` on factory and providers |
| `BeginScope` chaining | Nested `beginScope` calls (child overrides parent keys) |

### Key differences

- Dart has no `IDisposable` / `using`; use `scope.run(...)` / `scope.runAsync(...)` for scope lifetime management.
- Structured properties use a `Map<String, Object?>` instead of C# message templates.
- No DI container required  `LoggingBuilder` covers provider registration and configuration.
- Providers register `LoggingBuilder` extensions in their own source file rather than via `IServiceCollection`.
- `DavianLogger.quick()` provides a zero-config console logger equivalent to `host.Services.GetRequiredService<ILogger<T>>()`.

---

## License

MIT  2026 Davian Space
