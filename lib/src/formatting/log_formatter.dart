import '../abstractions/log_event.dart';

/// Converts a [LogEvent] into a string representation for output.
///
/// Implement this interface to produce custom log output formats.
/// Built-in implementations are `SimpleFormatter` (human-readable) and
/// `JsonFormatter` (machine-readable JSON).
///
/// Providers receive a [LogFormatter] instance and call [format] on each
/// [LogEvent] they accept.
///
/// Example — registering a JSON formatter with the console provider:
///
/// ```dart
/// LoggingBuilder().addConsole(formatter: JsonFormatter()).build();
/// ```
abstract interface class LogFormatter {
  /// Formats [event] into a string.
  ///
  /// Implementations should be pure functions with no side-effects.
  /// The returned string must not end with a trailing newline; providers
  /// are responsible for line termination.
  String format(LogEvent event);
}
