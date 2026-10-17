import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: nothing has been taken back yet
///
/// Read off the socket: what makes a preview a preview is that the call carried `dryRun`.
Future<void> nothingHasBeenTakenBackYet(WidgetTester tester) async {
  expect(World.backend.narrowings, isNotEmpty, reason: 'nothing was asked at all');
  expect(
    World.backend.narrowings.every((asked) => asked.preview),
    isTrue,
    reason: 'a name was taken back before anybody agreed to it',
  );
}
