import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the repository {'payments-api'} limits its memory to {'4g'}
Future<void> theRepositoryLimitsItsMemoryTo(WidgetTester tester, String repository, String memory) async {
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
        following: project.following,
        repositoryStates: <Repository>[
          for (final each in project.repositoryStates)
            Repository(
              name: each.name,
              own: each.own,
              behindReason: each.behindReason,
              limits: ResolvedLimits(
                memory: each.name == repository ? memory : '',
                pids: 512,
                memoryFrom: each.name == repository ? 'repository' : 'project',
                cpusFrom: 'project',
                pidsFrom: 'project',
              ),
            ),
        ],
      ),
  ];
  await World.machines.fleet.refresh(quietly: true);
  await World.settle(tester);
}
