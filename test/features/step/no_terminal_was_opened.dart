import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: no terminal was opened
Future<void> noTerminalWasOpened(WidgetTester tester) async {
  expect(World.terminals, isEmpty);
}
