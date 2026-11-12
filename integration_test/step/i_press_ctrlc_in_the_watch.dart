import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

import '../support/story_play.dart';
import 'i_run_task_list_watch_in_a_terminal_on_the_machine_beside_it.dart';

/// Usage: I press Ctrl-C in the watch
Future<void> iPressCtrlcInTheWatch(WidgetTester tester) => played(
  tester,
  '16 the person presses Ctrl-C in the watch, and it ends',
  () async {
    final beside = Played.beside ?? fail('no terminal on the machine was opened');
    beside.terminal.keyInput(TerminalKey.keyC, ctrl: true);
    await until(
      tester,
      () async => !await theWatchRuns(),
      within: const Duration(seconds: 10),
      asked: () => 'asked for the watch to end on Ctrl-C; it still runs',
    );
  },
  leansOn: 'watch',
  goesOn: true,
);
