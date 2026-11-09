import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: planning Save is usable
Future<void> planningSaveIsUsable(WidgetTester tester) async {
  // Disabling Save after a stale reply or an unrelated refusal makes this fail.
  expect(tester.widget<FilledButton>(planningElement('save')).onPressed, isNotNull);
}
