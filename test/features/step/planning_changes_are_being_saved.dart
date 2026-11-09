import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: planning changes are being saved
Future<void> planningChangesAreBeingSaved(WidgetTester tester) async {
  final save = planningElement('save-moves');
  expect(planningText(tester, save), 'Saving changes…');
  expect(tester.widget<FilledButton>(save).onPressed, isNull);
}
