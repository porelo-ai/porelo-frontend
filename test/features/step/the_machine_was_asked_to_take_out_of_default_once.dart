import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the machine was asked to take {'foo-2'} out of default once
Future<void> theMachineWasAskedToTakeOutOfDefaultOnce(WidgetTester tester, String name) async {
  expect(World.backend.leftDefault.where((each) => each == name), hasLength(1));
}
