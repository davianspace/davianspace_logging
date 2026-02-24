import 'package:davianspace_logging/davianspace_logging.dart';
import 'package:test/test.dart';

void main() {
  group('Structured properties', () {
    late MemoryLogStore store;
    late LoggerFactory factory;
    late Logger logger;

    setUp(() {
      store = MemoryLogStore();
      factory = LoggingBuilder()
          .addMemory(store: store)
          .setMinimumLevel(LogLevel.trace)
          .build();
      logger = factory.createLogger('PropertiesTest');
    });

    tearDown(() => factory.dispose());

    test('properties are stored on LogEvent without interpolation', () {
      logger.info(
        'User logged in',
        properties: {'userId': 42, 'role': 'admin'},
      );

      expect(store.length, equals(1));
      final event = store.events.first;
      expect(event.message, equals('User logged in'));
      expect(event.properties['userId'], equals(42));
      expect(event.properties['role'], equals('admin'));
    });

    test('null property values are preserved', () {
      logger.debug('nullable', properties: {'tag': null, 'count': 0});
      final event = store.events.first;
      expect(event.properties['tag'], isNull);
      expect(event.properties['count'], equals(0));
    });

    test('empty properties map is stored when not supplied', () {
      logger.info('no properties');
      expect(store.events.first.properties, isEmpty);
    });

    test('nested map values are preserved', () {
      logger.info('order', properties: {
        'order': {'id': 99, 'status': 'pending'}
      });
      final props = store.events.first.properties;
      expect(props['order'], isA<Map<String, Object?>>());
    });

    test('convenience methods forward properties correctly', () {
      logger.trace('t', properties: {'p': 1});
      logger.debug('d', properties: {'p': 2});
      logger.warning('w', properties: {'p': 3});
      logger.error('e', properties: {'p': 4});
      logger.critical('c', properties: {'p': 5});

      expect(store.length, equals(5));
      for (var i = 0; i < store.events.length; i++) {
        expect(store.events[i].properties['p'], equals(i + 1));
      }
    });

    test('error and stackTrace are stored on LogEvent', () {
      final err = Exception('boom');
      final st = StackTrace.current;
      logger.error('crash', error: err, stackTrace: st);

      final event = store.events.first;
      expect(event.error, same(err));
      expect(event.stackTrace, same(st));
    });

    test('category is set correctly on LogEvent', () {
      logger.info('msg');
      expect(store.events.first.category, equals('PropertiesTest'));
    });

    test('timestamp is set from TimestampProvider', () {
      final fixed = DateTime.utc(2026, 2, 25, 12);
      final fixedFactory = LoggingBuilder()
          .addMemory(store: store)
          .useTimestampProvider(_FixedTimestamp(fixed))
          .build();

      fixedFactory.createLogger('ts').info('timed');
      expect(store.events.last.timestamp, equals(fixed));
      fixedFactory.dispose();
    });
  });
}

final class _FixedTimestamp implements TimestampProvider {
  const _FixedTimestamp(this._value);
  final DateTime _value;

  @override
  DateTime now() => _value;
}
