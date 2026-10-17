import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I press {'Sign in first'}
Future<void> iPress(WidgetTester tester, String label) async {
  final button = find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate((each) => each is ButtonStyleButton),
  );
  await tester.tap(button.last);
  await World.settle(tester);
}
