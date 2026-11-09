import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the last sign-in was forced
Future<void> theLastSigninWasForced(WidgetTester tester) async {
  expect(World.backend.signInStarts, isNotEmpty);
  expect(World.backend.signInStarts.last.force, isTrue);
}
