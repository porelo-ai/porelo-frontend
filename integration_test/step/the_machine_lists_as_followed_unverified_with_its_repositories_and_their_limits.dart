import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/machines.dart';

import '../support/e2e.dart';

/// Usage: the machine lists {'e2e-follow'} as followed unverified, with its repositories and their limits
Future<void> theMachineListsAsFollowedUnverifiedWithItsRepositoriesAndTheirLimits(
  WidgetTester tester,
  String name,
) async {
  // Through the forward the interface raised, so this reads what the window reads.
  final client = await PoreloClient.connect(Backend(socketPath: Machine.endpointFor(E2e.name), label: E2e.name));
  final projects = await client.projects();
  final project = projects.where((each) => each.name == name).firstOrNull;
  if (project == null) {
    // Said whole, so a red run is a finding rather than a guess: what each call answers.
    final followed = await client.following();
    fail(
      'Projects() names ${projects.map((each) => each.name).toList()}; '
      'Following() answers ${followed.map((each) => '${each.name} ${each.outcome} ${each.detail}').toList()}',
    );
  }

  final following = project.following;
  expect(following, isNotNull, reason: 'a followed project carries its follow state');
  expect(following!.inForce, isTrue, reason: '${following.outcome}: ${following.detail}');
  expect(following.unverified, isTrue);
  expect(project.canBeActedOn, isTrue, reason: 'a followed project is one work can start in');
  expect(project.repositories, <String>[
    name,
    'backend',
  ], reason: 'its own first, then the one it declares - which need not exist to be followed');
  expect(project.repositoryStates.first.own, isTrue, reason: 'its own comes first');
  expect(project.repositoryStates.map((each) => each.limits), everyElement(isNotNull));
}
