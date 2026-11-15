import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/planning_details.dart';
import '../support/world.dart';

/// Usage: the window started task {name} of ST291 on the other machine
Future<void> theWindowStartedTaskOfSt291OnTheOtherMachine(WidgetTester tester, String name) async {
  // The planner names the task as the project does; the machine names it by the container Start made.
  final container = 'porelo-checkout_$name';
  mockStory('ST291')['work'] = {
    'tasks': [
      {
        'task': name,
        'containerId': container,
        'repository': 'porelo',
        'issues': ['B540', 'B541'],
        'state': 'In analysis',
        'done': 'Analyzed',
        'mode': 'UNATTENDED',
        'agent': 'Agent',
        'model': 'Model',
        'role': 'MAIN',
        'since': 'instant',
        'atWork': false,
        'ended': null,
      },
    ],
    'coordinator': null,
    'since': 'instant',
    'atWork': false,
    'repositories': <Map<String, dynamic>>[],
    'comment': '',
    'readingRounds': 2,
    'issueReadingRounds': <Map<String, dynamic>>[],
    'issues': <Map<String, dynamic>>[],
  };
  World.elsewhere.bringsUp(Task.from({'name': container, 'task': name, 'project': 'checkout', 'running': false}));
  await World.settings.rememberPlanningOffer(
    machine: 'elsewhere',
    container: container,
    offer: '00000000-0000-4000-8000-000000000603',
    provider: World.machines.current.name,
    project: 'checkout',
    story: 'ST291',
    task: name,
    role: 'MAIN',
    issues: const ['B541'],
  );
  // Its start was told long ago: nothing is reported again.
  await World.settings.planningOfferReported('elsewhere', container, started: true);
  await World.settle(tester);
}
