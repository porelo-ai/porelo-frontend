import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the tab of {'porelo-billing-shell'} is chosen
Future<void> theTabOfIsChosen(WidgetTester tester, String work) async {
  expect(tester.widget<Text>(find.byKey(const Key('running-name'))).data, work);
}
