import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I open a new terminal from the tab
Future<void> iOpenANewTerminalFromTheTab(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('running-new-terminal')));
  await World.settle(tester);
}
