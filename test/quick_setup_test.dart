import 'package:davianspace_logging/davianspace_logging.dart';
import 'package:test/test.dart';

void main() {
  // Always reset the shared quick factory between tests to prevent state
  // leaking from one test into the next.
  tearDown(DavianLogger.disposeQuickFactory);

  group('DavianLogger – quick()', () {
    test('quick() returns a non-null Logger', () {
      final logger = DavianLogger.quick();
      expect(logger, isNotNull);
      expect(logger, isA<Logger>());
    });

    test('quick() category defaults to "App"', () {
      final logger = DavianLogger.quick();
      expect(logger.category, equals('App'));
    });

    test('quick() category can be customised', () {
      final logger = DavianLogger.quick(category: 'OrderService');
      expect(logger.category, equals('OrderService'));
    });

    test('quick() minimum level defaults to LogLevel.debug', () {
      final logger = DavianLogger.quick();
      // Debug and above should be enabled.
      expect(logger.isEnabled(LogLevel.debug), isTrue);
      expect(logger.isEnabled(LogLevel.info), isTrue);
      expect(logger.isEnabled(LogLevel.error), isTrue);
      // Trace is below debug, so it should be disabled.
      expect(logger.isEnabled(LogLevel.trace), isFalse);
    });

    test('quick() respects custom minimumLevel', () {
      final logger = DavianLogger.quick(minimumLevel: LogLevel.warning);
      expect(logger.isEnabled(LogLevel.warning), isTrue);
      expect(logger.isEnabled(LogLevel.error), isTrue);
      expect(logger.isEnabled(LogLevel.info), isFalse);
    });

    test('quick() returns cached logger for same category', () {
      final a = DavianLogger.quick(category: 'A');
      final b = DavianLogger.quick(category: 'A');
      expect(identical(a, b), isTrue);
    });

    test('quick() returns distinct loggers for different categories', () {
      final a = DavianLogger.quick(category: 'A');
      final b = DavianLogger.quick(category: 'B');
      expect(identical(a, b), isFalse);
      expect(a.category, equals('A'));
      expect(b.category, equals('B'));
    });

    test('quick() rebuilds factory when minimumLevel changes', () {
      // First call: info-level factory.
      DavianLogger.quick(minimumLevel: LogLevel.info);

      // Second call with a different level forces a rebuild.
      final loggerWarn = DavianLogger.quick(minimumLevel: LogLevel.warning);
      expect(loggerWarn.isEnabled(LogLevel.warning), isTrue);
      expect(loggerWarn.isEnabled(LogLevel.info), isFalse);

      // Third call with info again: another rebuild; new logger reflects info floor.
      final loggerInfo2 = DavianLogger.quick(minimumLevel: LogLevel.info);
      expect(loggerInfo2.isEnabled(LogLevel.info), isTrue);
    });

    test('quick() logger accepts log calls without throwing', () {
      // We cannot easily capture ConsoleLoggerProvider output in a pure unit
      // test, but we verify the logger does not throw on normal use.
      final logger = DavianLogger.quick(minimumLevel: LogLevel.none);
      expect(
        () {
          logger.debug('should be filtered');
          logger.info('also filtered');
        },
        returnsNormally,
      );
    });
  });

  group('DavianLogger – quickFactory()', () {
    test('quickFactory() returns a non-null LoggerFactory', () {
      final factory = DavianLogger.quickFactory();
      expect(factory, isNotNull);
      expect(factory, isA<LoggerFactory>());
    });

    test('quickFactory() produces loggers matching quick()', () {
      final fromQuick = DavianLogger.quick(category: 'Svc');
      final fromFactory = DavianLogger.quickFactory().createLogger('Svc');
      expect(identical(fromQuick, fromFactory), isTrue);
    });
  });

  group('DavianLogger – disposeQuickFactory()', () {
    test('disposeQuickFactory() is idempotent when called multiple times', () {
      DavianLogger.quick(); // ensure factory is created
      expect(() {
        DavianLogger.disposeQuickFactory();
        DavianLogger.disposeQuickFactory();
      }, returnsNormally);
    });

    test('quick() can be called again after disposeQuickFactory()', () {
      DavianLogger.quick();
      DavianLogger.disposeQuickFactory();
      final logger = DavianLogger.quick();
      expect(logger, isNotNull);
    });
  });
}
