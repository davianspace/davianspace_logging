// Examples use print and stdout for observable output.
// ignore_for_file: avoid_print

import 'package:davianspace_logging/davianspace_logging.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Domain objects used across examples
// ─────────────────────────────────────────────────────────────────────────────

class Order {
  Order(this.id, this.amount);
  final int id;
  final double amount;
}

// ─────────────────────────────────────────────────────────────────────────────
// Example 1 — Minimal console setup
// ─────────────────────────────────────────────────────────────────────────────

void exampleMinimalSetup() {
  print(
      '── Example 1: Minimal console setup ─────────────────────────────────');

  final factory =
      LoggingBuilder().addConsole().setMinimumLevel(LogLevel.debug).build();

  final logger = factory.createLogger('MyApp');

  logger.debug('Starting up…');
  logger.info('Application ready');
  logger.warning('Config file not found – using defaults');

  factory.dispose();
  print('');
}

// ─────────────────────────────────────────────────────────────────────────────
// Example 2 — Structured properties (no string interpolation required)
// ─────────────────────────────────────────────────────────────────────────────

void exampleStructuredProperties() {
  print(
      '── Example 2: Structured properties ─────────────────────────────────');

  final factory = LoggingBuilder()
      .addConsole(formatter: const SimpleFormatter(includeTimestamp: false))
      .setMinimumLevel(LogLevel.info)
      .build();

  final logger = factory.createLogger('OrderService');

  final order = Order(1042, 299.99);

  logger.info(
    'Order placed',
    properties: {
      'orderId': order.id,
      'amount': order.amount,
      'currency': 'USD',
    },
  );

  logger.error(
    'Payment failed',
    error: Exception('Card declined'),
    properties: {
      'orderId': order.id,
      'gateway': 'stripe',
    },
  );

  factory.dispose();
  print('');
}

// ─────────────────────────────────────────────────────────────────────────────
// Example 3 — Scoped logging (async-safe)
// ─────────────────────────────────────────────────────────────────────────────

Future<void> exampleScopedLogging() async {
  print(
      '── Example 3: Scoped logging ─────────────────────────────────────────');

  final factory = LoggingBuilder()
      .addConsole(formatter: const SimpleFormatter(includeTimestamp: false))
      .setMinimumLevel(LogLevel.trace)
      .build();

  final logger = factory.createLogger('RequestHandler');

  // Simulate processing two concurrent requests, each with its own scope.
  await Future.wait([
    _handleRequest(logger, 'req-A', userId: 1),
    _handleRequest(logger, 'req-B', userId: 2),
  ]);

  factory.dispose();
  print('');
}

Future<void> _handleRequest(
  Logger logger,
  String requestId, {
  required int userId,
}) async {
  final scope = logger.beginScope({
    'requestId': requestId,
    'userId': userId,
  });
  await scope.runAsync(() async {
    logger.info('Request received');
    await Future<void>.delayed(Duration.zero); // simulate async work
    logger.info('Request processed');
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Example 4 — Log-level filtering rules
// ─────────────────────────────────────────────────────────────────────────────

void exampleFilterRules() {
  print(
      '── Example 4: Filter rules ───────────────────────────────────────────');

  final factory = LoggingBuilder()
      .addConsole(formatter: const SimpleFormatter(includeTimestamp: false))
      // Global floor: debug+
      .setMinimumLevel(LogLevel.debug)
      // Override: only errors from 'network.*' categories
      .addFilterRule(
        const FilterRule(
          categoryPrefix: 'network',
          minimumLevel: LogLevel.error,
        ),
      )
      .build();

  factory.createLogger('auth').debug('JWT validated'); // shown
  factory.createLogger('network.http').debug('GET /api'); // suppressed
  factory.createLogger('network.http').error('Timeout'); // shown
  factory.createLogger('db').info('Query executed'); // shown

  factory.dispose();
  print('');
}

// ─────────────────────────────────────────────────────────────────────────────
// Example 5 — JSON formatter (for log aggregation pipelines)
// ─────────────────────────────────────────────────────────────────────────────

void exampleJsonFormatter() {
  print(
      '── Example 5: JSON formatter ─────────────────────────────────────────');

  final factory = LoggingBuilder()
      .addConsole(formatter: const JsonFormatter())
      .setMinimumLevel(LogLevel.info)
      .build();

  factory.createLogger('Audit').info(
    'User action',
    properties: {
      'userId': 99,
      'action': 'delete',
      'targetId': 55,
    },
  );

  factory.dispose();
  print('');
}

// ─────────────────────────────────────────────────────────────────────────────
// Example 6 — Multiple providers simultaneously
// ─────────────────────────────────────────────────────────────────────────────

void exampleMultipleProviders() {
  print(
      '── Example 6: Multiple providers ────────────────────────────────────');

  final memoryStore = MemoryLogStore();

  // Console: human-readable for developer eyes.
  // Memory:  queryable store for health-checks or tests.
  final factory = LoggingBuilder()
      .addConsole(formatter: const SimpleFormatter(includeTimestamp: false))
      .addMemory(store: memoryStore)
      .setMinimumLevel(LogLevel.info)
      .build();

  final logger = factory.createLogger('PaymentGateway');
  logger.info('Charge initiated', properties: {'amount': 100});
  logger.warning('Retry attempt 1');
  logger.error('Charge failed', error: Exception('Insufficient funds'));

  print('Events in memory store: ${memoryStore.length}');
  print('Errors in memory store: '
      '${memoryStore.eventsAtOrAbove(LogLevel.error).length}');

  factory.dispose();
  print('');
}

// ─────────────────────────────────────────────────────────────────────────────
// Example 7 — isEnabled guard (zero allocation when disabled)
// ─────────────────────────────────────────────────────────────────────────────

void exampleIsEnabledGuard() {
  print(
      '── Example 7: isEnabled guard ────────────────────────────────────────');

  final factory = LoggingBuilder()
      .addConsole(formatter: const SimpleFormatter(includeTimestamp: false))
      .setMinimumLevel(LogLevel.warning)
      .build();

  final logger = factory.createLogger('PerfSensitive');

  // Expensive operation guarded — runs only when debug is enabled.
  if (logger.isEnabled(LogLevel.debug)) {
    // This block is not entered when minimum level is warning.
    logger.debug('Cache snapshot: ${_buildExpensiveSnapshot()}');
  }

  logger.warning('Processing threshold exceeded');

  factory.dispose();
  print('');
}

String _buildExpensiveSnapshot() => '[very large cache dump]';

// ─────────────────────────────────────────────────────────────────────────────
// main
// ─────────────────────────────────────────────────────────────────────────────

Future<void> main() async {
  exampleMinimalSetup();
  exampleStructuredProperties();
  await exampleScopedLogging();
  exampleFilterRules();
  exampleJsonFormatter();
  exampleMultipleProviders();
  exampleIsEnabledGuard();
}
