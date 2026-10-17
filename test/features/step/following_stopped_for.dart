import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: following stopped for {'checkout'}
Future<void> followingStoppedFor(WidgetTester tester, String project) async {
  expect(World.backend.deletions.where((asked) => !asked.preview).map((asked) => asked.project), contains(project));
}
