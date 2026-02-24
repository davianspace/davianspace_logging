import 'dart:async';

import 'package:davianspace_logging/davianspace_logging.dart';
import 'package:test/test.dart';

void main() {
  group('Concurrent logging', () {
    test('many concurrent async loggers produce expected event count',
        () async {
      final store = MemoryLogStore();
      final factory = LoggingBuilder()
          .addMemory(store: store)
          .setMinimumLevel(LogLevel.trace)
          .build();
      final logger = factory.createLogger('Concurrent');

      const tasks = 100;
      const logsPerTask = 50;

      // Fire tasks without awaiting; allow them to interleave.
      final futures = List.generate(
        tasks,
        (_) => Future<void>(() async {
          for (var i = 0; i < logsPerTask; i++) {
            logger.info('message $i');
            // Yield to allow other microtasks to run.
            await Future<void>.delayed(Duration.zero);
          }
        }),
      );

      await Future.wait(futures);

      expect(store.length, equals(tasks * logsPerTask));
      factory.dispose();
    });

    test('concurrent scoped loggers do not leak properties across isolates',
        () async {
      final store = MemoryLogStore();
      final factory = LoggingBuilder()
          .addMemory(store: store)
          .setMinimumLevel(LogLevel.trace)
          .build();
      final logger = factory.createLogger('ScopedConcurrent');

      // Launch two concurrent async tasks, each with its own scope.
      await Future.wait([
        Future<void>(() async {
          final scope = logger.beginScope({'worker': 'A'});
          await scope.runAsync(() async {
            await Future<void>.delayed(Duration.zero);
            logger.info('worker A step 1');
            await Future<void>.delayed(Duration.zero);
            logger.info('worker A step 2');
          });
        }),
        Future<void>(() async {
          final scope = logger.beginScope({'worker': 'B'});
          await scope.runAsync(() async {
            logger.info('worker B step 1');
            await Future<void>.delayed(Duration.zero);
            logger.info('worker B step 2');
          });
        }),
      ]);

      // Each event must carry exactly its own worker tag.
      for (final event in store.events) {
        final worker = event.scopeProperties['worker'];
        expect(worker, isNotNull,
            reason: '${event.message} missing worker property');
        expect(event.message, contains('worker $worker'));
      }
      factory.dispose();
    });

    test('high-frequency logging does not lose events', () async {
      final store = MemoryLogStore();
      final factory = LoggingBuilder().addMemory(store: store).build();
      final logger = factory.createLogger('HF');

      const count = 10000;
      for (var i = 0; i < count; i++) {
        logger.info('msg $i');
      }

      expect(store.length, equals(count));
      factory.dispose();
    });

    test('concurrent addProvider does not corrupt existing event delivery',
        () async {
      final storeA = MemoryLogStore();
      final storeB = MemoryLogStore();
      final factory = LoggingBuilder().addMemory(store: storeA).build();
      final logger = factory.createLogger('Dynamic');

      // Log before adding second provider.
      for (var i = 0; i < 10; i++) {
        logger.info('pre-$i');
      }

      factory.addProvider(MemoryLoggerProvider(store: storeB));

      // Log after adding second provider.
      for (var i = 0; i < 10; i++) {
        logger.info('post-$i');
      }

      expect(storeA.length, equals(20)); // all 20 events
      expect(storeB.length, equals(10)); // only post-add events
      factory.dispose();
    });
  });
}
