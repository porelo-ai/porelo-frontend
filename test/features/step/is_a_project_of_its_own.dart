import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/forge.dart';

import '../support/world.dart';

/// Usage: {'acme/backend'} is a project of its own
///
/// It holds a project.yml of its own, as `porelo-test-1` did from an earlier test in walk 8.
Future<void> isAProjectOfItsOwn(WidgetTester tester, String repository) async {
  World.forge.projects.add(repository);
  if (!World.forge.repositoriesHere.any((each) => each.fullName == repository)) {
    World.forge.repositoriesHere = <ForgeRepository>[
      ...World.forge.repositoriesHere,
      ForgeRepository(
        fullName: repository,
        sshUrl: 'git@github.com:$repository.git',
        httpsUrl: 'https://github.com/$repository.git',
        defaultBranch: 'main',
        admin: true,
        push: true,
        private: true,
      ),
    ];
  }
}
