import 'package:flutter_test/flutter_test.dart';

import '../support/idea_walk.dart';

/// Usage: the window starts the offered reader task and it ends
Future<void> theWindowStartsTheOfferedReaderTaskAndItEnds(WidgetTester tester) =>
    walked(tester, '9 the window starts the offered reader task and it ends', () async {
      // The window starts the planner's follow-up order by itself, as the answer to the builder's end.
      Walk.reader = theContainerOf(await theNewTask(tester, 'the reader task'));
      noteStep('   the reader runs in ${Walk.reader}');
      await untilItEnds(tester, Walk.reader!, within: Walk.taskDeadline, issue: Walk.issues.first.id);
    });
