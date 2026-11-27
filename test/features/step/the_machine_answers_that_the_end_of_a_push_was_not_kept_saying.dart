import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the machine answers that the end of a push was not kept, saying {'the task record of plan is gone'}
Future<void> theMachineAnswersThatTheEndOfAPushWasNotKeptSaying(WidgetTester tester, String sentence) async {
  World.backend.endUnkept = sentence;
}
