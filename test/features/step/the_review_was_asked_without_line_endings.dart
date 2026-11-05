import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the review was asked without line endings
Future<void> theReviewWasAskedWithoutLineEndings(WidgetTester tester) async {
  expect(World.backend.reviewedWithoutLineEndings.last, isTrue);
}
