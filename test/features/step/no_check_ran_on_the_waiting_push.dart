import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: no check ran on the waiting push
Future<void> noCheckRanOnTheWaitingPush(WidgetTester tester) async {
  World.backend.theSummaries['migrate'] = const ReviewSummary(openFindings: 0, openThreads: 0, runs: <ReviewRun>[]);
}
