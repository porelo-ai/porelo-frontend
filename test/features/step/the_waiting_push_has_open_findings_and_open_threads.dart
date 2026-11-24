import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the waiting push has {2} open findings and {3} open threads
Future<void> theWaitingPushHasOpenFindingsAndOpenThreads(WidgetTester tester, int findings, int threads) async {
  final runs = World.backend.theSummaries['migrate']?.runs ?? const <ReviewRun>[];
  World.backend.theSummaries['migrate'] = ReviewSummary(openFindings: findings, openThreads: threads, runs: runs);
}
