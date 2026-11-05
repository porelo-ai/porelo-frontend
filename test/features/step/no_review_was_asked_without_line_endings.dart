import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: no review was asked without line endings
Future<void> noReviewWasAskedWithoutLineEndings(WidgetTester tester) async {
  expect(World.backend.reviewedWithoutLineEndings, everyElement(isNull));
}
