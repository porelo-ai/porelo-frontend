import 'package:flutter_test/flutter_test.dart';

/// Usage: it names the work and the rule
Future<void> itNamesTheWorkAndTheRule(WidgetTester tester) async {
  // Enough context to tell what was attempted and by which piece of work — a destination alone
  // does not say whose it was, and five tasks can be asking at once.
  expect(find.textContaining('porelo-checkout-shell'), findsWidgets);
  expect(find.textContaining('egress/deny'), findsWidgets);
}
