import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';

/// Usage: the project {'checkout'} is marked as silent
Future<void> theProjectIsMarkedAsSilent(WidgetTester tester, String project) async {
  await lookingAtTheProjects(tester, () async {
    // A switch whose state cannot be seen is one people turn off twice and never back on.
    expect(whatTheRowOfSays(tester, project), contains('Notifications off'));
  });
}
