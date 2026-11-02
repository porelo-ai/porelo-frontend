import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the project {'checkout'} is left over, with no file
Future<void> theProjectIsLeftOverWithNoFile(WidgetTester tester, String name) async {
  World.backend.theProjectsItHas = <Project>[
    for (final project in World.backend.theProjectsItHas)
      project.name != name
          ? project
          : Project(
              name: project.name,
              securityClass: project.securityClass,
              file: '',
              mirror: project.mirror,
              pending: project.pending,
              tasks: project.tasks,
              running: project.running,
              prepared: project.prepared,
              preparedState: project.preparedState,
            ),
  ];
  await World.machines.fleet.refresh(quietly: true);
  await World.settle(tester);
}
