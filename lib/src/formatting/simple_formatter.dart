import '../abstractions/log_event.dart';
import 'log_formatter.dart';

/// Human-readable single-line log formatter.
///
/// Output format:
/// ```
/// 2026-02-25T14:23:01.123456Z [INFO ] AuthService » User logged in  {userId: 42}  {requestId: abc}
/// ```
///
/// Components:
/// - ISO-8601 UTC timestamp (microsecond precision)
/// - Fixed-width 4-character level label, padded with a space
/// - Category name
/// - Log message
/// - Inline properties (omitted when empty)
/// - Inline scope properties (omitted when no scope is active)
/// - Error and stack trace (on additional lines when present)
///
/// ### Usage
///
/// ```dart
/// LoggingBuilder()
///   .addConsole(formatter: SimpleFormatter())
///   .build();
/// ```
final class SimpleFormatter implements LogFormatter {
  /// Creates a [SimpleFormatter].
  ///
  /// Set [includeTimestamp] to `false` to suppress the timestamp prefix
  /// (useful when the output sink already adds timestamps, e.g. journald).
  ///
  /// Set [includeCategory] to `false` to suppress the category field.
  const SimpleFormatter({
    this.includeTimestamp = true,
    this.includeCategory = true,
  });

  /// Whether to include the ISO-8601 timestamp column.
  final bool includeTimestamp;

  /// Whether to include the category column.
  final bool includeCategory;

  @override
  String format(LogEvent event) {
    final buf = StringBuffer();

    // Timestamp
    if (includeTimestamp) {
      buf
        ..write(event.timestamp.toIso8601String())
        ..write(' ');
    }

    // Level label (5 chars: 4 + trailing space for column alignment)
    buf
      ..write('[')
      ..write(event.level.label)
      ..write('] ');

    // Category
    if (includeCategory) {
      buf
        ..write(event.category)
        ..write(' » ');
    }

    // Message
    buf.write(event.message);

    // Inline properties
    if (event.properties.isNotEmpty) {
      buf.write('  ');
      _writeMap(buf, event.properties);
    }

    // Scope properties
    if (event.scopeProperties.isNotEmpty) {
      buf.write('  scope:');
      _writeMap(buf, event.scopeProperties);
    }

    // Error
    if (event.error != null) {
      buf
        ..writeln()
        ..write('  Error: ')
        ..write(event.error);
    }

    // Stack trace
    if (event.stackTrace != null) {
      buf
        ..writeln()
        ..write('  StackTrace:\n')
        ..write(event.stackTrace);
    }

    return buf.toString();
  }

  static void _writeMap(StringBuffer buf, Map<String, Object?> map) {
    buf.write('{');
    var first = true;
    for (final entry in map.entries) {
      if (!first) buf.write(', ');
      buf
        ..write(entry.key)
        ..write(': ')
        ..write(_sanitizeValue(entry.value));
      first = false;
    }
    buf.write('}');
  }

  /// Converts [value] to a safe single-line string.
  ///
  /// Replaces `\n` and `\r` with `\n` and `\r` escape sequences to prevent
  /// log injection: a property containing a newline could otherwise masquerade
  /// as a separate log entry in the output stream.
  static String _sanitizeValue(Object? value) {
    if (value == null) return 'null';
    final s = value.toString();
    if (!s.contains('\n') && !s.contains('\r')) return s;
    return s
        .replaceAll('\r\n', r'\r\n')
        .replaceAll('\r', r'\r')
        .replaceAll('\n', r'\n');
  }
}
