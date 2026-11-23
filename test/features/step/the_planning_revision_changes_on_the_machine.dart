import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the planning revision changes on the machine
Future<void> thePlanningRevisionChangesOnTheMachine(WidgetTester tester) async {
  // The same board at a revision the window has not read: somebody else's save, unseen.
  final board = jsonDecode(jsonEncode(World.planning.boards['checkout'])) as Map<String, dynamic>;
  board['revision'] = 'another-revision';
  World.planning.boards['checkout'] = board;
}
