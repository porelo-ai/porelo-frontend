import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: {'porelo-checkout-shell'} was started again
///
/// By what went down the socket: the name within the project and its file, never the container.
Future<void> wasStartedAgain(WidgetTester tester, String work) async {
  final task = World.backend.tasksNow.firstWhere((each) => each.name == work);
  expect(World.backend.startedAgain, hasLength(1));
  expect(World.backend.startedAgain.single.task, task.task);
  expect(World.backend.startedAgain.single.project, isNotEmpty);
}
