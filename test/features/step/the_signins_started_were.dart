import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the sign-ins started were {'an-agent, other-agent'}
Future<void> theSigninsStartedWere(WidgetTester tester, String agents) async {
  expect(
    World.backend.signInStarts.map((each) => each.agent).toList(),
    agents.split(',').map((each) => each.trim()).toList(),
  );
}
