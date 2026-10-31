import 'package:flutter_test/flutter_test.dart';

/// Usage: the terminal is headed by {'Paste the code shown in your browser'}
Future<void> theTerminalIsHeadedBy(WidgetTester tester, String words) async {
  expect(find.textContaining(words), findsOneWidget);
}
