import 'package:davianspace_logging/davianspace_logging.dart';
import 'package:test/test.dart';

void main() {
  group('LoggerTagExtension – logTagged', () {
    late MemoryLogStore store;
    late LoggerFactory factory;
    late Logger logger;

    setUp(() {
      store = MemoryLogStore();
      factory = LoggingBuilder()
          .addMemory(store: store)
          .setMinimumLevel(LogLevel.trace)
          .build();
      logger = factory.createLogger('TagTest');
    });

    tearDown(() => factory.dispose());

    test('logTagged stores tag under reserved key in properties', () {
      logger.logTagged(LogLevel.info, 'auth', 'User signed in');

      expect(store.length, equals(1));
      final event = store.events.first;
      expect(event.message, equals('User signed in'));
      expect(event.properties[LoggerTagExtension.tagKey], equals('auth'));
    });

    test('logTagged merges extra properties alongside tag', () {
      logger.logTagged(
        LogLevel.info,
        'payment',
        'Charge processed',
        properties: {'amount': 99.99, 'currency': 'USD'},
      );

      final event = store.events.first;
      expect(event.properties[LoggerTagExtension.tagKey], equals('payment'));
      expect(event.properties['amount'], equals(99.99));
      expect(event.properties['currency'], equals('USD'));
    });

    test('tag overwrites any existing "tag" key in caller properties', () {
      logger.logTagged(
        LogLevel.debug,
        'newTag',
        'msg',
        properties: {'tag': 'oldTag', 'x': 1},
      );

      expect(store.events.first.properties['tag'], equals('newTag'));
    });

    test('traceTagged emits at LogLevel.trace', () {
      logger.traceTagged('lifecycle', 'trace event');
      expect(store.events.first.level, equals(LogLevel.trace));
      expect(store.events.first.properties['tag'], equals('lifecycle'));
    });

    test('debugTagged emits at LogLevel.debug', () {
      logger.debugTagged('db', 'query executed');
      expect(store.events.first.level, equals(LogLevel.debug));
      expect(store.events.first.properties['tag'], equals('db'));
    });

    test('infoTagged emits at LogLevel.info', () {
      logger.infoTagged('app', 'started');
      expect(store.events.first.level, equals(LogLevel.info));
    });

    test('warningTagged emits at LogLevel.warning', () {
      logger.warningTagged('config', 'missing key');
      expect(store.events.first.level, equals(LogLevel.warning));
    });

    test('errorTagged forwards error and stackTrace', () {
      final err = Exception('oops');
      final st = StackTrace.current;
      logger.errorTagged('network', 'request failed',
          error: err, stackTrace: st);

      final event = store.events.first;
      expect(event.level, equals(LogLevel.error));
      expect(event.error, same(err));
      expect(event.stackTrace, same(st));
      expect(event.properties['tag'], equals('network'));
    });

    test('criticalTagged emits at LogLevel.critical', () {
      logger.criticalTagged('system', 'disk full');
      expect(store.events.first.level, equals(LogLevel.critical));
    });
  });

  group('MemoryLogStore – eventsForTag', () {
    late MemoryLogStore store;
    late LoggerFactory factory;
    late Logger logger;

    setUp(() {
      store = MemoryLogStore();
      factory = LoggingBuilder()
          .addMemory(store: store)
          .setMinimumLevel(LogLevel.trace)
          .build();
      logger = factory.createLogger('TagFilter');
    });

    tearDown(() => factory.dispose());

    test('eventsForTag returns only events with the given tag', () {
      logger.infoTagged('auth', 'login');
      logger.infoTagged('auth', 'logout');
      logger.infoTagged('payment', 'charged');
      logger.info('untagged message');

      final authEvents = store.eventsForTag('auth');
      expect(authEvents, hasLength(2));
      expect(authEvents.every((e) => e.properties['tag'] == 'auth'), isTrue);
    });

    test('eventsForTag returns empty list when no events match', () {
      logger.infoTagged('auth', 'login');
      expect(store.eventsForTag('nonexistent'), isEmpty);
    });

    test('eventsForTag does not return events with no tag', () {
      logger.info('no tag here');
      logger.infoTagged('payment', 'charged');

      expect(store.eventsForTag('payment'), hasLength(1));
    });

    test('eventsForTag is case-sensitive', () {
      logger.infoTagged('Auth', 'login');
      expect(store.eventsForTag('auth'), isEmpty);
      expect(store.eventsForTag('Auth'), hasLength(1));
    });
  });
}
