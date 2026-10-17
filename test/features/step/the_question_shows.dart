import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the question shows {'setsid porelod'}
Future<void> theQuestionShows(WidgetTester tester, String words) async {
  final shown = tester.widget<SelectableText>(find.byKey(const Key('forwarding-command'))).data!;
  expect(shown, contains(words));
}
