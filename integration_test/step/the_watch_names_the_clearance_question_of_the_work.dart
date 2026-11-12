import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/story_play.dart';

/// Usage: the watch names the clearance question of the work
///
/// A line of its own above the table, naming the work, while porelo still lists the question as waiting.
Future<void> theWatchNamesTheClearanceQuestionOfTheWork(WidgetTester tester) => played(
  tester,
  '13 the watch names the waiting clearance question of the work above its table',
  () async {
    final beside = Played.beside ?? fail('no terminal on the machine was opened');
    final row = await theListedRow() ?? fail('porelo task list prints no row of ${Played.project}');
    final names = {row.name, ?Played.container};
    bool hinted() {
      final lines = beside.lines;
      final heading = lines.indexWhere((line) => line.startsWith('NAME '));
      return heading > 0 && lines.take(heading).any((line) => names.any(line.contains));
    }

    final by = DateTime.now().add(const Duration(seconds: 30));
    while (!hinted()) {
      if (DateTime.now().isAfter(by)) {
        final waiting = '${(await theWork())?['waitingFor'] ?? ''}';
        fail(
          'asked for a line above the table naming ${names.join(' or ')} while porelo lists it waiting for '
          '"$waiting"; the watch showed: ${beside.lines.where((each) => each.isNotEmpty).join(' / ')}',
        );
      }
      await pumpFor(tester, const Duration(seconds: 2));
    }
  },
  leansOn: 'watch',
  goesOn: true,
);
