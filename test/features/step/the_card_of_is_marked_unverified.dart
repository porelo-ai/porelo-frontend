import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';

/// Usage: the card of {'checkout'} is marked unverified
Future<void> theCardOfIsMarkedUnverified(WidgetTester tester, String project) async {
  await lookingAtTheProjects(tester, () async {
    expect(whatTheRowOfSays(tester, project), contains('Followed unverified'));
  });
}
