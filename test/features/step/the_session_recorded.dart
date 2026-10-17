import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the session recorded {'Start Porelo on user@build.example.test'}
///
/// What ran on a machine belongs in the record, where somebody coming back an hour later finds
/// it — a start that only happened is a start nobody can account for.
Future<void> theSessionRecorded(WidgetTester tester, String title) async {
  expect(
    World.operations.all.map((each) => each.title),
    contains(title),
    reason: 'the session record has nothing about it',
  );
}
