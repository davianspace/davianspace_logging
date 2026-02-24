import 'dart:convert' show JsonEncoder, json;

import '../abstractions/log_event.dart';
import 'log_formatter.dart';

/// Structured JSON log formatter.
///
/// Each [LogEvent] is serialized to a single JSON object on one line,
/// suitable for ingestion by log aggregation pipelines (e.g. Elasticsearch,
/// Datadog, Google Cloud Logging).
///
/// ### Schema
///
/// ```json
/// {
///   "timestamp": "2026-02-25T14:23:01.123456Z",
///   "level":     "info",
///   "category":  "AuthService",
///   "message":   "User logged in",
///   "properties": { "userId": 42 },
///   "scope":      { "requestId": "abc123" },
///   "error":      "FormatException: bad input",
///   "stackTrace": "..."
/// }
/// ```
///
/// Fields with empty/null values are omitted to keep payloads compact.
///
/// ### Usage
///
/// ```dart
/// LoggingBuilder()
///   .addConsole(formatter: JsonFormatter())
///   .build();
/// ```
final class JsonFormatter implements LogFormatter {
  /// Creates a [JsonFormatter].
  ///
  /// Set [prettyPrint] to `true` to format with indentation (useful during
  /// development; disable in production for compact single-line output).
  const JsonFormatter({this.prettyPrint = false});

  /// Whether to pretty-print the JSON output with 2-space indentation.
  final bool prettyPrint;

  @override
  String format(LogEvent event) {
    final map = <String, Object?>{
      'timestamp': event.timestamp.toIso8601String(),
      'level': event.level.name,
      'category': event.category,
      'message': event.message,
    };

    if (event.properties.isNotEmpty) {
      map['properties'] = _sanitizeMap(event.properties);
    }

    if (event.scopeProperties.isNotEmpty) {
      map['scope'] = _sanitizeMap(event.scopeProperties);
    }

    if (event.error != null) {
      map['error'] = event.error.toString();
    }

    if (event.stackTrace != null) {
      map['stackTrace'] = event.stackTrace.toString();
    }

    return prettyPrint
        ? const JsonEncoder.withIndent('  ').convert(map)
        : json.encode(map);
  }

  /// Converts values to JSON-safe types.
  ///
  /// Values that are already JSON primitives (bool, num, String, null,
  /// List, Map) pass through unchanged. Everything else is converted via
  /// [Object.toString].
  static Map<String, Object?> _sanitizeMap(Map<String, Object?> source) {
    final result = <String, Object?>{};
    for (final entry in source.entries) {
      result[entry.key] = _sanitize(entry.value);
    }
    return result;
  }

  static Object? _sanitize(Object? value) => switch (value) {
        null => null,
        bool() => value,
        num() => value,
        String() => value,
        List<Object?>() => [for (final v in value) _sanitize(v)],
        Map<String, Object?>() => _sanitizeMap(value),
        _ => value.toString(),
      };
}
