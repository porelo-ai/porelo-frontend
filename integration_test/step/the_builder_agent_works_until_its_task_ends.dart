import 'package:flutter_test/flutter_test.dart';

import '../support/idea_walk.dart';

/// Usage: the builder agent works until its task ends
Future<void> theBuilderAgentWorksUntilItsTaskEnds(WidgetTester tester) =>
    walked(tester, '7 the builder agent works until its task ends', () async {
      for (final builder in Walk.builders) {
        await untilItEnds(tester, builder, within: Walk.taskDeadline, issue: await theIssueOf(builder));
      }
    });
