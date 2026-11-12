import 'package:flutter_test/flutter_test.dart';

import '../support/idea_walk.dart';

/// Usage: the window starts the offered reader task and it ends
Future<void> theWindowStartsTheOfferedReaderTaskAndItEnds(WidgetTester tester) =>
    walked(tester, '9 the window starts the offered reader task and it ends', () async {
      // The window starts the planner's follow-up order by itself, as the answer to the builder's end.
      // The builders are no readers: they were started after the tasks were noted.
      Walk.tasksBefore = {...Walk.tasksBefore, ...Walk.builders};
      Walk.readers = [
        for (final each in await theNewTasks(tester, 'the reader tasks', Walk.issues.length, within: Walk.taskDeadline))
          theContainerOf(each),
      ];
      noteStep('   the readers run in ${Walk.readers.join(', ')}');
      for (final reader in Walk.readers) {
        await untilItEnds(tester, reader, within: Walk.taskDeadline, issue: await theIssueOf(reader));
      }
    });
