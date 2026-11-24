import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_planning/porelo_planning.dart';

import '../support/planning.dart';
import '../support/world.dart';

/// Usage: the planning save is partly saved with story {id} saved in {state}
///
/// Once the save is refused, the planner's store holds what the pushed repository took before any watch tells it, as
/// the planner answers a push one repository refused: `PartlySaved`, naming those pushed, the one that failed and the
/// issues it moved.
Future<void> thePlanningSaveIsPartlySavedWithStorySavedIn(WidgetTester tester, String id, String state) async {
  final held = jsonDecode(jsonEncode(World.planning.board('checkout'))) as Map<String, dynamic>;
  final story = planningMaps(held, 'stories').firstWhere((story) => story['id'] == id);
  story['state'] = state;
  for (final issue in (story['issues'] as List? ?? <dynamic>[]).cast<Map<String, dynamic>>()) {
    issue['state'] = state;
  }
  held['revision'] = '${held['revision']}:partly';
  // Held only once the save is refused: the preview and the digest the save sends are of the board the person saw.
  World.planning
    ..heldWhenRefused = held
    ..moveFailure = const PlanningRefusal('PartlySaved', {
      'pushed': 'porelo',
      'failed': 'porelo-host',
      // The issues the pushed repository moved, `id=state` comma-joined; one without a state is named alone.
      'issues': 'B540=Backlog,B541', // not-a-citation: the planning stand-in's own issue ids
    }, 'The repository refused the push.');
}
