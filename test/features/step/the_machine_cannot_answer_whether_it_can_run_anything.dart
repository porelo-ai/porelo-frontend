import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the machine cannot answer whether it can run anything
Future<void> theMachineCannotAnswerWhetherItCanRunAnything(WidgetTester tester) async {
  World.backend.doctorIsUnsupported = true;
}
