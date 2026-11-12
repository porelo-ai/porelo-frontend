import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the machine answers what nobody expected
Future<void> theMachineAnswersWhatNobodyExpected(WidgetTester tester) async {
  World.backend.readsFail = StateError('an answer nobody expected');
}
