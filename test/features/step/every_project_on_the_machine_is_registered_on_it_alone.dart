import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: every project on the machine is registered on it alone
Future<void> everyProjectOnTheMachineIsRegisteredOnItAlone(WidgetTester tester) async {
  World.organizationAtStart = EveryProjectLocal();
}
