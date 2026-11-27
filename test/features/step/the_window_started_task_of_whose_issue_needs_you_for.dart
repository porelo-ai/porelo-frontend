import '../../support/planned_orders.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/planning.dart';
import '../support/world.dart';

/// Usage: the window started task {name} of {story} whose issue needs you for {'SAVE_REFUSED'}
Future<void> theWindowStartedTaskOfWhoseIssueNeedsYouFor(
  WidgetTester tester,
  String name,
  String story,
  String reason,
) async {
  // The planner names the task as the project does, at work; this machine names it by the container Start made.
  final container = 'porelo-checkout_$name';
  final board = planningFixture();
  final reported = planningMaps(board, 'stories').singleWhere((each) => each['id'] == story);
  final issue = (reported['issues'] as List<dynamic>).first as Map<String, dynamic>;
  issue['needsYou'] = true;
  reported['work'] = <String, dynamic>{
    'run': '00000000-0000-4000-9000-0000000000ab',
    'atWork': true,
    'tasks': [
      {
        'task': name,
        'containerId': container,
        'repository': 'porelo',
        'issues': [issue['id']],
        'state': 'In analysis',
        'done': 'Analyzed',
        'mode': 'UNATTENDED',
        'agent': 'Agent',
        'model': 'Model',
        'role': authorRole,
        'readLanded': <String>[],
        'since': 'instant',
        'atWork': true,
        'ended': null,
      },
    ],
    'issues': [
      {'issue': issue['id'], 'reason': reason, 'needsYou': true, 'rounds': 0, 'roundsMost': 2},
    ],
  };
  World.backend.bringsUp(Task.from({'name': container, 'task': name, 'project': 'checkout', 'running': true}));
  await World.settings.rememberPlanningOffer(
    machine: World.machines.current.name,
    container: container,
    offer: '00000000-0000-4000-8000-000000000609',
    provider: World.machines.current.name,
    project: 'checkout',
    story: story,
    task: name,
    role: 'MAIN',
    issues: [issue['id'] as String],
  );
  // Its start was told long ago: nothing is reported again.
  await World.settings.planningOfferReported(World.machines.current.name, container, started: true);
  await pushPlanning(tester, board);
}
