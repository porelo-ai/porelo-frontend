import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the project {'checkout'} has the repositories {'checkout, payments-api'}
Future<void> theProjectHasTheRepositories(WidgetTester tester, String name, String names) async {
  final repositories = names.split(',').map((each) => each.trim()).toList();
  World.backend.theProjectsItHas = <Project>[
    for (final project in World.backend.theProjectsItHas)
      project.name == name
          ? Project(
              name: project.name,
              securityClass: project.securityClass,
              file: project.file,
              mirror: project.mirror,
              pending: project.pending,
              tasks: project.tasks,
              running: project.running,
              prepared: project.prepared,
              preparedState: project.preparedState,
              repositories: repositories,
              repositoryStates: <Repository>[
                for (final each in repositories)
                  Repository(name: each, own: each == repositories.first, behindReason: 'NEVER_CHECKED'),
              ],
            )
          : project,
  ];
  await World.machines.fleet.refresh(quietly: true);
  await World.settle(tester);
}
