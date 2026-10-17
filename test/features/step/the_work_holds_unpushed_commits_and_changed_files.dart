import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the work holds {2} unpushed commits and {3} changed files
Future<void> theWorkHoldsUnpushedCommitsAndChangedFiles(WidgetTester tester, int commits, int files) async {
  World.backend.theWorkItHolds = HeldWork(
    readable: true,
    changedFiles: files,
    unpushedCommits: commits,
    // Absent: the answer is current, which is what makes it "holds" rather than "held".
  );
}
