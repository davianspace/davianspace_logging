import 'package:davianspace_logging/davianspace_logging.dart';
import 'package:test/test.dart';

void main() {
  group('LogLevel ordering', () {
    test('isAtLeast returns true for equal levels', () {
      for (final level in LogLevel.values) {
        expect(level.isAtLeast(level), isTrue, reason: '$level.name');
      }
    });

    test('isAtLeast returns true for lower minimum', () {
      expect(LogLevel.warning.isAtLeast(LogLevel.debug), isTrue);
      expect(LogLevel.critical.isAtLeast(LogLevel.trace), isTrue);
      expect(LogLevel.none.isAtLeast(LogLevel.critical), isTrue);
    });

    test('isAtLeast returns false for higher minimum', () {
      expect(LogLevel.debug.isAtLeast(LogLevel.info), isFalse);
      expect(LogLevel.info.isAtLeast(LogLevel.warning), isFalse);
      expect(LogLevel.trace.isAtLeast(LogLevel.error), isFalse);
    });

    test('none is always suppressed by isEnabled check', () {
      final store = MemoryLogStore();
      final factory = LoggingBuilder()
          .addMemory(store: store)
          .setMinimumLevel(LogLevel.trace)
          .build();
      final logger = factory.createLogger('Test');

      logger.log(LogLevel.none, 'should not appear');
      expect(store.isEmpty, isTrue);
      factory.dispose();
    });
  });

  group('Global minimum level filtering', () {
    test('entries below minimum level are dropped', () {
      final store = MemoryLogStore();
      final factory = LoggingBuilder()
          .addMemory(store: store)
          .setMinimumLevel(LogLevel.warning)
          .build();
      final logger = factory.createLogger('FilterTest');

      logger.trace('trace message');
      logger.debug('debug message');
      logger.info('info message');
      logger.warning('warning message');
      logger.error('error message');
      logger.critical('critical message');

      expect(store.length, equals(3));
      expect(store.events.map((e) => e.level).toList(), [
        LogLevel.warning,
        LogLevel.error,
        LogLevel.critical,
      ]);
      factory.dispose();
    });

    test('setMinimumLevel(trace) passes all levels', () {
      final store = MemoryLogStore();
      final factory = LoggingBuilder()
          .addMemory(store: store)
          .setMinimumLevel(LogLevel.trace)
          .build();
      final logger = factory.createLogger('All');

      logger.trace('t');
      logger.debug('d');
      logger.info('i');
      logger.warning('w');
      logger.error('e');
      logger.critical('c');

      expect(store.length, equals(6));
      factory.dispose();
    });

    test('setMinimumLevel(none) drops all entries', () {
      final store = MemoryLogStore();
      final factory = LoggingBuilder()
          .addMemory(store: store)
          .setMinimumLevel(LogLevel.none)
          .build();
      final logger = factory.createLogger('Silence');

      logger.trace('t');
      logger.debug('d');
      logger.info('i');
      logger.warning('w');
      logger.error('e');
      logger.critical('c');

      expect(store.isEmpty, isTrue);
      factory.dispose();
    });
  });

  group('FilterRule – category prefix filtering', () {
    test('category prefix rule overrides global minimum', () {
      final store = MemoryLogStore();
      final factory = LoggingBuilder()
          .addMemory(store: store)
          .setMinimumLevel(LogLevel.debug)
          .addFilterRule(
            const FilterRule(
              categoryPrefix: 'network',
              minimumLevel: LogLevel.error,
            ),
          )
          .build();

      factory.createLogger('network.http').info('should be dropped');
      factory.createLogger('network.http').error('should be kept');
      factory.createLogger('auth').debug('auth debug – kept');

      expect(store.length, equals(2));
      expect(store.events[0].level, equals(LogLevel.error));
      expect(store.events[1].category, equals('auth'));
      factory.dispose();
    });

    test('provider-specific rule takes precedence over category rule', () {
      final storeA = MemoryLogStore();
      final storeB = MemoryLogStore();

      final factory = LoggingBuilder()
          .addProvider(MemoryLoggerProvider(store: storeA))
          .addProvider(MemoryLoggerProvider(store: storeB))
          .setMinimumLevel(LogLevel.trace)
          .addFilterRule(const FilterRule(
            providerType: MemoryLoggerProvider,
            categoryPrefix: 'noisy',
            minimumLevel: LogLevel.error,
          ))
          .build();

      factory.createLogger('noisy.module').info('suppressed by provider rule');
      factory.createLogger('noisy.module').error('passes provider rule');

      // Both stores receive from same provider type so both are filtered.
      expect(storeA.length, equals(1));
      expect(storeB.length, equals(1));
      factory.dispose();
    });
  });

  group('isEnabled', () {
    test('returns false when all providers filter the level', () {
      final factory =
          LoggingBuilder().addMemory().setMinimumLevel(LogLevel.error).build();
      final logger = factory.createLogger('IsEnabledTest');

      expect(logger.isEnabled(LogLevel.debug), isFalse);
      expect(logger.isEnabled(LogLevel.info), isFalse);
      expect(logger.isEnabled(LogLevel.error), isTrue);
      expect(logger.isEnabled(LogLevel.critical), isTrue);
      factory.dispose();
    });

    test('returns false for LogLevel.none regardless of config', () {
      final factory =
          LoggingBuilder().addMemory().setMinimumLevel(LogLevel.trace).build();
      expect(factory.createLogger('x').isEnabled(LogLevel.none), isFalse);
      factory.dispose();
    });
  });
}
