import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the import button says {'on this computer'}
Future<void> theImportButtonSays(WidgetTester tester, String words) async {
  final button = find.byKey(const Key('import-credential')).first;
  expect(find.descendant(of: button, matching: find.textContaining(words)), findsOneWidget);
}
