import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

import '../support/e2e.dart';
import '../support/story_play.dart';

/// What was typed and erased before the line that went, which the work must never receive.
String? erased;

/// Usage: I type {'falsch'} and erase it with Ctrl-U before {'richtig'} in the terminal of the work
Future<void> iTypeAndEraseItWithCtrluBeforeInTheTerminalOfTheWork(WidgetTester tester, String wrong, String right) =>
    played(
      tester,
      '8 the person types "$wrong", erases it with Ctrl-U and sends "$right"',
      () async {
        final terminal = await intoTheTerminalOfTheWork(tester);
        erased = wrong;
        Played.typed.add(right);
        terminal.textInput(wrong);
        await pumpFor(tester, const Duration(milliseconds: 500));
        await pressWithCtrl(tester, LogicalKeyboardKey.keyU);
        terminal.textInput(right);
        await pumpFor(tester, const Duration(milliseconds: 500));
        terminal.keyInput(TerminalKey.enter);
        await pumpFor(tester);
      },
      leansOn: 'terminal',
      goesOn: true,
    );
