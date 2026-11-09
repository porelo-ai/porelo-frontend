import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: no sign-in was forced
Future<void> noSigninWasForced(WidgetTester tester) async {
  expect(World.backend.signInStarts.where((each) => each.force == true), isEmpty);
}
