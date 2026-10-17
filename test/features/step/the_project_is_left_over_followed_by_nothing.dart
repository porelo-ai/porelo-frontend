import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the project {'checkout'} is left over, followed by nothing
Future<void> theProjectIsLeftOverFollowedByNothing(WidgetTester tester, String name) async {
  // As a Porelo that knows following lists it: the old registry's file, and an empty follow state.
  World.backend.theProjectsItHas = <Project>[
    for (final project in World.backend.theProjectsItHas)
      project.name != name
          ? project
          : Project(
              name: project.name,
              securityClass: project.securityClass,
              file: project.file,
              mirror: project.mirror,
              pending: project.pending,
              tasks: project.tasks,
              running: project.running,
              prepared: project.prepared,
              preparedState: project.preparedState,
              followingAnswered: true,
            ),
  ];
  await World.machines.fleet.refresh(quietly: true);
  await World.settle(tester);
}
