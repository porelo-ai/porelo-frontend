import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/explanations.dart';
import '../support/world.dart';

/// Usage: I open the selection
Future<void> iOpenTheSelection(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await World.settle(tester);
  await closeTheExplanations(tester);
}
