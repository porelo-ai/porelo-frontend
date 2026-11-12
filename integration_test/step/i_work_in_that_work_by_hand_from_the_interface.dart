import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/idea_walk.dart';
import '../support/story_play.dart';

/// Usage: I work in that work by hand from the interface
Future<void> iWorkInThatWorkByHandFromTheInterface(WidgetTester tester) =>
    played(tester, '5 the person works in the work by hand from the window', () async {
      final container = Played.container ?? fail('no work was started');
      await chooseFromTheMenuOfTheTile(tester, container, 'Work in it by hand');
      Played.ofTheWork = await theSessionsTerminal(tester);
      // Ready once the stub says so in its session, read on the machine: what is typed before goes to nobody.
      var shown = <String>[];
      await until(
        tester,
        () async {
          try {
            shown = await theSessionOfTheWork();
          } on StateError {
            return false;
          }
          return shown.any((line) => line.contains('stub: at work, nothing asked'));
        },
        within: const Duration(minutes: 3),
        asked: () =>
            'asked for the stub waiting for input in the session of $container; it showed ${shown.join(' / ')}',
      );
    });
