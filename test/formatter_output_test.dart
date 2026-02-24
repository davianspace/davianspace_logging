import 'dart:convert' show jsonDecode;

import 'package:davianspace_logging/davianspace_logging.dart';
import 'package:test/test.dart';

/// A fixed timestamp used across all formatter tests for reproducible output.
final _ts = DateTime.utc(2026, 2, 25, 14, 23, 1, 123, 456);

/// Convenience: build a [LogEvent] with common defaults.
LogEvent _event({
  LogLevel level = LogLevel.info,
  String category = 'TestCategory',
  String message = 'Test message',
  Map<String, Object?> properties = const {},
  Map<String, Object?> scopeProperties = const {},
  Object? error,
  StackTrace? stackTrace,
}) =>
    LogEvent(
      level: level,
      category: category,
      message: message,
      timestamp: _ts,
      properties: properties,
      scopeProperties: scopeProperties,
      error: error,
      stackTrace: stackTrace,
    );

void main() {
  // ── SimpleFormatter ────────────────────────────────────────────────────────
  group('SimpleFormatter', () {
    const fmt = SimpleFormatter();

    test('output contains ISO timestamp', () {
      expect(fmt.format(_event()), contains('2026-02-25T14:23:01'));
    });

    test('output contains level label', () {
      expect(fmt.format(_event()), contains('[INFO]'));
      expect(fmt.format(_event(level: LogLevel.warning)), contains('[WARN]'));
      expect(fmt.format(_event(level: LogLevel.error)), contains('[EROR]'));
      expect(fmt.format(_event(level: LogLevel.critical)), contains('[CRIT]'));
      expect(fmt.format(_event(level: LogLevel.debug)), contains('[DBUG]'));
      expect(fmt.format(_event(level: LogLevel.trace)), contains('[TRCE]'));
    });

    test('output contains category', () {
      expect(
          fmt.format(_event(category: 'AuthService')), contains('AuthService'));
    });

    test('output contains message', () {
      expect(
          fmt.format(_event(message: 'hello world')), contains('hello world'));
    });

    test('properties appear inline', () {
      final output = fmt.format(_event(properties: {'userId': 42}));
      expect(output, contains('userId: 42'));
    });

    test('scope properties appear with scope: prefix', () {
      final output = fmt.format(_event(scopeProperties: {'requestId': 'abc'}));
      expect(output, contains('scope:'));
      expect(output, contains('requestId: abc'));
    });

    test('error appears on separate line', () {
      final output = fmt.format(_event(error: Exception('boom')));
      expect(output, contains('Error: Exception: boom'));
    });

    test('stack trace appears in output', () {
      final st = StackTrace.fromString('  at foo (bar.dart:1)');
      final output = fmt.format(_event(stackTrace: st));
      expect(output, contains('StackTrace'));
      expect(output, contains('foo'));
    });

    test('includeTimestamp: false omits timestamp', () {
      const noTs = SimpleFormatter(includeTimestamp: false);
      final output = noTs.format(_event());
      expect(output, isNot(contains('2026')));
    });

    test('includeCategory: false omits category', () {
      const noCat = SimpleFormatter(includeCategory: false);
      final output = noCat.format(_event(category: 'ShouldBeAbsent'));
      expect(output, isNot(contains('ShouldBeAbsent')));
    });
  });

  // ── JsonFormatter ──────────────────────────────────────────────────────────
  group('JsonFormatter', () {
    const fmt = JsonFormatter();

    Map<String, dynamic> parse(LogEvent event) =>
        jsonDecode(fmt.format(event)) as Map<String, dynamic>;

    test('output is valid JSON', () {
      expect(() => fmt.format(_event()), returnsNormally);
    });

    test('timestamp field is ISO string', () {
      final map = parse(_event());
      expect(map['timestamp'], equals('2026-02-25T14:23:01.123456Z'));
    });

    test('level field contains level name', () {
      final map = parse(_event(level: LogLevel.warning));
      expect(map['level'], equals('warning'));
    });

    test('category and message fields are present', () {
      final map = parse(_event(category: 'svc', message: 'hello'));
      expect(map['category'], equals('svc'));
      expect(map['message'], equals('hello'));
    });

    test('properties field present when non-empty', () {
      final map = parse(_event(properties: {'x': 1}));
      expect(map['properties'], isA<Map<String, dynamic>>());
      expect((map['properties'] as Map<String, dynamic>)['x'], equals(1));
    });

    test('properties field absent when empty', () {
      final map = parse(_event());
      expect(map.containsKey('properties'), isFalse);
    });

    test('scope field present when non-empty', () {
      final map = parse(_event(scopeProperties: {'req': 'r'}));
      expect(map.containsKey('scope'), isTrue);
      expect((map['scope'] as Map<String, dynamic>)['req'], equals('r'));
    });

    test('error field present when error supplied', () {
      final map = parse(_event(error: Exception('oops')));
      expect(map['error'], contains('oops'));
    });

    test('stackTrace field absent when null', () {
      final map = parse(_event());
      expect(map.containsKey('stackTrace'), isFalse);
    });

    test('non-JSON values are converted to string', () {
      // An object with a custom toString().
      final map = parse(_event(properties: {'obj': _CustomObject()}));
      final propsMap = map['properties'] as Map<String, dynamic>;
      expect(propsMap['obj'], equals('custom-object'));
    });

    test('prettyPrint produces indented output', () {
      const prettyFmt = JsonFormatter(prettyPrint: true);
      final output = prettyFmt.format(_event(properties: {'a': 1}));
      expect(output, contains('\n')); // indented → has newlines
    });

    test('compact output has no newlines', () {
      final output = fmt.format(_event(properties: {'a': 1}));
      expect(output, isNot(contains('\n')));
    });
  });
}

final class _CustomObject {
  @override
  String toString() => 'custom-object';
}
