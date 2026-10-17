import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: it names the helper {'porelo-checkout-shell-gate (pid 4711)'}
Future<void> itNamesTheHelper(WidgetTester tester, String helper) async {
  // Named, never counted: somebody has to kill these by hand, and a number is something nobody
  // can act on.
  expect(find.byKey(const Key('surviving-helper')), findsWidgets);
  expect(find.text(helper), findsOneWidget);
}
