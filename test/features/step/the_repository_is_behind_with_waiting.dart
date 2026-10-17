import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the repository {'payments-api'} is {'4'} behind with {'2'} waiting
Future<void> theRepositoryIsBehindWithWaiting(
    WidgetTester tester, String repository, String behind, String waiting) async {
  World.backend.theProjectsItHas = <Project>[
    for (final project in World.backend.theProjectsItHas)
      Project(
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
        repositories: project.repositories,
        repositoryStates: <Repository>[
          for (final each in project.repositoryStates)
            each.name != repository
                ? each
                : Repository(
                    name: each.name,
                    own: each.own,
                    pending: int.parse(waiting),
                    behind: int.parse(behind),
                    behindReason: 'MEASURED',
                  ),
        ],
      ),
  ];
  await World.machines.fleet.refresh(quietly: true);
  await World.settle(tester);
}
