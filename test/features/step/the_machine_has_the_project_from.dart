import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the machine has the project {'api'} from {'git@github.com:acme/api.git'}
Future<void> theMachineHasTheProjectFrom(WidgetTester tester, String name, String url) async {
  final repository = Repository.from(<String, dynamic>{'name': name, 'own': true, 'upstream': url});
  final known = World.backend.theProjectsItHas.where((project) => project.name == name).firstOrNull;
  World.backend.theProjectsItHas = <Project>[
    for (final project in World.backend.theProjectsItHas)
      if (project.name != name) project,
    Project(
      name: name,
      securityClass: known?.securityClass ?? 'guarded',
      file: known?.file ?? '/srv/$name/project.yml',
      mirror: known?.mirror ?? '/srv/$name/.porelo/mirror',
      pending: known?.pending ?? 0,
      tasks: known?.tasks ?? 0,
      running: known?.running ?? 0,
      prepared: known?.prepared ?? false,
      preparedState: known?.preparedState ?? '',
      repositories: <String>[name],
      repositoryStates: <Repository>[repository],
    ),
  ];
  await World.machines.fleet.refresh(quietly: true);
  await World.settle(tester);
}
