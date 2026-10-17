import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: it offers the package {'porelo-agent-claude'}
Future<void> itOffersThePackage(WidgetTester tester, String name) async {
  final choice = tester.widget<CheckboxListTile>(find.byKey(Key('package-$name')));
  expect(choice.value, isFalse, reason: 'it was chosen for the person');
  expect(choice.onChanged, isNotNull);
}
