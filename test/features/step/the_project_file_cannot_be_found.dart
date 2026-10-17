import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the project file cannot be found
Future<void> theProjectFileCannotBeFound(WidgetTester tester) async {
  // The run is widened and the file is not, because nothing knows where the file is. Set here
  // rather than contrived out of a project fixture: it is the daemon's answer that matters.
  World.backend.nextWidening = Widened.from(const <String, dynamic>{
    'outcome': 'NO_PROJECT_FILE',
    'opens': <String>['files.example.test'],
    'persisted': false,
    'detail': 'the run can reach it; no project file is recorded, so nothing was written',
  });
}
