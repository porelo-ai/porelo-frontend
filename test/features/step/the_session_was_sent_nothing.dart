import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the session was sent nothing
Future<void> theSessionWasSentNothing(WidgetTester tester) async {
  for (final terminal in World.terminals) {
    expect(terminal.typed, isEmpty);
  }
}
