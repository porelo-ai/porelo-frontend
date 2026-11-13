import 'package:flutter_test/flutter_test.dart';

import '../support/idea_walk.dart';

/// Usage: the readers end
Future<void> theReadersEnd(WidgetTester tester) => walked(tester, '9 the readers end', () async {
  for (final reader in Walk.readers) {
    await untilItEnds(tester, reader, within: Walk.taskDeadline, issue: await theIssueOf(reader));
  }
  // What the planner says of the readings counts a reader only once its offer is bound.
  await untilEveryTaskBound(tester, Walk.readers, 'the readers');
});
