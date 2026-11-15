import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// The offer of the reader the planner orders after a start, in the shape the planner's offers take.
const followUpOffer = '00000000-0000-4000-8000-000000000291';

/// Usage: the planner orders a reader of {issue} after the next reported start
Future<void> thePlannerOrdersAReaderOfAfterTheNextReportedStart(WidgetTester tester, String issue) async {
  World.planning.followUpOnStart = {
    'offer': followUpOffer,
    'repository': 'porelo',
    'issues': [issue],
    'role': 'READER',
    // What it reads: the issue's builder, which the start ran.
    'reads': ['st291-porelo-builder-${issue.toLowerCase()}'],
    'agent': 'codex',
    'model': 'a-model',
    'prompt': 'Read $issue.',
  };
}
