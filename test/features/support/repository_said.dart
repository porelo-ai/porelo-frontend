import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import 'world.dart';

/// What the machine says of one repository of every project naming it, from now on: its carry, its state at central
/// with how far ahead and when, and its count of work, each left unsaid unless given, as an older Porelo leaves them.
Future<void> theMachineSaysOfTheRepository(
  WidgetTester tester,
  String repository, {
  bool? carriedHere,
  String? central,
  int? ahead,
  String? aheadMeasured,
  int? tasks,
  int? running,
}) async {
  Repository said(Repository each) => Repository(
    name: each.name,
    own: each.own,
    upstream: each.upstream,
    mirror: each.mirror,
    pending: each.pending,
    behind: each.behind,
    behindMeasured: each.behindMeasured,
    behindReason: each.behindReason,
    behindDetail: each.behindDetail,
    limits: each.limits,
    agent: each.agent,
    nickname: each.nickname,
    goesBy: each.goesBy,
    carriedHere: carriedHere ?? each.carriedHere,
    central: central ?? each.central,
    centralWhy: each.centralWhy,
    ahead: ahead ?? each.ahead,
    aheadMeasured: aheadMeasured ?? each.aheadMeasured,
    tasks: tasks ?? each.tasks,
    running: running ?? each.running,
  );
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
        carried: project.carried,
        repositoryStates: <Repository>[
          for (final each in project.repositoryStates) each.name == repository ? said(each) : each,
        ],
      ),
  ];
  await World.machines.fleet.refresh(quietly: true);
  await World.settle(tester);
}
