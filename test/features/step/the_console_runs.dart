import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the console runs {'ssh -t alice@vm'}
Future<void> theConsoleRuns(WidgetTester tester, String command) async {
  // The whole line: the machine's own options, a terminal and its host, and no command after it.
  expect(World.terminals.last.command.join(' '), command);
  expect(find.byKey(const Key('ssh-console-terminal')), findsOneWidget, reason: 'it opens in the window');
}
