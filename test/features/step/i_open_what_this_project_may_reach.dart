import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/explanations.dart';
import '../support/world.dart';

/// Usage: I open what this project may reach
Future<void> iOpenWhatThisProjectMayReach(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await World.settle(tester);
  await closeTheExplanations(tester);
}
