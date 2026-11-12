import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/idea_walk.dart';
import '../support/story_play.dart';

/// Usage: I end the agent of the work with Ctrl-D in its terminal
///
/// Ctrl-D on an empty line ends the stub's input, and the stub with it. Where porelo still lists the work running
/// after that, the person stops it, as they would, so the watch has an end to show either way.
Future<void> iEndTheAgentOfTheWorkWithCtrldInItsTerminal(WidgetTester tester) => played(
  tester,
  '14 the person ends the agent of the work with Ctrl-D in its terminal',
  () async {
    final container = Played.container ?? fail('no work was started');
    try {
      await intoTheTerminalOfTheWork(tester);
      await pressWithCtrl(tester, LogicalKeyboardKey.keyD);
      var running = '';
      await until(
        tester,
        () async {
          try {
            running = await inTheWork(r'for p in /proc/[0-9]*; do tr "\0" " " <"$p/cmdline" 2>/dev/null; echo; done');
          } on StateError {
            return true;
          }
          return !running.contains('porelo-stub-cli');
        },
        within: const Duration(seconds: 60),
        asked: () => 'asked for the stub in $container to end on Ctrl-D; it still runs',
      );
    } finally {
      await _endedOrStopped(tester, container);
    }
  },
  leansOn: 'terminal',
  goesOn: true,
);

Future<void> _endedOrStopped(WidgetTester tester, String container) async {
  final by = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(by)) {
    final work = await theWork();
    if (work == null || hasEnded(work) || work['activity'] == 'ENDED' || work['activity'] == 'DONE') return;
    await pumpFor(tester, const Duration(seconds: 2));
  }
  debugPrint('porelo still lists $container running after its agent was ended; it is stopped');
  await inTheAccount('porelo task stop $container >/dev/null');
}
