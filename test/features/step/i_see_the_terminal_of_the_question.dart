import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I see the terminal of the question
Future<void> iSeeTheTerminalOfTheQuestion(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('tile-see-terminal')).first);
  await World.settle(tester);
}
