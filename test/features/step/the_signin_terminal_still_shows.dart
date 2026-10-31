import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

/// Usage: the sign-in terminal still shows {'a loopback sign-in cannot run in a host account'}
///
/// Read off the terminal's own buffer: a terminal is painted, so there is no `Text` to look for.
Future<void> theSigninTerminalStillShows(WidgetTester tester, String words) async {
  final view = tester.widget<TerminalView>(find.byKey(const Key('unlock-terminal')));
  expect(view.terminal.buffer.getText(), contains(words));
}
