import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I do not start it
Future<void> iDoNotStartIt(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(TextButton, 'Not now'));
  await World.settle(tester);
}
