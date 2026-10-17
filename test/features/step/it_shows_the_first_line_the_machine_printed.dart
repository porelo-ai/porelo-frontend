import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: it shows the first line the machine printed
Future<void> itShowsTheFirstLineTheMachinePrinted(WidgetTester tester) async {
  expect(
    tester.widget<SelectableText>(find.byKey(const Key('asking-output'))).data,
    contains('Reading package lists...'),
  );
}
