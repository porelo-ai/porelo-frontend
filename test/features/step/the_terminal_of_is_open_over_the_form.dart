import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the terminal of {'porelo-login-an-agent'} is open over the form
Future<void> theTerminalOfIsOpenOverTheForm(WidgetTester tester, String task) async {
  expect(World.sessions.beside, isNotEmpty, reason: 'no terminal of a login task is open');
  expect(World.sessions.beside.last.task, task);
  expect(World.terminals.last.command.join(' '), endsWith('porelo task attach $task'));
}
