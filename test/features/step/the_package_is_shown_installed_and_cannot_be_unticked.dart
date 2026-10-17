import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the package {'porelo-message-transport-matrix'} is shown installed and cannot be unticked
Future<void> thePackageIsShownInstalledAndCannotBeUnticked(WidgetTester tester, String name) async {
  final choice = tester.widget<CheckboxListTile>(find.byKey(Key('package-$name')));
  expect(choice.value, isTrue);
  expect(choice.onChanged, isNull);
}
