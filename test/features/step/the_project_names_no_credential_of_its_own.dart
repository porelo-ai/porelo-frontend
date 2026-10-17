import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the project {'checkout'} names no credential of its own
Future<void> theProjectNamesNoCredentialOfItsOwn(WidgetTester tester, String name) =>
    naming(tester, name, const <String, String>{});

/// Makes [name] a project whose machine says which credentials it names: [credentials].
Future<void> naming(WidgetTester tester, String name, Map<String, String> credentials) async {
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
              following: project.following,
              followingAnswered: project.followingAnswered,
              credentials: credentials,
              credentialsAnswered: true,
            )
          : project,
  ];
  await World.machines.fleet.refresh(quietly: true);
  await World.settle(tester);
}
