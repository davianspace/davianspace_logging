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
// Example 8 — DavianLogger.quick() (zero-config console logger)
// ─────────────────────────────────────────────────────────────────────────────

void exampleQuickSetup() {
  print('── Example 8: DavianLogger.quick() ─────────────────────────────────');

  // Single-line — no LoggingBuilder, no factory wiring needed.
  final log = DavianLogger.quick(
    category: 'Bootstrap',
  );

  log.debug('Environment loaded');
  log.info('Server listening on :8080');
  log.warning('TLS certificate expires in 7 days');

  // Multiple loggers from the same internally shared factory.
  final factory = DavianLogger.quickFactory(minimumLevel: LogLevel.info);
  final authLog = factory.createLogger('Auth');
  final dbLog = factory.createLogger('Database');

  authLog.info('JWT validated', properties: {'sub': 'user-99'});
  dbLog.info('Connection pool ready', properties: {'size': 10});

  // Always dispose on exit in long-running processes.
  DavianLogger.disposeQuickFactory();
  print('');
}

// ─────────────────────────────────────────────────────────────────────────────
// Example 9 — Tag-based logging (LoggerTagExtension)
// ─────────────────────────────────────────────────────────────────────────────

void exampleTaggedLogging() {
  print(
      '── Example 9: Tag-based logging ─────────────────────────────────────');

  final store = MemoryLogStore();
  final factory = LoggingBuilder()
      .addConsole(formatter: const SimpleFormatter(includeTimestamp: false))
      .addMemory(store: store)
      .setMinimumLevel(LogLevel.trace)
      .build();

  final logger = factory.createLogger('App');

  // Per-level tagged helpers.
  logger.infoTagged('auth', 'User signed in', properties: {'userId': 42});
  logger.infoTagged('auth', 'Token refreshed');
  logger.debugTagged('cache', 'Cache miss for key "orders:99"');
  logger.warningTagged('payment', 'Retry attempt 1');
  logger.errorTagged('payment', 'Charge failed',
      error: Exception('Card declined'));

  // Query by tag from the memory store.
  final authEvents = store.eventsForTag('auth');
  final paymentEvents = store.eventsForTag('payment');
  print('auth events   : ${authEvents.length}'); // 2
  print('payment events: ${paymentEvents.length}'); // 2

  // The tag is accessible via the properties map.
  final tagValue = store.events.first.properties[LoggerTagExtension.tagKey];
  print('first tag     : $tagValue'); // auth

  factory.dispose();
  print('');
}

// ─────────────────────────────────────────────────────────────────────────────
// Example 10 — Exception helper (LoggerExceptionExtension)
// ─────────────────────────────────────────────────────────────────────────────

void exampleExceptionLogging() {
  print(
      '── Example 10: Exception helper ──────────────────────────────────────');

  final store = MemoryLogStore();
  final factory = LoggingBuilder()
      .addConsole(formatter: const SimpleFormatter(includeTimestamp: false))
      .addMemory(store: store)
      .setMinimumLevel(LogLevel.trace)
      .build();

  final logger = factory.createLogger('OrderService');

  try {
    throw const FormatException('invalid order payload');
  } catch (e, st) {
    // Minimal form — message auto-derived from the error.
    logger.logException(e, st);
  }

  try {
    throw Exception('Card declined');
  } catch (e, st) {
    // Full form with context and extra properties.
    logger.logException(
      e,
      st,
      message: 'Payment processing failed',
      properties: {'orderId': 1042, 'gateway': 'stripe'},
    );
  }

  // Both events carry errorType + errorMessage automatically.
  for (final event in store.events) {
    print('  [${event.level.name}] ${event.message}');
    print('    errorType    : ${event.properties['errorType']}');
    print('    errorMessage : ${event.properties['errorMessage']}');
  }

  factory.dispose();
  print('');
}

// ─────────────────────────────────────────────────────────────────────────────
// Example 11 — HTTP interceptor (HttpLogInterceptor)
// ─────────────────────────────────────────────────────────────────────────────

void exampleHttpInterceptor() {
  print(
      '── Example 11: HTTP interceptor ─────────────────────────────────────');

  final store = MemoryLogStore();
  final factory = LoggingBuilder()
      .addConsole(formatter: const SimpleFormatter(includeTimestamp: false))
      .addMemory(store: store)
      .setMinimumLevel(LogLevel.trace)
      .build();

  final logger = factory.createLogger('HttpClient');

  // Framework-agnostic: call onRequest / onResponse / onError from whatever
  // HTTP client wrapper your project uses (Dio, http, etc.).
  final http = HttpLogInterceptor(
    logger,
    // Enable in development only — may expose secrets in production.
    logHeaders: true,
  );

  // Simulate a successful request.
  http.onRequest('GET', 'https://api.example.com/orders/1', headers: {
    'Authorization': 'Bearer <token>',
    'Accept': 'application/json'
  });
  http.onResponse(200, 'https://api.example.com/orders/1', durationMs: 38);

  // Simulate a failed request.
  http.onRequest('POST', 'https://api.example.com/payments');
  http.onError(
    'POST',
    'https://api.example.com/payments',
    Exception('Connection timed out'),
    StackTrace.current,
  );

  print('Requests logged : ${store.eventsAtOrAbove(LogLevel.debug).length}');
  print('Errors logged   : ${store.eventsAtOrAbove(LogLevel.error).length}');

  // Inspect the structured properties added by the interceptor.
  final firstEvent = store.events.first;
  print('http.method : ${firstEvent.properties['http.method']}');
  print('http.url    : ${firstEvent.properties['http.url']}');

  factory.dispose();
  print('');
}

// ─────────────────────────────────────────────────────────────────────────────
// Example 12 — Memory store export (exportAsJson, bounded capacity)
// ─────────────────────────────────────────────────────────────────────────────

void exampleMemoryExport() {
  print('── Example 12: Memory store export ─────────────────────────────────');

  // Bounded store: keeps only the most recent 3 events.
  final store = MemoryLogStore(maxCapacity: 3);
  final factory = LoggingBuilder()
      .addMemory(store: store)
      .setMinimumLevel(LogLevel.trace)
      .build();

  final logger = factory.createLogger('AuditLog');

  logger.info('Event A');
  logger.info('Event B');
  logger.info('Event C');
  logger.warning('Event D'); // evicts 'Event A' (oldest)

  print('Store length after 4 events (max 3): ${store.length}'); // 3
  print('First retained event               : ${store.events.first.message}');

  // Export to JSON for shipping to a log aggregator, snapshot test, etc.
  final jsonOutput = store.exportAsJson();
  print('JSON export (truncated)            : ${jsonOutput.substring(0, 60)}…');

  // The exported JSON includes only non-empty optional fields.
  logger.error('Payment failed',
      error: Exception('Insufficient funds'), properties: {'orderId': 99});
  store.clear();
  logger.logException(Exception('Timeout'), StackTrace.current,
      properties: {'endpoint': '/checkout'});
  final exportWithError = store.exportAsJson();
  print('Error event JSON contains "errorType": '
      '${exportWithError.contains('errorType')}');

  factory.dispose();
  print('');
}

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
  exampleQuickSetup();
  exampleTaggedLogging();
  exampleExceptionLogging();
  exampleHttpInterceptor();
  exampleMemoryExport();
}
