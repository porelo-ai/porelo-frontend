import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: it names the work {'porelo-checkout-shell'} among what was stopped
Future<void> itNamesTheWorkAmongWhatWasStopped(WidgetTester tester, String work) async {
  // The container name, so the row says exactly which work was stopped.
  expect(find.byKey(const Key('stopped-task')), findsWidgets);
  expect(find.textContaining(work), findsWidgets);
}
