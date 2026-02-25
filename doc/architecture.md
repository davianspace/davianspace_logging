# Architecture

This document describes the internal design of `davianspace_logging`, the
decisions behind key patterns, and guidance for contributors.

---

## Table of contents

- [Overview](#overview)
- [Design principles](#design-principles)
- [Package layout](#package-layout)
- [Dependency graph](#dependency-graph)
- [Component diagram](#component-diagram)
- [Boot pipeline](#boot-pipeline)
- [Log call dispatch](#log-call-dispatch)
- [Filter rule resolution](#filter-rule-resolution)
- [Scope system](#scope-system)
- [Provider model](#provider-model)
- [EventLogger interface](#eventlogger-interface)
- [LogEvent immutability](#logevent-immutability)
- [Extensions](#extensions)
- [Quick setup helper](#quick-setup-helper)
- [Memory store and export](#memory-store-and-export)
- [Timestamp abstraction](#timestamp-abstraction)
- [Disposal model](#disposal-model)
- [Design decisions](#design-decisions)

---

## Overview

`davianspace_logging` is a structured logging framework for Dart and Flutter,
conceptually equivalent to **Microsoft.Extensions.Logging** but expressed
idiomatically in Dart with:

- Zero allocations on the fast path when a level is disabled.
- A single `LogEvent` allocation per `log()` call regardless of provider count.
- Zone-aware async-safe scopes with no manual threading.
- A builder-based provider registration model.
- No reflection, no code generation, and full tree-shaking support.

---

## Design principles

| Principle | Application |
|---|---|
| **Zero allocations on fast path** | `isEnabled` check exits before allocating when level is below minimum |
| **Single allocation per call** | One `LogEvent` is created and shared across all accepting providers |
| **Zero reflection** | No `dart:mirrors` — AOT-safe and tree-shaken on all platforms |
| **Separation of abstractions** | Interfaces in `abstractions/`, implementations in `core/` |
| **Immutable data carrier** | `LogEvent` maps are defensively copied and wrapped in unmodifiable views |
| **Provider-agnostic routing** | Filter rules are evaluated centrally; providers receive only events they accept |
| **Zone-based scope propagation** | Async context is inherited through Dart's `Zone` mechanism, not manually threaded |
| **Pluggable sinks** | Any back-end is supported by implementing two methods: `createLogger` and `dispose` |

---

## Package layout

```
davianspace_logging/
├── lib/
│   ├── davianspace_logging.dart    ← single barrel export
│   └── src/
│       ├── abstractions/           ← public interfaces (no implementations)
│       │   ├── log_event.dart      (immutable data carrier)
│       │   ├── log_level.dart      (enum + isAtLeast, label)
│       │   ├── logger.dart         (Logger interface + LoggerConvenienceExtension)
│       │   ├── logger_factory.dart (LoggerFactory interface)
│       │   └── logger_provider.dart (LoggerProvider abstract class)
│       │
│       ├── core/                   ← concrete framework machinery
│       │   ├── davian_logger.dart  (DavianLogger static quick-setup helper)
│       │   ├── filter_rules.dart   (FilterRule + FilterRuleSet)
│       │   ├── logger_factory_impl.dart (LoggerFactoryImpl — caching factory)
│       │   ├── logger_impl.dart    (LoggerImpl + EventLogger interface + LoggerEntry)
│       │   └── logging_scope.dart  (LoggingScope — Zone-based context)
│       │
│       ├── extensions/             ← Logger extension methods
│       │   ├── logger_exception_extension.dart (LoggerExceptionExtension)
│       │   ├── logger_tag_extension.dart       (LoggerTagExtension)
│       │   └── logging_di_extensions.dart      (LoggingBuilder extensions)
│       │
│       ├── formatting/             ← log event → string renderers
│       │   ├── json_formatter.dart    (JsonFormatter)
│       │   ├── log_formatter.dart     (LogFormatter interface)
│       │   └── simple_formatter.dart  (SimpleFormatter)
│       │
│       ├── integrations/           ← framework-agnostic integration bridges
│       │   └── http_log_interceptor.dart (HttpLogInterceptor)
│       │
│       ├── providers/              ← built-in LoggerProvider implementations
│       │   ├── console_logger.dart (ConsoleLoggerProvider + ANSI color output)
│       │   ├── debug_logger.dart   (DebugLoggerProvider + dart:developer)
│       │   ├── memory_logger.dart  (MemoryLoggerProvider + MemoryLogStore)
│       │   └── null_logger.dart    (NullLoggerProvider + NullLogger)
│       │
│       └── utils/
│           └── timestamp_provider.dart (TimestampProvider + UtcTimestampProvider)
│
├── test/                           ← 167 tests across 12 files
│   ├── davianspace_logging_test.dart
│   ├── exception_helper_test.dart
│   ├── http_interceptor_test.dart
│   ├── memory_export_test.dart
│   ├── quick_setup_test.dart
│   ├── tag_logging_test.dart
│   └── collection/
│
├── example/
│   └── example.dart               (12 runnable examples)
│
├── doc/
│   └── architecture.md            ← this file
│
├── CHANGELOG.md
├── CONTRIBUTING.md
├── SECURITY.md
├── LICENSE                        (MIT)
├── README.md
├── pubspec.yaml
└── analysis_options.yaml          (strict-casts, strict-inference, strict-raw-types)
```

---

## Dependency graph

```
 ┌─────────────┐
 │ extensions  │  LoggerTagExtension, LoggerExceptionExtension,
 │             │  LoggingBuilder extensions (logging_di_extensions)
 └──────┬──────┘
        │  depends on
        ▼
 ┌──────────────┐
 │ core         │  DavianLogger, LoggerFactoryImpl, LoggerImpl,
 │              │  FilterRuleSet, LoggingScope
 └──────┬───────┘
        │  depends on
        ▼
 ┌──────────────┐
 │ abstractions │  Logger, LoggerFactory, LoggerProvider, LogEvent, LogLevel
 └──────────────┘  (no internal dependencies — pure interfaces)

 ┌──────────────┐
 │ providers    │  ConsoleLoggerProvider, DebugLoggerProvider,
 │              │  MemoryLoggerProvider, NullLoggerProvider
 └──────┬───────┘
        │  depends on
        ▼
 ┌──────────────┐
 │ abstractions │  (same leaf node as above)
 └──────────────┘

 ┌──────────────┐
 │ formatting   │  LogFormatter, SimpleFormatter, JsonFormatter
 └──────┬───────┘
        │  depends on
        ▼
 ┌──────────────┐
 │ abstractions │  (same leaf node)
 └──────────────┘

 ┌──────────────────┐
 │ integrations     │  HttpLogInterceptor
 └────────┬─────────┘
          │  depends on
          ▼
 ┌──────────────┐
 │ abstractions │  (Logger, LogLevel only)
 └──────────────┘
```

All arrows point inward. No layer has a compile-time dependency on any layer
above it. `extensions` and `providers` are peers — neither depends on the
other.

---

## Component diagram

```
LoggingBuilder (fluent builder)
    │  .addConsole() / .addDebug() / .addMemory() / .addProvider()
    │  .setMinimumLevel()
    │  .addFilterRule()
    │  .build()
    ▼
LoggerFactoryImpl
    ├── List<LoggerProvider>         providers registered at build time
    │       ├── ConsoleLoggerProvider
    │       ├── DebugLoggerProvider
    │       └── MemoryLoggerProvider
    │
    ├── FilterRuleSet                one shared instance, immutable after build
    │       └── List<FilterRule>     ordered by registration
    │
    ├── TimestampProvider            injectable clock (UtcTimestampProvider default)
    │
    ├── Map<category, LoggerImpl>    _loggerCache — one LoggerImpl per category
    └── Map<category, List<LoggerEntry>> _entryCache — one entry list per category
                                        (referenced by LoggerImpl; mutated on addProvider)

LoggerFactory.createLogger("Category")
    └── LoggerImpl
            ├── _category: String
            ├── _entries: List<LoggerEntry>    ← shared reference from _entryCache
            │       each entry: (providerType: Type, logger: Logger)
            ├── _rules: FilterRuleSet          ← shared reference
            └── _timestampProvider             ← shared reference
                    │
                    │ .log(level, message, …)
                    ▼
              FilterRuleSet.isEnabled(…)   zero-allocation fast-path check
                    │  any provider enabled?
                    ├─ no  → return immediately (zero allocations)
                    └─ yes → LoggingScope.current → merge scopeProperties
                             → allocate one LogEvent
                             → dispatch to each enabled provider
                                  ├── EventLogger.write(event)    (built-in providers)
                                  └── Logger.log(…)               (external providers, no scope)
```

---

## Boot pipeline

`LoggingBuilder.build()` executes a deterministic sequence:

```
LoggingBuilder.build()
  │
  ├─ 1. Collect providers
  │       List<LoggerProvider> registered via:
  │         .addConsole()  → ConsoleLoggerProvider
  │         .addDebug()    → DebugLoggerProvider
  │         .addMemory()   → MemoryLoggerProvider
  │         .addProvider() → any custom LoggerProvider
  │
  ├─ 2. Build FilterRuleSet
  │       FilterRuleSet(
  │         rules        = List<FilterRule> from .addFilterRule() calls,
  │         globalMinimum = LogLevel from .setMinimumLevel() (default: trace),
  │       )
  │
  ├─ 3. Resolve TimestampProvider
  │       UtcTimestampProvider() unless overridden via
  │       .setTimestampProvider(custom)
  │
  └─ 4. Construct and return LoggerFactoryImpl(
           providers         = collected provider list (defensive copy),
           rules             = FilterRuleSet,
           timestampProvider = resolved clock,
         )
```

The built factory is ready for immediate use; no deferred initialisation
occurs.

---

## Log call dispatch

The following sequence describes what happens on a single `logger.info(…)` call,
assuming two providers are registered (console + memory):

```
logger.info('Order placed', properties: {'orderId': 1042})
  │
  │  (delegates to logger.log(LogLevel.info, 'Order placed', …))
  │
  └─ LoggerImpl.log()
       │
       ├─ 1. Zero-allocation fast-path scan
       │       for each LoggerEntry(providerType, _) in _entries:
       │         FilterRuleSet.isEnabled(providerType, category, level)
       │       If no entry is enabled → return immediately
       │
       ├─ 2. Scope resolution (if at least one provider is enabled)
       │       scopeProps = LoggingScope.current?.effectiveProperties
       │                    ?? const {}
       │       (O(1) Zone lookup; no allocation when no scope is active)
       │
       ├─ 3. Single LogEvent allocation
       │       LogEvent(
       │         level          = LogLevel.info,
       │         category       = 'OrderService',
       │         message        = 'Order placed',
       │         timestamp      = timestampProvider.now(),
       │         properties     = {'orderId': 1042},    ← defensive copy
       │         scopeProperties = scopeProps,           ← defensive copy
       │       )
       │
       └─ 4. Dispatch loop
               for each LoggerEntry in _entries:
                 if not isEnabled(…) → skip
                 if logger is EventLogger:
                   logger.write(event)        ← built-in providers, scope included
                 else:
                   logger.log(level, message, …)  ← fallback, no scope forwarding
```

**Key property:** `LogEvent` is created exactly once per `log()` call regardless
of provider count. Each provider receives the same object reference, so
providers must not mutate it.

---

## Filter rule resolution

`FilterRuleSet.isEnabled(providerType, category, level)` works as follows:

```
for each FilterRule in _rules (registration order):
  if rule.matches(providerType, category):
    track as candidate if specificity >= current best

return best?.minimumLevel ?? globalMinimum
```

Matching is defined as:

- `rule.providerType` is `null` **or** equals the queried `providerType`.
- `rule.categoryPrefix` is `null` **or** `category.startsWith(categoryPrefix)`.

Specificity score (higher wins):

| Rule type | Score |
|---|---|
| Provider type **and** category prefix | 3 |
| Provider type only | 2 |
| Category prefix only | 1 |
| Global (no type, no prefix) | 0 |

Because the scan is O(n) over registered rules (typically very few), and the
result is not cached, the evaluation is intentionally kept simple. Memoisation
would require cache invalidation on `addProvider` and rules do not change after
`build()`.

---

## Scope system

Scopes allow structured ambient properties to be automatically injected into
every `LogEvent` emitted within their dynamic extent without being passed as
explicit arguments.

### Zone-based propagation

Each `LoggingScope` forks a new Dart `Zone` and stores itself under a private
zone-value key (`#_davianspace_logging_scope`). Because `Zone.current` is
always available anywhere in the call tree, scopes are propagated to async
continuations for free:

```
Zone.root
  └── Zone (requestId: 'req-A')              ← LoggingScope.run / runAsync
        └── Zone (txId: 'tx-99')             ← nested LoggingScope
              ├── logger.info(…)             ← sees requestId + txId
              └── await asyncHelper()        ← still sees requestId + txId
```

### Property merging

`LoggingScope.effectiveProperties` merges the chain from root to leaf:

```
parentScope.effectiveProperties = { requestId: 'req-A' }
childScope.properties           = { txId: 'tx-99', requestId: 'override' }

childScope.effectiveProperties  = {
  requestId: 'override',   ← child wins
  txId:      'tx-99',
}
```

The merged map is computed lazily (`late final`) and cached for the lifetime
of the scope. The scope chain is immutable after creation, so the cache is
always valid.

### `LoggingScope.current`

`LoggerImpl.log` reads the active scope once per call:

```dart
final activeScope = LoggingScope.current;
final scopeProps  = activeScope?.effectiveProperties ?? const {};
```

When no scope is active, `Zone.current[_zoneKey]` returns `null` and the
constant empty map is used — no allocation.

---

## Provider model

A `LoggerProvider` has two responsibilities:

1. `createLogger(category)` — return a `Logger` for the given category.
2. `dispose()` — release any owned resources.

Providers own their own logger cache (or delegate caching to the framework via
`LoggerFactoryImpl._entryCache`). The base class provides a no-op `dispose`
so providers without resources need not override it.

### Built-in providers

| Provider | Back-end | Platform |
|---|---|---|
| `ConsoleLoggerProvider` | `stdout` (ANSI color) | CLI, server, Flutter (non-web) |
| `DebugLoggerProvider` | `dart:developer log()` | All including web |
| `MemoryLoggerProvider` | `MemoryLogStore` (in-memory) | All — testing only |
| `NullLoggerProvider` | `/dev/null` | All — null object / stubs |

### `LoggingBuilder` extension pattern

Each provider file defines its own `LoggingBuilder` extension:

```
console_logger.dart   → extension LoggingBuilderConsoleExtension on LoggingBuilder
debug_logger.dart     → extension LoggingBuilderDebugExtension on LoggingBuilder
memory_logger.dart    → extension LoggingBuilderMemoryExtension on LoggingBuilder
null_logger.dart      → extension LoggingBuilderNullExtension on LoggingBuilder
```

This keeps provider-specific builder API co-located with the provider
implementation and allows new providers to extend `LoggingBuilder` without
modifying the core.

---

## EventLogger interface

`EventLogger` is an internal interface that extends `Logger`:

```dart
abstract interface class EventLogger implements Logger {
  void write(LogEvent event);
}
```

All built-in provider loggers implement `EventLogger`. When `LoggerImpl`
dispatches a log entry, it checks `logger is EventLogger`:

- **`EventLogger` path** — passes the pre-built `LogEvent` (which already
  contains scope-merged `scopeProperties`) directly to `write()`. This avoids
  creating a second object and ensures scope data is available.
- **Fallback path** — calls the standard `Logger.log(…)` interface. Scope
  properties are **not** forwarded because external loggers cannot receive a
  `LogEvent`. This is a documented limitation of third-party providers that
  don't implement `EventLogger`.

```
LoggerImpl.log()
    │
    ├── logger is EventLogger?
    │       yes → logger.write(preBuiltEvent)   scope properties included
    │       no  → logger.log(level, msg, …)     scope properties NOT forwarded
    └──
```

Third-party providers can opt into scope support by implementing `EventLogger`.

---

## LogEvent immutability

`LogEvent` is declared `final` and all mutable fields are made defensively
immutable at construction time:

```dart
LogEvent({
  …
  Map<String, Object?> properties = const {},
  Map<String, Object?> scopeProperties = const {},
  …
})  : properties = properties.isEmpty
          ? const {}
          : Map.unmodifiable(Map.of(properties)),
      scopeProperties = scopeProperties.isEmpty
          ? const {}
          : Map.unmodifiable(Map.of(scopeProperties));
```

- When the source map is empty, the shared `const {}` constant is reused — no
  allocation.
- When non-empty, a defensive copy is taken immediately (`Map.of`) and then
  wrapped in `Map.unmodifiable`. The source map can be reused or mutated by
  the caller after `log()` returns without affecting stored events.

`MemoryLogStore` stores `LogEvent` references in a `ListQueue<LogEvent>`.
Because the events are immutable, concurrent reads (within the same isolate,
after all writes are complete) are safe without locking.

---

## Extensions

### `LoggerTagExtension`

Adds tag-based logging convenience methods to every `Logger` by storing the
tag under the reserved property key `'tag'`:

```
logger.infoTagged('auth', 'User signed in')
  │
  └─ logTagged(LogLevel.info, 'auth', 'User signed in')
       └─ logger.log(LogLevel.info, 'User signed in',
              properties: {'tag': 'auth'})
```

The tag is stored in `LogEvent.properties['tag']`, making it visible to every
provider and queryable via `MemoryLogStore.eventsForTag`. No changes to the core
`Logger` interface are required.

### `LoggerExceptionExtension`

Reduces exception-logging boilerplate by building the standard `errorType` and
`errorMessage` properties automatically and deriving a message from the error
when none is provided:

```
logger.logException(e, st, properties: {'orderId': 99})
  │
  ├─ message      = _formatError(e)         ← derived when not supplied
  ├─ mergedProps  = { errorType, errorMessage } + caller properties
  └─ logger.log(LogLevel.error, message, error: e, stackTrace: st,
         properties: mergedProps)
```

The `_formatError` helper avoids redundant `"TypeName: TypeName: …"` when
`error.toString()` already begins with the type name.

---

## Quick setup helper

`DavianLogger` is a static `abstract final class` that holds a single process-wide
`LoggerFactory` (`_quickFactory`) backed by `ConsoleLoggerProvider`. It is
rebuilt automatically when the `minimumLevel` argument changes:

```
DavianLogger._quickFactory  (nullable, LoggerFactory?)
DavianLogger._quickFactoryLevel (nullable, LogLevel?)

DavianLogger.quick(category, minimumLevel)
  │
  ├─ _ensureQuickFactory(minimumLevel)
  │       if _quickFactory == null || _quickFactoryLevel != minimumLevel:
  │           _quickFactory?.dispose()
  │           _quickFactory = LoggingBuilder()
  │                               .addConsole()
  │                               .setMinimumLevel(minimumLevel)
  │                               .build()
  │           _quickFactoryLevel = minimumLevel
  │
  └─ return _quickFactory!.createLogger(category)
```

`DavianLogger.disposeQuickFactory()` sets both fields to `null` after
disposing, allowing a clean rebuild on the next call.

---

## Memory store and export

`MemoryLogStore` stores `LogEvent` objects in a `dart:collection.ListQueue<LogEvent>`:

```
MemoryLogStore
    ├── _events: ListQueue<LogEvent>   (insertion-ordered)
    ├── maxCapacity: int?              (null = unbounded)
    │
    ├── add(event)
    │       if maxCapacity != null && _events.length >= maxCapacity:
    │           _events.removeFirst()   ← O(1) from ListQueue
    │       _events.add(event)
    │
    ├── eventsAtOrAbove(minimum)  → filter by level.isAtLeast(minimum)
    ├── eventsForCategory(cat)    → filter by event.category == cat
    ├── eventsForTag(tag)         → filter by event.properties['tag'] == tag
    │
    └── exportAsJson()
            → json.encode(
                _events.map(_eventToJsonMap).toList()
              )
```

`_eventToJsonMap` serialises each event to a plain `Map<String, Object?>` and
omits optional fields (`properties`, `scopeProperties`, `error`, `stackTrace`)
when they are absent or empty. This keeps the JSON output minimal.

`ListQueue` is used instead of `List` to achieve O(1) removal from the front
during bounded-capacity eviction, compared to `List.removeAt(0)` which is O(n).

---

## Timestamp abstraction

`TimestampProvider` decouples the framework from `DateTime.now()`, enabling
deterministic time in tests:

```dart
abstract interface class TimestampProvider {
  DateTime now();
}
```

`UtcTimestampProvider` is the default; it calls `DateTime.timestamp()` which
is equivalent to `DateTime.now().toUtc()` but slightly more efficient. A custom
provider can be injected via `LoggingBuilder.setTimestampProvider(...)`.

---

## Disposal model

Disposal is deterministic and propagates from factory to providers:

```
LoggerFactoryImpl.dispose()
  │
  ├─ _disposed = true
  │
  ├─ for each provider in _providers:
  │       provider.dispose()           ← flush buffers, close sinks
  │
  ├─ _providers.clear()
  │
  ├─ for each entryList in _entryCache.values:
  │       entryList.clear()            ← existing LoggerImpl instances become no-ops
  │                                      (their _entries list is now empty)
  │
  └─ _loggerCache.clear()
     _entryCache.clear()
```

`LoggerImpl` instances obtained before disposal continue to accept calls
silently — `_entries` is empty, so the fast-path scan finds no enabled
providers and returns immediately. This prevents crashes in long-lived objects
that hold a logger reference beyond the factory's lifetime.

`DavianLogger.disposeQuickFactory()` follows the same pattern and sets the
internal fields to `null` so a subsequent call to `quick()` rebuilds the factory.

---

## Design decisions

### Why `abstract interface class` for `Logger` and `LoggerFactory`?

Dart's `abstract interface class` disallows implicit `implements` from outside
the library, providing stronger encapsulation than a plain abstract class.
Consumer code works against the public interface using
`factory.createLogger(...)` without knowing (or needing to know) the concrete
type.

### Why `final class` for `LogEvent`?

`LogEvent` is a data carrier. Making it `final` prevents subclassing and
signals immutability intent clearly. Combined with the unmodifiable map wrapping
in the constructor, providers can safely compare, cache, or serialise events
without defensive copies of their own.

### Why a separate `EventLogger` interface instead of putting `write()` on `Logger`?

`Logger` is a public consumer-facing interface. Adding `write(LogEvent)` to it
would expose internal dispatch details and force every external implementor to
handle `LogEvent` construction. `EventLogger` is an opt-in upgrade: built-in
providers implement it to gain scope support; external providers can ignore it
and still work correctly via the `Logger.log` fallback.

### Why `ListQueue` for `MemoryLogStore`?

`ListQueue` from `dart:collection` provides O(1) `add` (amortised) and O(1)
`removeFirst`, which are the two operations needed for a bounded ring-buffer.
`List.removeAt(0)` would be O(n) for every eviction, degrading performance in
long-running test suites with large stores.

### Why is `FilterRuleSet` not cached per (providerType, category) pair?

Caching would require invalidation logic when `addProvider` is called after
factory creation. Because the number of rules is small in practice and the scan
is O(rules), the simplicity of always scanning outweighs the overhead.
Applications with genuinely hot paths should guard expensive calls with
`logger.isEnabled(level)` and avoid deep rule sets.

### Why is `LoggingScope.effectiveProperties` lazy?

Scope chains are immutable once created, so the merged map is computed on first
access and cached via `late final`. This avoids recomputing the merge on every
`log()` call when multiple log entries are emitted within the same scope.

### Why `DavianLogger` over a top-level global logger?

A top-level mutable `Logger` variable is a global singleton that is difficult
to replace in tests. `DavianLogger` instead holds a `LoggerFactory` that can be
disposed and rebuilt, and all `DavianLogger.quick()` calls go through
`createLogger`, so test code can substitute their own factory if needed without
patching a global.
