import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the waiting push's check {'owner review'} is {'partial'} with {0} findings
Future<void> theWaitingPushsCheckIsWithFindings(
  WidgetTester tester,
  String name,
  String completeness,
  int findings,
) async {
  World.backend.theSummaries['migrate'] = ReviewSummary(
    openFindings: findings,
    openThreads: 0,
    runs: <ReviewRun>[ReviewRun(name: name, completeness: completeness, findings: findings)],
  );
}
