import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: no first task was agreed to on any machine
Future<void> noFirstTaskWasAgreedToOnAnyMachine(WidgetTester tester) async {
  expect(World.backend.firstStartsOfConfirmed, isEmpty, reason: 'the machine forgotten was asked to write settings');
  expect(World.elsewhere.firstStartsOfConfirmed, isEmpty, reason: 'another machine was asked to write settings');
}
