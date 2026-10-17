import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the machine no longer has the project {'billing'}
///
/// Deleted, cleared or no longer followed: the machine lists it no more, and its work went with it.
Future<void> theMachineNoLongerHasTheProject(WidgetTester tester, String project) async {
  World.backend.theProjectsItHas = <Project>[
    for (final each in World.backend.theProjectsItHas)
      if (each.name != project) each,
  ];
  World.backend.publish(<Task>[
    for (final task in World.backend.tasksNow)
      if (task.project != project) task,
  ]);
  await World.machines.fleet.refresh(quietly: true);
  await World.settle(tester);
}
