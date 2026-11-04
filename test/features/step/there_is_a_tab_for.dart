import 'package:flutter_test/flutter_test.dart';

/// Usage: there is a tab for {'porelo-billing-shell'}
Future<void> thereIsATabFor(WidgetTester tester, String work) async {
  expect(find.text(work.replaceFirst('porelo-', '')), findsOneWidget);
}
