import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the machine counts a CRLF to LF file of three real lines {'lib/legacy.dart'}
///
/// As `Review` answers it: git's own count over every line, and the count without line ends beside it.
Future<void> theMachineCountsACrlfToLfFileOfThreeRealLines(WidgetTester tester, String path) async {
  World.backend
    ..theRanking = <ReviewFile>[
      ReviewFile(
        path: path,
        status: 'M',
        added: 1042,
        removed: 1043,
        rank: 'ORDINARY',
        reason: '',
        addedIgnoringLineEndings: 1,
        removedIgnoringLineEndings: 2,
      ),
    ]
    ..theDiffWithoutLineEndings =
        'diff --git a/$path b/$path\n--- a/$path\n+++ b/$path\n@@ -1,2 +1,1 @@\n-old one\n-old two\n+new one\n';
}
