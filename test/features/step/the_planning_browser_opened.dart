import 'package:flutter_test/flutter_test.dart';

/// Usage: the planning browser opened {address}
Future<void> thePlanningBrowserOpened(WidgetTester tester, String address) async {
  expect(find.text('Browser opened $address'), findsOneWidget);
}
