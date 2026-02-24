/// Defines the verbosity of a log entry.
///
/// Levels are ordered from least to most severe:
/// [trace] < [debug] < [info] < [warning] < [error] < [critical] < [none].
///
/// Use [none] to disable all logging for a category or provider.
///
/// Example:
/// ```dart
/// if (logger.isEnabled(LogLevel.info)) {
///   logger.info('Server started on port $port');
/// }
/// ```
enum LogLevel {
  /// Highly detailed diagnostic messages. Disabled in production by default.
  trace,

  /// Developer-facing diagnostic messages useful during development.
  debug,

  /// Informational messages tracking normal application flow.
  info,

  /// Unexpected but recoverable situations that deserve attention.
  warning,

  /// Failures that prevent completing the current operation.
  error,

  /// Unrecoverable failures requiring immediate intervention.
  critical,

  /// Special sentinel level used to disable all logging.
  ///
  /// No messages are written when the minimum level is set to [none].
  none;

  /// Returns `true` if this level is at least as severe as [minimum].
  ///
  /// ```dart
  /// LogLevel.warning.isAtLeast(LogLevel.info); // true
  /// LogLevel.debug.isAtLeast(LogLevel.info);   // false
  /// ```
  bool isAtLeast(LogLevel minimum) => index >= minimum.index;

  /// Short, fixed-width label used by formatters.
  String get label => switch (this) {
        LogLevel.trace => 'TRCE',
        LogLevel.debug => 'DBUG',
        LogLevel.info => 'INFO',
        LogLevel.warning => 'WARN',
        LogLevel.error => 'EROR',
        LogLevel.critical => 'CRIT',
        LogLevel.none => 'NONE',
      };
}
