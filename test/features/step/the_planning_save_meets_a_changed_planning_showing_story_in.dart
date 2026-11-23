import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_planning/porelo_planning.dart';

import '../support/planning.dart';
import '../support/world.dart';

/// Usage: the planning save meets a changed planning showing story {id} in {state}
///
/// The preview answers on the board the person saw; the save then finds planning changed elsewhere meanwhile, and the
/// board read again shows the story and its issues already in [state], as after a move made on another machine.
Future<void> thePlanningSaveMeetsAChangedPlanningShowingStoryIn(WidgetTester tester, String id, String state) async {
  final held = jsonDecode(jsonEncode(World.planning.board('checkout'))) as Map<String, dynamic>;
  final story = planningMaps(held, 'stories').firstWhere((story) => story['id'] == id);
  story['state'] = state;
  for (final issue in (story['issues'] as List? ?? <dynamic>[]).cast<Map<String, dynamic>>()) {
    issue['state'] = state;
  }
  held['revision'] = '${held['revision']}:elsewhere';
  World.planning
    ..heldWhenRefused = held
    ..moveFailure = PlanningRefusal('ItemChanged', {
      'changed': [id],
    }, 'A story changed since it was read.');
}
