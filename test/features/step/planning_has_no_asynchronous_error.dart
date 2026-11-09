import 'package:flutter_test/flutter_test.dart';

/// Usage: planning has no asynchronous error
Future<void> planningHasNoAsynchronousError(WidgetTester tester) async {
  expect(tester.takeException(), isNull);
}
