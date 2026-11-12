import 'package:flutter_test/flutter_test.dart';

import '../support/idea_walk.dart';

/// Usage: the builder agent works until its task ends
Future<void> theBuilderAgentWorksUntilItsTaskEnds(WidgetTester tester) =>
    walked(tester, '7 the builder agent works until its task ends', () async {
      await untilItEnds(tester, Walk.builder!, within: Walk.taskDeadline, issue: Walk.issues.first.id);
    });
