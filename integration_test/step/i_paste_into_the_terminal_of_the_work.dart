import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/story_play.dart';

/// Usage: I paste {'erste Zeile|zweite Zeile mit ä|dritte Zeile'} into the terminal of the work
///
/// The lines are separated by `|` and pasted as one block, each ended as a copied line is: from the clipboard, with
/// the keys the window pastes with.
Future<void> iPasteIntoTheTerminalOfTheWork(WidgetTester tester, String block) => played(
  tester,
  '7 the person pastes the lines "$block" into the terminal of the work',
  () async {
    final lines = block.split('|');
    await Clipboard.setData(ClipboardData(text: '${lines.join('\n')}\n'));
    await intoTheTerminalOfTheWork(tester);
    Played.typed.addAll(lines);
    await pressWithCtrl(tester, LogicalKeyboardKey.keyV, shift: true);
    await pumpFor(tester, const Duration(seconds: 1));
  },
  leansOn: 'terminal',
  goesOn: true,
);
