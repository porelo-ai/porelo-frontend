import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the project {'checkout'} is followed from {'git@example.org:checkout.git'}
Future<void> theProjectIsFollowedFrom(WidgetTester tester, String name, String url) async {
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
              repositories: project.repositories,
              repositoryStates: project.repositoryStates,
              following: Followed(name: name, url: url, commit: 'c0ffee1d2e3f', outcome: 'UNCHANGED'),
              followingAnswered: true,
            )
          : project,
  ];
  await World.machines.fleet.refresh(quietly: true);
  await World.settle(tester);
}
