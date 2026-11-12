import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/idea_walk.dart';
import '../support/story_play.dart';

/// Usage: I run task list --watch in a terminal on the machine beside it
Future<void> iRunTaskListWatchInATerminalOnTheMachineBesideIt(WidgetTester tester) => played(
  tester,
  '10 the person runs porelo task list --watch in a terminal on the machine beside it',
  () async {
    final beside = Played.beside = TerminalOnTheMachine.open();
    addTearDown(() => Played.beside?.close());
    await until(
      tester,
      () => beside.lines.any((line) => line.isNotEmpty),
      within: const Duration(seconds: 20),
      asked: () => 'asked for a prompt in the terminal on the machine; it showed nothing',
    );
    beside.say('porelo task list --watch');
    await until(
      tester,
      () => beside.lines.any((line) => line.startsWith('NAME ')),
      within: const Duration(seconds: 30),
      asked: () =>
          'asked for the heading of the watch; it showed ${beside.lines.where((each) => each.isNotEmpty).join(' / ')}',
    );
    // Still showing a while later, rather than listing once and handing the prompt back.
    await pumpFor(tester, const Duration(seconds: 3));
    if (!await theWatchRuns()) {
      fail(
        'asked for the watch to keep showing; it ended, and the terminal showed: '
        '${beside.lines.where((each) => each.isNotEmpty).join(' / ')}',
      );
    }
  },
  leansOn: 'watch',
  goesOn: true,
);

/// Whether a `porelo task list --watch` runs on the machine; the bracket keeps pgrep from finding itself.
Future<bool> theWatchRuns() async =>
    (await inTheAccount("pgrep -f -- '[t]ask list --watch' >/dev/null && echo runs || echo ended")).trim() == 'runs';
