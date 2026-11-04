import 'package:flutter_test/flutter_test.dart';

/// Usage: there is no tab for {'porelo-billing-audit'}
Future<void> thereIsNoTabFor(WidgetTester tester, String work) async {
  expect(find.text(work.replaceFirst('porelo-', '')), findsNothing);
}
