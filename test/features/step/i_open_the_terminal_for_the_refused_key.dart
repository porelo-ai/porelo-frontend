import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I open the terminal for the refused key
Future<void> iOpenTheTerminalForTheRefusedKey(WidgetTester tester) async {
  final button = find.byKey(const Key('refused-key-terminal'));
  await tester.ensureVisible(button);
  await World.settle(tester);
  await tester.tap(button);
  await World.settle(tester);
}
