import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the project {'checkout'} has a conversation over {'matrix'} reaching {'127.0.0.1:8008'}, ready
Future<void> theProjectHasAConversationOverReachingReady(
  WidgetTester tester,
  String name,
  String transport,
  String reaches,
) => conversing(tester, name, transport, reaches, ready: true);

/// Gives project [name] a conversation, as the machine's `Projects` answers it.
Future<void> conversing(
  WidgetTester tester,
  String name,
  String transport,
  String reaches, {
  required bool ready,
  String detail = '',
  String waits = '',
}) async {
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
              messages: ProjectMessages(
                transport: transport,
                conversation: '!room:localhost',
                reaches: <String>[reaches],
                ready: ready,
                detail: detail,
                loopbackOnly: false,
                waits: waits,
              ),
            )
          : project,
  ];
  await World.machines.fleet.refresh(quietly: true);
  await World.settle(tester);
}
