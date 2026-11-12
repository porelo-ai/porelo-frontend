import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/story_play.dart';

/// Usage: the terminal gives an ordinary prompt back
///
/// Proven as a person proves it: a word echoed comes back once, on a line of its own, after the command typed shows as
/// typed; the cursor is shown, and no screen of the watch is left over.
Future<void> theTerminalGivesAnOrdinaryPromptBack(WidgetTester tester) => played(
  tester,
  '17 the terminal gives an ordinary prompt back',
  () async {
    final beside = Played.beside ?? fail('no terminal on the machine was opened');
    final word = 'prompt-back-${Random().nextInt(1 << 30)}';
    beside.say('echo $word');
    await until(
      tester,
      () => beside.lines.contains(word),
      within: const Duration(seconds: 10),
      asked: () =>
          'asked for "$word" echoed back; the terminal showed ${beside.lines.where((each) => each.isNotEmpty).join(' / ')}',
    );
    await pumpFor(tester, const Duration(seconds: 1));
    final lines = beside.lines;
    final wrong = [
      if (lines.where((line) => line == word).length != 1)
        '"$word" came back ${lines.where((line) => line == word).length} times',
      if (!lines.any((line) => line.endsWith('echo $word'))) 'what was typed was not echoed',
      if (beside.terminal.isUsingAltBuffer) 'the screen of the watch is still up',
      if (!beside.terminal.cursorVisibleMode) 'the cursor is hidden',
    ];
    if (wrong.isNotEmpty) {
      fail(
        'asked for an ordinary prompt; ${wrong.join(', ')}; it showed ${lines.where((e) => e.isNotEmpty).join(' / ')}',
      );
    }
  },
  leansOn: 'watch',
  goesOn: true,
);
