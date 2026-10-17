import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: {'acme/api'} holds the project {'api'} with the work repository {'backend'} at {'git@github.com:acme/backend.git'}
Future<void> holdsTheProjectWithTheWorkRepositoryAt(
  WidgetTester tester,
  String repository,
  String project,
  String work,
  String upstream,
) async {
  World.forge.projects.add(repository);
  World.workspace.onTheForge =
      'project:\n  name: "$project"\n  security_class: "guarded"\n'
      'repositories:\n  $work:\n    upstream: "$upstream"\n';
  // What the machine reads from the project once it follows it.
  World.backend.workUpstreams[work] = upstream;
}
