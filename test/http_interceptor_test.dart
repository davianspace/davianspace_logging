import 'package:davianspace_logging/davianspace_logging.dart';
import 'package:test/test.dart';

void main() {
  group('HttpLogInterceptor', () {
    late MemoryLogStore store;
    late LoggerFactory factory;
    late Logger logger;
    late HttpLogInterceptor interceptor;

    setUp(() {
      store = MemoryLogStore();
      factory = LoggingBuilder()
          .addMemory(store: store)
          .setMinimumLevel(LogLevel.trace)
          .build();
      logger = factory.createLogger('HttpTest');
      interceptor = HttpLogInterceptor(logger);
    });

    tearDown(() => factory.dispose());

    // ── onRequest ──────────────────────────────────────────────────────────

    test('onRequest logs at debug level by default', () {
      interceptor.onRequest('GET', 'https://example.com/orders');
      expect(store.length, equals(1));
      expect(store.events.first.level, equals(LogLevel.debug));
    });

    test('onRequest message includes method and URL', () {
      interceptor.onRequest('POST', 'https://example.com/orders');
      expect(store.events.first.message, contains('POST'));
      expect(
          store.events.first.message, contains('https://example.com/orders'));
    });

    test('onRequest normalises method to upper-case', () {
      interceptor.onRequest('get', 'https://example.com');
      expect(store.events.first.message, contains('GET'));
      expect(store.events.first.properties['http.method'], equals('GET'));
    });

    test('onRequest stores http.method and http.url as properties', () {
      interceptor.onRequest('DELETE', 'https://api.test/items/1');
      final props = store.events.first.properties;
      expect(props['http.method'], equals('DELETE'));
      expect(props['http.url'], equals('https://api.test/items/1'));
    });

    test('onRequest does not include headers by default', () {
      interceptor.onRequest('GET', 'https://api.test',
          headers: {'Authorization': 'Bearer token'});
      expect(store.events.first.properties.containsKey('http.request.headers'),
          isFalse);
    });

    test('onRequest includes headers when logHeaders is true', () {
      final verboseInterceptor = HttpLogInterceptor(logger, logHeaders: true);
      verboseInterceptor.onRequest('GET', 'https://api.test',
          headers: {'Accept': 'application/json'});
      expect(store.events.first.properties['http.request.headers'], isNotNull);
    });

    test('onRequest does not include body by default', () {
      interceptor.onRequest('POST', 'https://api.test', body: '{"x":1}');
      expect(store.events.first.properties.containsKey('http.request.body'),
          isFalse);
    });

    test('onRequest includes body when logBody is true', () {
      final verboseInterceptor = HttpLogInterceptor(logger, logBody: true);
      verboseInterceptor.onRequest('POST', 'https://api.test', body: '{"x":1}');
      expect(store.events.first.properties['http.request.body'],
          equals('{"x":1}'));
    });

    test('onRequest is silent when logger level is above requestLevel', () {
      final quietFactory = LoggingBuilder()
          .addMemory(store: store)
          .setMinimumLevel(LogLevel.error)
          .build();
      final quietLogger = quietFactory.createLogger('quiet');
      final quietInterceptor = HttpLogInterceptor(quietLogger);

      quietInterceptor.onRequest('GET', 'https://example.com');
      expect(store.isEmpty, isTrue);
      quietFactory.dispose();
    });

    // ── onResponse ─────────────────────────────────────────────────────────

    test('onResponse logs at debug level by default', () {
      interceptor.onResponse(200, 'https://example.com/orders');
      expect(store.events.first.level, equals(LogLevel.debug));
    });

    test('onResponse message includes status code and URL', () {
      interceptor.onResponse(404, 'https://example.com/missing');
      expect(store.events.first.message, contains('404'));
      expect(
          store.events.first.message, contains('https://example.com/missing'));
    });

    test('onResponse stores http.status and http.url as properties', () {
      interceptor.onResponse(201, 'https://api.test/items');
      final props = store.events.first.properties;
      expect(props['http.status'], equals(201));
      expect(props['http.url'], equals('https://api.test/items'));
    });

    test('onResponse includes durationMs when provided', () {
      interceptor.onResponse(200, 'https://api.test', durationMs: 123);
      expect(store.events.first.properties['http.durationMs'], equals(123));
    });

    test('onResponse omits durationMs when not provided', () {
      interceptor.onResponse(200, 'https://api.test');
      expect(store.events.first.properties.containsKey('http.durationMs'),
          isFalse);
    });

    // ── onError ────────────────────────────────────────────────────────────

    test('onError logs at error level by default', () {
      interceptor.onError('GET', 'https://example.com', Exception('timeout'),
          StackTrace.current);
      expect(store.events.first.level, equals(LogLevel.error));
    });

    test('onError stores error and stackTrace on the event', () {
      final err = Exception('connection refused');
      final st = StackTrace.current;
      interceptor.onError('GET', 'https://api.test', err, st);

      expect(store.events.first.error, same(err));
      expect(store.events.first.stackTrace, same(st));
    });

    test('onError message includes method and URL', () {
      interceptor.onError('POST', 'https://api.test/items', Exception('err'),
          StackTrace.current);
      expect(store.events.first.message, contains('POST'));
      expect(store.events.first.message, contains('https://api.test/items'));
    });

    test('onError stores statusCode in properties when provided', () {
      interceptor.onError('GET', 'https://api.test', Exception('server error'),
          StackTrace.current,
          statusCode: 500);
      expect(store.events.first.properties['http.status'], equals(500));
    });

    test('onError omits statusCode from properties when not provided', () {
      interceptor.onError(
          'GET', 'https://api.test', Exception('timeout'), StackTrace.current);
      expect(store.events.first.properties.containsKey('http.status'), isFalse);
    });

    // ── Custom levels ───────────────────────────────────────────────────────

    test('custom requestLevel and responseLevel are respected', () {
      final customInterceptor = HttpLogInterceptor(
        logger,
        requestLevel: LogLevel.info,
        responseLevel: LogLevel.info,
        errorLevel: LogLevel.critical,
      );

      customInterceptor.onRequest('GET', 'https://api.test');
      customInterceptor.onResponse(200, 'https://api.test');
      customInterceptor.onError(
          'GET', 'https://api.test', Exception('x'), StackTrace.current);

      expect(store.events[0].level, equals(LogLevel.info));
      expect(store.events[1].level, equals(LogLevel.info));
      expect(store.events[2].level, equals(LogLevel.critical));
    });
  });
}
