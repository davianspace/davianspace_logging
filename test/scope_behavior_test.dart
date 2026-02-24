import 'package:davianspace_logging/davianspace_logging.dart';
import 'package:test/test.dart';

void main() {
  group('LoggingScope – synchronous', () {
    late MemoryLogStore store;
    late LoggerFactory factory;
    late Logger logger;

    setUp(() {
      store = MemoryLogStore();
      factory = LoggingBuilder()
          .addMemory(store: store)
          .setMinimumLevel(LogLevel.trace)
          .build();
      logger = factory.createLogger('ScopeTest');
    });

    tearDown(() => factory.dispose());

    test('scope properties are injected into log events', () {
      final scope = logger.beginScope({'requestId': 'req-1'});
      scope.run(() => logger.info('inside scope'));

      expect(store.length, equals(1));
      expect(store.events.first.scopeProperties['requestId'], equals('req-1'));
    });

    test('log outside scope has empty scopeProperties', () {
      logger.info('outside any scope');
      expect(store.events.first.scopeProperties, isEmpty);
    });

    test('nested scopes merge properties, child overrides parent', () {
      final outer = logger.beginScope({'a': 1, 'b': 'outer'});
      outer.run(() {
        final inner = logger.beginScope({'b': 'inner', 'c': 3});
        inner.run(() {
          logger.info('in nested scope');
        });
      });

      final props = store.events.first.scopeProperties;
      expect(props['a'], equals(1));
      expect(props['b'], equals('inner')); // child overrides parent
      expect(props['c'], equals(3));
    });

    test('properties after scope.run have no scope', () {
      final scope = logger.beginScope({'x': 42});
      scope.run(() => logger.info('in scope'));
      logger.info('after scope');

      expect(store.events[0].scopeProperties['x'], equals(42));
      expect(store.events[1].scopeProperties, isEmpty);
    });

    test('scope does not affect sibling runs', () {
      final scopeA = logger.beginScope({'s': 'A'});
      final scopeB = logger.beginScope({'s': 'B'});

      scopeA.run(() => logger.info('from A'));
      scopeB.run(() => logger.info('from B'));

      expect(store.events[0].scopeProperties['s'], equals('A'));
      expect(store.events[1].scopeProperties['s'], equals('B'));
    });
  });

  group('LoggingScope – async propagation', () {
    late MemoryLogStore store;
    late LoggerFactory factory;
    late Logger logger;

    setUp(() {
      store = MemoryLogStore();
      factory = LoggingBuilder()
          .addMemory(store: store)
          .setMinimumLevel(LogLevel.trace)
          .build();
      logger = factory.createLogger('AsyncScopeTest');
    });

    tearDown(() => factory.dispose());

    test('scope properties propagate across await boundaries', () async {
      final scope = logger.beginScope({'correlationId': 'corr-42'});
      await scope.runAsync(() async {
        logger.info('before await');
        await Future<void>.delayed(Duration.zero);
        logger.info('after await');
      });

      expect(store.length, equals(2));
      for (final event in store.events) {
        expect(event.scopeProperties['correlationId'], equals('corr-42'));
      }
    });

    test('async operations outside scope do not inherit scope properties',
        () async {
      final scope = logger.beginScope({'tag': 'scoped'});
      final List<String> results = [];

      // Start an async task OUTSIDE the scope first.
      final outsideTask = Future<void>.microtask(() async {
        await Future<void>.delayed(Duration.zero);
        logger.info('unscoped async');
        results.add('out');
      });

      await scope.runAsync(() async {
        logger.info('scoped async');
        results.add('in');
      });
      await outsideTask;

      final inEvent =
          store.events.firstWhere((e) => e.message == 'scoped async');
      final outEvent =
          store.events.firstWhere((e) => e.message == 'unscoped async');

      expect(inEvent.scopeProperties['tag'], equals('scoped'));
      expect(outEvent.scopeProperties, isEmpty);
    });

    test('deeper nested async scopes stack correctly', () async {
      final s1 = logger.beginScope({'depth': 1, 'a': 'root'});
      await s1.runAsync(() async {
        final s2 = logger.beginScope({'depth': 2, 'b': 'mid'});
        await s2.runAsync(() async {
          final s3 = logger.beginScope({'depth': 3});
          await s3.runAsync(() async => logger.info('deep'));
        });
      });

      final props = store.events.first.scopeProperties;
      expect(props['depth'], equals(3));
      expect(props['a'], equals('root'));
      expect(props['b'], equals('mid'));
    });
  });

  group('LoggingScope.current', () {
    test('current is null outside any scope', () {
      expect(LoggingScope.current, isNull);
    });

    test('current reflects innermost scope during run', () {
      final outer = LoggingScope.create({'level': 'outer'});
      outer.run(() {
        expect(LoggingScope.current!.properties['level'], equals('outer'));

        final inner = LoggingScope.create({'level': 'inner'});
        inner.run(() {
          expect(LoggingScope.current!.properties['level'], equals('inner'));
        });

        // Back to outer after inner.run completes.
        expect(LoggingScope.current!.properties['level'], equals('outer'));
      });

      expect(LoggingScope.current, isNull);
    });
  });
}
