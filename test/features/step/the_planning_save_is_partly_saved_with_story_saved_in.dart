import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_planning/porelo_planning.dart';

import '../support/planning.dart';
import '../support/world.dart';

/// Usage: the planning save is partly saved with story {id} saved in {state}
///
/// The planner's store holds what the pushed repository took before any watch tells it, as the planner answers a
/// push one repository refused: `PartlySaved`, naming those pushed and the one that failed.
Future<void> thePlanningSaveIsPartlySavedWithStorySavedIn(WidgetTester tester, String id, String state) async {
  final held = jsonDecode(jsonEncode(World.planning.board('checkout'))) as Map<String, dynamic>;
  final story = planningMaps(held, 'stories').firstWhere((story) => story['id'] == id);
  story['state'] = state;
  for (final issue in (story['issues'] as List? ?? <dynamic>[]).cast<Map<String, dynamic>>()) {
    issue['state'] = state;
  }
  held['revision'] = '${held['revision']}:partly';
  World.planning
    ..boards['checkout'] = held
    ..moveFailure = const PlanningRefusal('PartlySaved', {
      'pushed': 'porelo',
      'failed': 'porelo-host',
    }, 'The repository refused the push.');
}
