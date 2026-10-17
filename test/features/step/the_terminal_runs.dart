import 'package:flutter_test/flutter_test.dart';

import '../support/over_ssh.dart';
import '../support/world.dart';

/// Usage: the terminal runs {'ssh -t porelo-the-build-machine porelo vault init'}
Future<void> theTerminalRuns(WidgetTester tester, String command) async {
  expect(World.terminals.last.command.join(' '), asRunOverSsh(command));
}
