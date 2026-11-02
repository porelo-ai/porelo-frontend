import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: it was removed for {'checkout'}
Future<void> itWasRemovedFor(WidgetTester tester, String project) async {
  expect(World.backend.deletions.where((asked) => !asked.preview).map((asked) => asked.project), contains(project));
}
