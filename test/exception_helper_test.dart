import 'package:davianspace_logging/davianspace_logging.dart';
import 'package:test/test.dart';

void main() {
  group('LoggerExceptionExtension – logException', () {
    late MemoryLogStore store;
    late LoggerFactory factory;
    late Logger logger;

    setUp(() {
      store = MemoryLogStore();
      factory = LoggingBuilder()
          .addMemory(store: store)
          .setMinimumLevel(LogLevel.trace)
          .build();
      logger = factory.createLogger('ExceptionTest');
    });

    tearDown(() => factory.dispose());

    test('logException emits at LogLevel.error by default', () {
      final err = Exception('boom');
      final st = StackTrace.current;

      logger.logException(err, st);

      expect(store.length, equals(1));
      expect(store.events.first.level, equals(LogLevel.error));
    });

    test('logException stores error and stackTrace on the event', () {
      const err = FormatException('bad input');
      final st = StackTrace.current;

      logger.logException(err, st);

      final event = store.events.first;
      expect(event.error, same(err));
      expect(event.stackTrace, same(st));
    });

    test('logException derives message from error when not specified', () {
      final err = Exception('something went wrong');
      logger.logException(err, StackTrace.current);

      // Message should mention the error type or message.
      expect(store.events.first.message, isNotEmpty);
    });

    test('logException uses provided message instead of deriving one', () {
      logger.logException(
        Exception('internal'),
        StackTrace.current,
        message: 'Custom context message',
      );

      expect(store.events.first.message, equals('Custom context message'));
    });

    test('logException adds errorType and errorMessage to properties', () {
      const err = FormatException('parse failed');
      logger.logException(err, StackTrace.current);

      final props = store.events.first.properties;
      expect(props['errorType'], equals('FormatException'));
      expect(props['errorMessage'], equals(err.toString()));
    });

    test('logException merges caller properties alongside built-in keys', () {
      logger.logException(
        Exception('db error'),
        StackTrace.current,
        properties: {'orderId': 42, 'retryCount': 3},
      );

      final props = store.events.first.properties;
      expect(props['orderId'], equals(42));
      expect(props['retryCount'], equals(3));
      expect(props.containsKey('errorType'), isTrue);
    });

    test('caller properties can override built-in keys', () {
      logger.logException(
        Exception('x'),
        StackTrace.current,
        properties: {'errorType': 'custom'},
      );

      expect(store.events.first.properties['errorType'], equals('custom'));
    });

    test('logException respects custom LogLevel', () {
      logger.logException(
        Exception('warn-level'),
        StackTrace.current,
        level: LogLevel.warning,
      );

      expect(store.events.first.level, equals(LogLevel.warning));
    });

    test('logException is filtered by level like any other call', () {
      final filtered = MemoryLogStore();
      final filteredFactory = LoggingBuilder()
          .addMemory(store: filtered)
          .setMinimumLevel(LogLevel.critical)
          .build();
      final filteredLogger = filteredFactory.createLogger('FilteredEx');

      filteredLogger.logException(
        Exception('dropped'),
        StackTrace.current,
      );

      expect(filtered.isEmpty, isTrue);
      filteredFactory.dispose();
    });
  });
}
