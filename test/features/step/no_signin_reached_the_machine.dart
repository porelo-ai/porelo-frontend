import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: no sign-in reached the machine {'elsewhere'}
Future<void> noSigninReachedTheMachine(WidgetTester tester, String name) async {
  expect(name, 'elsewhere');
  expect(World.elsewhere.signInsAsked, 0, reason: 'nothing may be asked of the machine chosen meanwhile');
  expect(World.elsewhere.signInStarts, isEmpty, reason: 'no sign-in may start there');
  expect(World.elsewhere.signInWaits, isEmpty, reason: 'no sign-in there may be waited on');
  expect(World.backend.signInStarts, isNotEmpty, reason: 'the sign-in must reach the machine of the form');
}
