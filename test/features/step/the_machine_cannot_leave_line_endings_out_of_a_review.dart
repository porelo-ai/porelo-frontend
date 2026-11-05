import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the machine cannot leave line endings out of a review
Future<void> theMachineCannotLeaveLineEndingsOutOfAReview(WidgetTester tester) async {
  World.backend.servesWithoutLineEndings = false;
}
