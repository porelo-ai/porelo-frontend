import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the machine was last asked whether it can start with {'a-provider'} for {'weather'}
Future<void> theMachineWasLastAskedWhetherItCanStartWithFor(
  WidgetTester tester,
  String entry,
  String destination,
) async {
  expect(World.backend.askedAboutCredentials.last, <String, String>{entry: destination});
}
