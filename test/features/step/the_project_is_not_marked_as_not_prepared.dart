import 'package:flutter_test/flutter_test.dart';

import 'the_project_is_marked_as_not_prepared.dart';

/// Usage: the project {'checkout'} is not marked as not prepared
Future<void> theProjectIsNotMarkedAsNotPrepared(WidgetTester tester, String project) async {
  expect(marksNotPrepared(tester, project), 0);
}
