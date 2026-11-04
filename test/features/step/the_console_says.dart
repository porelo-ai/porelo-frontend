import 'package:flutter_test/flutter_test.dart';

/// Usage: the console says {'reading the contracts'}
Future<void> theConsoleSays(WidgetTester tester, String words) async {
  expect(find.textContaining(words, findRichText: true), findsWidgets);
}
