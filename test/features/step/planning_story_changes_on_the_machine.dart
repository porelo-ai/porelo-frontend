import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';
import '../support/world.dart';

/// Usage: planning story {id} changes on the machine
///
/// Another window renames the story, so the planner holds it at a version other than the one the board shows.
Future<void> planningStoryChangesOnTheMachine(WidgetTester tester, String id) async {
  final board = jsonDecode(jsonEncode(World.planning.boards['checkout'])) as Map<String, dynamic>;
  final story = planningMaps(board, 'stories').firstWhere((story) => story['id'] == id);
  story['title'] = '${story['title']} (renamed elsewhere)';
  World.planning.boards['checkout'] = board;
}
