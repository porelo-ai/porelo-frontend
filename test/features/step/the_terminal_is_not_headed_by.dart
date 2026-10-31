import 'package:flutter_test/flutter_test.dart';

/// Usage: the terminal is not headed by {'Paste the code'}
Future<void> theTerminalIsNotHeadedBy(WidgetTester tester, String words) async {
  expect(find.textContaining(words), findsNothing);
}
