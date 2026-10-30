import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/access_developers.dart';
import 'package:porelo_frontend/src/app/commands.dart';
import 'package:porelo_frontend/src/app/project_developers.dart';
import 'package:porelo_frontend/src/app/settings.dart';

import '../support/host_registry.dart';
import '../support/project_access.dart';

void main() {
  // Harm: a pointer callback retained before authority is lost must not grant access later.
  test('stale person commands recheck authority at mutation and name the permitted admin', () async {
    final settings = Settings(MemorySettingsStore());
    final fixture = ProjectAccessFixture();
    addTearDown(settings.dispose);
    addTearDown(fixture.registry.dispose);
    final access = await fixture.access(settings);
    final developers = ProjectDevelopers(project: 'demo', people: access);
    addTearDown(developers.dispose);
    await developers.load();
    Future<void>? request;
    final commands = projectPersonCommands(
      developers: developers,
      add: () {
        request = developers.addDeveloper(
          AccessDeveloper(login: 'bob', role: 'developer', fingerprint: personFingerprint),
        );
      },
    );
    expect(commands.map((command) => command.id), [
      'project.addDeveloper',
      'project.removePerson',
      'project.lockPerson',
      'project.retryAccess',
    ]);
    expect(commands.every((command) => command.home == Home.projectMenu), isTrue);
    final callback = commands.first.run;
    expect(commands.first.unavailable, isNull);
    fixture.authorized = false;
    callback();
    await request;
    expect(fixture.calls, isEmpty);
    expect(developers.problem, contains('alice@example.org'));
    expect(projectPersonCommands(developers: developers).every((command) => command.unavailable != null), isTrue);
  });
}
