import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I press Ctrl and Page Up
Future<void> iPressCtrlAndPageUp(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await World.settle(tester);
}
