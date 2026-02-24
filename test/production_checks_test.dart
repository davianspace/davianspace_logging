/// Production & enterprise quality checks added in the hardening pass.
///
/// Covers:
///   - [StateError] thrown by [LoggerFactory] after disposal (replaces assert)
///   - [LogEvent] value semantics: defensive copy, `==`, `hashCode`, `copyWith`
///   - [SimpleFormatter] log-injection guard (newline escaping)
///   - [NullLogger] and [NullLoggerProvider] no-op behaviour
///   - [MemoryLogStore.maxCapacity] bounded ring-buffer eviction
///   - [LoggingScope.effectiveProperties] memoisation – same identity on repeat access
///   - [LoggerProvider] can be extended (not just implemented) with free dispose()
library;

import 'package:davianspace_logging/davianspace_logging.dart';
import 'package:test/test.dart';

void main() {
  // ── StateError after disposal ──────────────────────────────────────────────
  group('LoggerFactory – StateError after dispose', () {
    test('createLogger throws StateError after dispose', () {
      final factory = LoggingBuilder().addMemory().build();
      factory.dispose();
      expect(
        () => factory.createLogger('X'),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('disposed'),
        )),
      );
    });

    test('addProvider throws StateError after dispose', () {
      final factory = LoggingBuilder().addMemory().build();
      factory.dispose();
      expect(
        () => factory.addProvider(MemoryLoggerProvider()),
        throwsA(isA<StateError>()),
      );
    });

    test('dispose is idempotent – second call does not throw', () {
      final factory = LoggingBuilder().addMemory().build();
      factory.dispose();
      expect(factory.dispose, returnsNormally);
    });
  });

  // ── LogEvent defensive copy ────────────────────────────────────────────────
  group('LogEvent – defensive copy', () {
    test('mutating source properties map after creation has no effect', () {
      final source = <String, Object?>{'key': 'original'};
      final event = LogEvent(
        level: LogLevel.info,
        category: 'Test',
        message: 'msg',
        timestamp: DateTime.utc(2026),
        properties: source,
      );

      source['key'] = 'mutated'; // mutate AFTER construction

      expect(event.properties['key'], equals('original'),
          reason: 'stored map must be a independent copy');
    });

    test('mutating source scopeProperties after creation has no effect', () {
      final source = <String, Object?>{'req': 'abc'};
      final event = LogEvent(
        level: LogLevel.info,
        category: 'Test',
        message: 'msg',
        timestamp: DateTime.utc(2026),
        scopeProperties: source,
      );

      source['req'] = 'xyz';

      expect(event.scopeProperties['req'], equals('abc'));
    });

    test('properties map on the event is unmodifiable', () {
      final event = LogEvent(
        level: LogLevel.info,
        category: 'T',
        message: 'm',
        timestamp: DateTime.utc(2026),
        properties: {'x': 1},
      );

      expect(
        () => (event.properties)['x'] = 2,
        throwsUnsupportedError,
        reason: 'stored map must be unmodifiable',
      );
    });

    test('empty properties map uses canonical const instance (no allocation)',
        () {
      final a = LogEvent(
          level: LogLevel.info,
          category: 'T',
          message: 'm',
          timestamp: DateTime.utc(2026));
      final b = LogEvent(
          level: LogLevel.info,
          category: 'T',
          message: 'm',
          timestamp: DateTime.utc(2026));

      // Both should use the same canonical const empty map.
      expect(identical(a.properties, b.properties), isTrue);
    });
  });

  // ── LogEvent equality ──────────────────────────────────────────────────────
  group('LogEvent – value equality', () {
    final ts = DateTime.utc(2026, 2, 25, 10);

    LogEvent base() => LogEvent(
          level: LogLevel.info,
          category: 'Cat',
          message: 'msg',
          timestamp: ts,
          properties: {'k': 1},
          scopeProperties: {'s': 'v'},
        );

    test('identical events are equal', () {
      expect(base(), equals(base()));
    });

    test('same reference is equal', () {
      final e = base();
      expect(e, equals(e));
    });

    test('different level is not equal', () {
      expect(
        base(),
        isNot(equals(base().copyWith(level: LogLevel.warning))),
      );
    });

    test('different message is not equal', () {
      expect(base(), isNot(equals(base().copyWith(message: 'other'))));
    });

    test('different properties is not equal', () {
      expect(
        base(),
        isNot(equals(base().copyWith(properties: {'k': 2}))),
      );
    });

    test('equal events have equal hashCodes', () {
      expect(base().hashCode, equals(base().hashCode));
    });

    test('can be stored and retrieved from a Set', () {
      final set = {base()};
      expect(set.contains(base()), isTrue);
    });
  });

  // ── LogEvent.copyWith ─────────────────────────────────────────────────────
  group('LogEvent.copyWith', () {
    final ts = DateTime.utc(2026, 3);

    test('returns event with updated level', () {
      final original = LogEvent(
          level: LogLevel.debug, category: 'C', message: 'm', timestamp: ts);
      final copy = original.copyWith(level: LogLevel.error);

      expect(copy.level, equals(LogLevel.error));
      expect(copy.category, equals(original.category));
    });

    test('returns event with updated properties', () {
      final original = LogEvent(
          level: LogLevel.info,
          category: 'C',
          message: 'm',
          timestamp: ts,
          properties: {'a': 1});
      final copy = original.copyWith(properties: {'b': 2});

      expect(copy.properties.containsKey('a'), isFalse);
      expect(copy.properties['b'], equals(2));
    });

    test('unchanged fields are preserved', () {
      final err = Exception('boom');
      final original = LogEvent(
          level: LogLevel.error,
          category: 'C',
          message: 'm',
          timestamp: ts,
          error: err);
      final copy = original.copyWith(message: 'updated');

      expect(copy.error, same(err));
      expect(copy.message, equals('updated'));
    });
  });

  // ── SimpleFormatter – log injection ──────────────────────────────────────
  group('SimpleFormatter – log injection guard', () {
    const fmt = SimpleFormatter(includeTimestamp: false);

    test('newline in property value is escaped to literal \\\\n', () {
      final event = LogEvent(
        level: LogLevel.info,
        category: 'T',
        message: 'msg',
        timestamp: DateTime.utc(2026),
        properties: {'payload': 'line1\nline2'},
      );

      final output = fmt.format(event);

      // The physical newline must not appear; instead the escaped sequence should.
      expect(output, isNot(contains('\n')));
      expect(output, contains(r'\n')); // escaped form is present
    });

    test('carriage return in property value is escaped', () {
      final event = LogEvent(
        level: LogLevel.info,
        category: 'T',
        message: 'msg',
        timestamp: DateTime.utc(2026),
        properties: {'v': 'before\rafter'},
      );

      final output = fmt.format(event);
      expect(output, isNot(contains('\r')));
      expect(output, contains(r'\r'));
    });

    test('CRLF pair is escaped atomically', () {
      final event = LogEvent(
        level: LogLevel.info,
        category: 'T',
        message: 'msg',
        timestamp: DateTime.utc(2026),
        properties: {'v': 'a\r\nb'},
      );

      final output = fmt.format(event);
      expect(output, isNot(contains('\r\n')));
      // Should appear as the literal text \r\n, not doubled.
      expect(output.contains(r'\r\n'), isTrue);
    });

    test('clean property value is unchanged', () {
      final event = LogEvent(
        level: LogLevel.info,
        category: 'T',
        message: 'msg',
        timestamp: DateTime.utc(2026),
        properties: {'key': 'safe value 123'},
      );

      final output = fmt.format(event);
      expect(output, contains('safe value 123'));
    });
  });

  // ── NullLogger ─────────────────────────────────────────────────────────────
  group('NullLogger', () {
    test('isEnabled always returns false', () {
      const logger = NullLogger('Test');
      for (final level in LogLevel.values) {
        expect(logger.isEnabled(level), isFalse,
            reason: '${level.name} should be disabled');
      }
    });

    test('log() is a pure no-op (no allocation check via isEnabled guard)', () {
      const logger = NullLogger();
      expect(() => logger.log(LogLevel.critical, 'boom'), returnsNormally);
    });

    test('beginScope returns a valid LoggingScope', () {
      const logger = NullLogger();
      final scope = logger.beginScope({'x': 1});
      expect(scope, isA<LoggingScope>());
    });

    test('category is empty string by default', () {
      expect(const NullLogger().category, equals(''));
    });

    test('category is returned when provided', () {
      expect(const NullLogger('MyService').category, equals('MyService'));
    });
  });

  group('NullLoggerProvider', () {
    test('createLogger returns NullLogger with correct category', () {
      const provider = NullLoggerProvider();
      final logger = provider.createLogger('SomeCategory');
      expect(logger.category, equals('SomeCategory'));
      expect(logger.isEnabled(LogLevel.info), isFalse);
    });

    test('addNull() builds factory that produces no events via MemoryStore',
        () {
      final store = MemoryLogStore();
      // addNull first, then addMemory with info+ filter so we see if anything leaks.
      final factory = LoggingBuilder()
          .addNull()
          .addMemory(store: store)
          .setMinimumLevel(LogLevel.info)
          .build();

      final logger = factory.createLogger('Null');
      logger.info('should reach memory but not null provider');

      // The memory store should still get the event; null provider discards it.
      expect(store.length, equals(1));
      factory.dispose();
    });
  });

  // ── MemoryLogStore maxCapacity ─────────────────────────────────────────────
  group('MemoryLogStore – bounded capacity', () {
    test('does not evict when under capacity', () {
      final store = MemoryLogStore(maxCapacity: 5);
      final factory = LoggingBuilder()
          .addMemory(store: store)
          .setMinimumLevel(LogLevel.trace)
          .build();
      final logger = factory.createLogger('Cap');

      for (var i = 0; i < 5; i++) {
        logger.info('msg $i');
      }

      expect(store.length, equals(5));
      factory.dispose();
    });

    test('evicts oldest event when at capacity', () {
      final store = MemoryLogStore(maxCapacity: 3);
      final factory = LoggingBuilder()
          .addMemory(store: store)
          .setMinimumLevel(LogLevel.trace)
          .build();
      final logger = factory.createLogger('Cap');

      for (var i = 0; i < 5; i++) {
        logger.info('msg $i');
      }

      // Only last 3 events should remain.
      expect(store.length, equals(3));
      expect(store.events.first.message, equals('msg 2'));
      expect(store.events.last.message, equals('msg 4'));
      factory.dispose();
    });

    test('unlimited store (null maxCapacity) keeps all events', () {
      final store = MemoryLogStore(); // no maxCapacity
      final factory = LoggingBuilder().addMemory(store: store).build();
      final logger = factory.createLogger('Unlimited');

      for (var i = 0; i < 200; i++) {
        logger.info('x');
      }

      expect(store.length, equals(200));
      factory.dispose();
    });
  });

  // ── LoggingScope memoised effectiveProperties ─────────────────────────────
  group('LoggingScope – effectiveProperties memoisation', () {
    test('same map object is returned on repeated access', () {
      final scope = LoggingScope.create({'a': 1, 'b': 2});
      final first = scope.effectiveProperties;
      final second = scope.effectiveProperties;
      expect(identical(first, second), isTrue,
          reason: 'should return the same cached instance');
    });

    test('nested scope memoised map merges correctly', () {
      final outer = LoggingScope.create({'x': 1});
      outer.run(() {
        final inner = LoggingScope.create({'y': 2});
        final props = inner.effectiveProperties;
        expect(props['x'], equals(1));
        expect(props['y'], equals(2));

        // Second access returns cached map.
        expect(identical(inner.effectiveProperties, props), isTrue);
      });
    });
  });

  // ── LoggerProvider extends (free dispose) ─────────────────────────────────
  group('LoggerProvider extension', () {
    test('custom provider that extends LoggerProvider gets free no-op dispose',
        () {
      final provider = _MinimalProvider();
      // dispose() is inherited; should not throw.
      expect(provider.dispose, returnsNormally);
    });

    test('custom provider can be registered with LoggingBuilder', () {
      final store = MemoryLogStore();
      final factory = LoggingBuilder()
          .addProvider(_ForwardingProvider(store))
          .setMinimumLevel(LogLevel.info)
          .build();

      factory.createLogger('Custom').info('hello from custom');
      expect(store.length, equals(1));
      factory.dispose();
    });
  });
}

