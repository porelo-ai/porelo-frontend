import 'package:flutter_test/flutter_test.dart';

/// Usage: it says its name is {'porelo-checkout-shell'}
Future<void> itSaysItsNameIs(WidgetTester tester, String name) async {
  expect(find.textContaining('Its name'), findsOneWidget);
  expect(find.text(name), findsWidgets);
}
