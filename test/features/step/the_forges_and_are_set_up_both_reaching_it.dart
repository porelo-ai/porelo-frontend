import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the forges {'GitHub'} and {'GitHub work'} are set up, both reaching it
Future<void> theForgesAndAreSetUpBothReachingIt(WidgetTester tester, String first, String second) async {
  // Both reached by the token chosen for them, as a forge given a token is kept.
  await World.forgeEntries.write(<Map<String, Object?>>[
    <String, Object?>{
      'id': 'github.com',
      'kind': 'github',
      'name': first,
      'address': 'github.com',
      'authentication': 'token',
    },
    <String, Object?>{
      'id': 'github.com#2',
      'kind': 'github',
      'name': second,
      'address': 'github.com',
      'authentication': 'token',
    },
  ]);
  await World.forgeTokens.write('github.com', 'ghp_accepted');
}