// ── Helpers ───────────────────────────────────────────────────────────────

/// Minimal provider that only overrides [createLogger]; no [dispose] override.
final class _MinimalProvider extends LoggerProvider {
  @override
  Logger createLogger(String category) => NullLogger(category);
}

/// Provider that forwards events to a [MemoryLogStore] via [EventLogger].
final class _ForwardingProvider extends LoggerProvider {
  _ForwardingProvider(this._store);
  final MemoryLogStore _store;

  @override
  Logger createLogger(String category) => _ForwardingLogger(category, _store);
}

final class _ForwardingLogger implements EventLogger {
  _ForwardingLogger(this._category, this._store);
  final String _category;
  final MemoryLogStore _store;

  @override
  String get category => _category;

  @override
  bool isEnabled(LogLevel level) => level != LogLevel.none;

  @override
  void write(LogEvent event) => _store.add(event);

  @override
  void log(LogLevel level, String message,
      {Object? error,
      StackTrace? stackTrace,
      Map<String, Object?>? properties}) {
    if (!isEnabled(level)) return;
    write(LogEvent(
        level: level,
        category: _category,
        message: message,
        timestamp: DateTime.timestamp(),
        properties: properties ?? const {},
        error: error,
        stackTrace: stackTrace));
  }

  @override
  LoggingScope beginScope(Map<String, Object?> properties) =>
      LoggingScope.create(properties);
}
