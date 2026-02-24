/// Abstraction over the system clock, enabling deterministic testing.
///
/// The default implementation ([UtcTimestampProvider]) returns `DateTime.timestamp()`.
/// Inject a custom implementation in tests to control the reported time:
///
/// ```dart
/// class FixedTimestampProvider implements TimestampProvider {
///   FixedTimestampProvider(this._fixed);
///   final DateTime _fixed;
///   @override
///   DateTime now() => _fixed;
/// }
/// ```
abstract interface class TimestampProvider {
  /// Returns the current timestamp.
  ///
  /// Implementations should return a UTC [DateTime] for consistency across
  /// time zones.
  DateTime now();
}

/// The default [TimestampProvider] that delegates to [DateTime.timestamp].
///
/// `DateTime.timestamp()` always returns a UTC value and is slightly more
/// efficient than `DateTime.now().toUtc()`.
final class UtcTimestampProvider implements TimestampProvider {
  /// Creates a [UtcTimestampProvider].
  const UtcTimestampProvider();

  @override
  DateTime now() => DateTime.timestamp();
}
