import 'dart:convert' show json;

import 'package:davianspace_logging/davianspace_logging.dart';
import 'package:test/test.dart';

void main() {
  group('MemoryLogStore – exportAsJson()', () {
    late MemoryLogStore store;
    late LoggerFactory factory;
    late Logger logger;

    setUp(() {
      store = MemoryLogStore();
      factory = LoggingBuilder()
          .addMemory(store: store)
          .setMinimumLevel(LogLevel.trace)
          .build();
      logger = factory.createLogger('ExportTest');
    });

    tearDown(() => factory.dispose());

    test('exportAsJson returns "[]" for an empty store', () {
      expect(store.exportAsJson(), equals('[]'));
    });

    test('exportAsJson returns a valid JSON array', () {
      logger.info('hello');
      final result = store.exportAsJson();
      expect(() => json.decode(result), returnsNormally);
      final decoded = json.decode(result) as List<dynamic>;
      expect(decoded, hasLength(1));
    });

    test('exported entry contains required fields', () {
      logger.info('test message');
      final decoded = (json.decode(store.exportAsJson()) as List<dynamic>).first
          as Map<String, dynamic>;

      expect(decoded.containsKey('timestamp'), isTrue);
      expect(decoded['level'], equals('info'));
      expect(decoded['category'], equals('ExportTest'));
      expect(decoded['message'], equals('test message'));
    });

    test('exported entry omits properties when empty', () {
      logger.info('no props');
      final decoded = (json.decode(store.exportAsJson()) as List<dynamic>).first
          as Map<String, dynamic>;
      expect(decoded.containsKey('properties'), isFalse);
    });

    test('exported entry includes properties when present', () {
      logger.info('with props', properties: {'userId': 42, 'role': 'admin'});
      final decoded = (json.decode(store.exportAsJson()) as List<dynamic>).first
          as Map<String, dynamic>;
      final props = decoded['properties'] as Map<String, dynamic>;
      expect(props['userId'], equals(42));
      expect(props['role'], equals('admin'));
    });

    test('exported entry includes error string when present', () {
      logger.error('failure', error: Exception('crash'));
      final decoded = (json.decode(store.exportAsJson()) as List<dynamic>).first
          as Map<String, dynamic>;
      expect(decoded.containsKey('error'), isTrue);
      expect((decoded['error'] as String), contains('crash'));
    });

    test('exported entry includes stackTrace when present', () {
      final st = StackTrace.current;
      logger.error('oops', error: Exception('x'), stackTrace: st);
      final decoded = (json.decode(store.exportAsJson()) as List<dynamic>).first
          as Map<String, dynamic>;
      expect(decoded.containsKey('stackTrace'), isTrue);
    });

    test('exported entry omits error and stackTrace when absent', () {
      logger.info('clean entry');
      final decoded = (json.decode(store.exportAsJson()) as List<dynamic>).first
          as Map<String, dynamic>;
      expect(decoded.containsKey('error'), isFalse);
      expect(decoded.containsKey('stackTrace'), isFalse);
    });

    test('exportAsJson serialises multiple events in order', () {
      logger.info('first');
      logger.warning('second');
      logger.error('third');

      final decoded = json.decode(store.exportAsJson()) as List<dynamic>;
      expect(decoded, hasLength(3));
      expect((decoded[0] as Map<String, dynamic>)['message'], equals('first'));
      expect((decoded[1] as Map<String, dynamic>)['message'], equals('second'));
      expect((decoded[2] as Map<String, dynamic>)['message'], equals('third'));
    });

    test('exportAsJson and clear work together correctly', () {
      logger.info('before clear');
      expect(store.exportAsJson(), isNot(equals('[]')));

      store.clear();
      expect(store.exportAsJson(), equals('[]'));
    });

    test('timestamp field is a valid ISO-8601 string', () {
      logger.info('ts check');
      final decoded = (json.decode(store.exportAsJson()) as List<dynamic>).first
          as Map<String, dynamic>;
      final ts = decoded['timestamp'] as String;
      expect(() => DateTime.parse(ts), returnsNormally);
    });

    test('level field uses lowercase level name', () {
      logger.warning('lvl check');
      final decoded = (json.decode(store.exportAsJson()) as List<dynamic>).first
          as Map<String, dynamic>;
      expect(decoded['level'], equals('warning'));
    });
  });

  group('MemoryLogStore – clear() (existing behaviour preserved)', () {
    test('clear removes all events and isEmpty becomes true', () {
      final store = MemoryLogStore();
      final factory = LoggingBuilder().addMemory(store: store).build();
      final logger = factory.createLogger('ClearTest');

      logger.info('a');
      logger.info('b');
      expect(store.length, equals(2));

      store.clear();
      expect(store.isEmpty, isTrue);
      expect(store.length, equals(0));
      factory.dispose();
    });
  });
}
