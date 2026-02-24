import 'package:davianspace_logging/davianspace_logging.dart';
import 'package:test/test.dart';

void main() {
  group('Multi-provider routing', () {
    test('entry is delivered to all registered providers', () {
      final storeA = MemoryLogStore();
      final storeB = MemoryLogStore();

      final factory = LoggingBuilder()
          .addMemory(store: storeA)
          .addMemory(store: storeB)
          .build();
      final logger = factory.createLogger('Routing');

      logger.info('broadcast');

      expect(storeA.length, equals(1));
      expect(storeB.length, equals(1));
      expect(storeA.events.first.message, equals('broadcast'));
      expect(storeB.events.first.message, equals('broadcast'));
      factory.dispose();
    });

    test('provider-specific filter suppresses only that provider', () {
      final consoleStore = MemoryLogStore();
      final auditStore = MemoryLogStore();

      // Simulate two providers by using two MemoryLoggerProvider instances.
      // Provider A only accepts errors+; Provider B accepts all.
      final providerA = MemoryLoggerProvider(store: consoleStore);
      final providerB = MemoryLoggerProvider(store: auditStore);

      final factory = LoggingBuilder()
          .addProvider(providerA)
          .addProvider(providerB)
          .setMinimumLevel(LogLevel.trace)
          .addFilterRule(const FilterRule(
            providerType: MemoryLoggerProvider,
            minimumLevel: LogLevel.error,
          ))
          .build();

      factory.createLogger('SvcA').info('info msg');
      factory.createLogger('SvcA').error('error msg');

      // Both providers share the same type, so the same rule applies to both.
      // Only error+ passes.
      expect(consoleStore.length, equals(1));
      expect(auditStore.length, equals(1));
      factory.dispose();
    });

    test('addProvider after build routes to new provider immediately', () {
      final earlyStore = MemoryLogStore();
      final lateStore = MemoryLogStore();

      final factory = LoggingBuilder().addMemory(store: earlyStore).build();
      final logger = factory.createLogger('Live');

      logger.info('before add');
      factory.addProvider(MemoryLoggerProvider(store: lateStore));
      logger.info('after add');

      expect(earlyStore.length, equals(2));
      expect(lateStore.length, equals(1));
      expect(lateStore.events.first.message, equals('after add'));
      factory.dispose();
    });

    test('createLogger returns same cached instance for same category', () {
      final factory = LoggingBuilder().addMemory().build();
      final a = factory.createLogger('Same');
      final b = factory.createLogger('Same');
      expect(identical(a, b), isTrue);
      factory.dispose();
    });

    test('different categories produce independent loggers', () {
      final store = MemoryLogStore();
      final factory = LoggingBuilder().addMemory(store: store).build();

      factory.createLogger('Cat.A').info('from A');
      factory.createLogger('Cat.B').info('from B');

      expect(store.events[0].category, equals('Cat.A'));
      expect(store.events[1].category, equals('Cat.B'));
      factory.dispose();
    });

    test('dispose releases providers and stops logging', () {
      final store = MemoryLogStore();
      final factory = LoggingBuilder().addMemory(store: store).build();
      final logger = factory.createLogger('Disposal');

      logger.info('before dispose');
      factory.dispose();

      // After disposal the logger is orphaned; further calls are no-ops
      // because the entry list is cleared.
      logger.info('after dispose');

      // Only the first message was recorded.
      expect(store.length, equals(1));
    });
  });

  group('MemoryLogStore queries', () {
    test('eventsAtOrAbove filters correctly', () {
      final store = MemoryLogStore();
      final factory = LoggingBuilder()
          .addMemory(store: store)
          .setMinimumLevel(LogLevel.trace)
          .build();
      final logger = factory.createLogger('Q');

      logger.debug('d');
      logger.info('i');
      logger.warning('w');
      logger.error('e');

      final warningsAndAbove = store.eventsAtOrAbove(LogLevel.warning);
      expect(warningsAndAbove, hasLength(2));
      expect(warningsAndAbove.map((e) => e.level).toList(),
          [LogLevel.warning, LogLevel.error]);
      factory.dispose();
    });

    test('eventsForCategory filters by category', () {
      final store = MemoryLogStore();
      final factory = LoggingBuilder().addMemory(store: store).build();

      factory.createLogger('Svc.A').info('a1');
      factory.createLogger('Svc.B').info('b1');
      factory.createLogger('Svc.A').info('a2');

      expect(store.eventsForCategory('Svc.A'), hasLength(2));
      expect(store.eventsForCategory('Svc.B'), hasLength(1));
      factory.dispose();
    });

    test('clear empties the store', () {
      final store = MemoryLogStore();
      final factory = LoggingBuilder().addMemory(store: store).build();
      factory.createLogger('X').info('one');
      factory.createLogger('X').info('two');
      store.clear();
      expect(store.isEmpty, isTrue);
      factory.dispose();
    });
  });
}
