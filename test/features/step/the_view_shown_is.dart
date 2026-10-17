import 'package:flutter_test/flutter_test.dart';

/// Usage: the view shown is {'porelo-billing-shell · what its agent writes'}
Future<void> theViewShownIs(WidgetTester tester, String title) async {
  expect(find.text(title), findsOneWidget);
}
