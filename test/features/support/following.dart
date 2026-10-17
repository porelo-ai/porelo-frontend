import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import 'world.dart';

/// Gives [name] the follow state [followed], as `Projects()` would answer it, and lets it arrive.
Future<void> theProjectFollows(WidgetTester tester, String name, Followed followed) async {
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
              behind: project.behind,
              behindMeasured: project.behindMeasured,
              behindReason: project.behindReason,
              behindDetail: project.behindDetail,
              repositories: project.repositories,
              repositoryStates: project.repositoryStates,
              following: followed,
            ),
  ];
  await World.machines.fleet.refresh(quietly: true);
  await World.settle(tester);
}
