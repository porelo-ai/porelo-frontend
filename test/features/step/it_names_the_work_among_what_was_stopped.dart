import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: it names the work {'porelo-checkout-shell'} among what was stopped
Future<void> itNamesTheWorkAmongWhatWasStopped(WidgetTester tester, String work) async {
  // The harm: a person told work was stopped that was not. The container name, in a row of what was
  // stopped, not anywhere on screen, where the work's own tile shows it too.
  final rows = find.byKey(const Key('stopped-task')).evaluate().map((each) => (each.widget as Text).data ?? '');
  expect(rows.where((row) => row.startsWith(work)), isNotEmpty, reason: 'stopped: ${rows.join(', ')}');
}
