import 'package:flutter_test/flutter_test.dart';

import '../support/idea_walk.dart';
import '../support/story_play.dart';

/// Usage: I type {'Grüße von Zoë, mit Ångström und Leerzeichen'} into the terminal of the work
Future<void> iTypeIntoTheTerminalOfTheWork(WidgetTester tester, String words) => played(
  tester,
  '6 the person types "$words" and Enter into the terminal of the work',
  () async {
    final terminal = await intoTheTerminalOfTheWork(tester);
    Played.typed.add(words);
    await say(tester, terminal, words);
  },
  leansOn: 'terminal',
  goesOn: true,
);
