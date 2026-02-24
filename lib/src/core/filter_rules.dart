import '../abstractions/log_level.dart';

/// A single log-filtering rule that maps a provider type and/or category
/// prefix to a minimum [LogLevel].
///
/// Rules are evaluated in registration order by [FilterRuleSet], which returns
/// the **most specific** matching rule for a given provider/category pair.
/// Specificity is defined as:
///
/// 1. Provider type **and** category prefix match (most specific).
/// 2. Category prefix match only.
/// 3. Provider type match only.
/// 4. Global rule (no provider, no prefix — least specific).
///
/// Example — raise the floor to [LogLevel.warning] for all categories whose
/// name starts with `'network'`, but only for the console provider:
///
/// ```dart
/// FilterRule(
///   providerType: ConsoleLoggerProvider,
///   categoryPrefix: 'network',
///   minimumLevel: LogLevel.warning,
/// )
/// ```
final class FilterRule {
  /// Creates a [FilterRule].
  ///
  /// Omit [providerType] to apply the rule to all providers.
  /// Omit [categoryPrefix] to apply the rule to all categories.
  const FilterRule({
    this.providerType,
    this.categoryPrefix,
    required this.minimumLevel,
  });

  /// The provider type this rule applies to, or `null` for all providers.
  final Type? providerType;

  /// Category prefix this rule applies to, or `null` for all categories.
  ///
  /// Matching is a simple `String.startsWith` check, so `'network'` matches
  /// both `'network'` and `'network.http'`.
  final String? categoryPrefix;

  /// The minimum [LogLevel] required for a log entry to pass through.
  final LogLevel minimumLevel;

  /// Returns `true` when this rule applies to [providerType] and [category].
  bool matches(Type providerType, String category) {
    if (this.providerType != null && this.providerType != providerType) {
      return false;
    }
    if (categoryPrefix != null && !category.startsWith(categoryPrefix!)) {
      return false;
    }
    return true;
  }

  /// Computes a specificity score for tie-breaking.
  ///
  /// Higher scores indicate more specific rules.
  int get _specificity {
    var score = 0;
    if (providerType != null) score += 2;
    if (categoryPrefix != null) score += 1;
    return score;
  }
}

/// An ordered collection of [FilterRule]s that resolves the effective minimum
/// [LogLevel] for a given provider type and category pair.
///
/// Instantiate once per `LoggerFactory` and reuse across threads (immutable
/// after construction).
///
/// ```dart
/// final rules = FilterRuleSet(
///   [
///     FilterRule(categoryPrefix: 'network', minimumLevel: LogLevel.warning),
///   ],
///   LogLevel.debug, // global minimum
/// );
///
/// final level = rules.getEffectiveLevel(ConsoleLoggerProvider, 'AuthService');
/// ```
final class FilterRuleSet {
  /// Creates a [FilterRuleSet].
  ///
  /// [globalMinimum] is returned when no rule matches; it acts as the
  /// catch-all floor.
  FilterRuleSet(List<FilterRule> rules, this.globalMinimum)
      : _rules = List.unmodifiable(rules);

  /// The fallback minimum level when no specific rule matches.
  final LogLevel globalMinimum;

  final List<FilterRule> _rules;

  /// Returns the effective minimum [LogLevel] for [providerType] and [category].
  ///
  /// Evaluates all registered rules and returns the minimum level of the
  /// most specific matching rule, or [globalMinimum] if none match.
  LogLevel getEffectiveLevel(Type providerType, String category) {
    FilterRule? best;

    for (final rule in _rules) {
      if (!rule.matches(providerType, category)) continue;
      if (best == null || rule._specificity > best._specificity) {
        best = rule;
      }
    }

    return best?.minimumLevel ?? globalMinimum;
  }

  /// Returns `true` if [level] passes the filter for [providerType] and
  /// [category].
  bool isEnabled(Type providerType, String category, LogLevel level) {
    final minimum = getEffectiveLevel(providerType, category);
    return level.isAtLeast(minimum);
  }
}
