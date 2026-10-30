import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/access_developers.dart';
import 'package:porelo_frontend/src/app/commands.dart';
import 'package:porelo_frontend/src/app/project_developers.dart';
import 'package:porelo_frontend/src/app/settings.dart';

import '../support/host_registry.dart';
import '../support/project_access.dart';

void main() {
  // Harm: invoking a disabled callback must not bypass the verified boundary.
  test('unscoped person command callbacks cannot mutate access', () async {
    final people = _UnscopedPeople();
    final developers = ProjectDevelopers(project: 'demo', people: people);
    addTearDown(developers.dispose);
    await developers.load();
    var adds = 0;
    final commands = projectPersonCommands(developers: developers, person: 'worker', add: () => adds++);
    commands[0].run();
    commands[1].run();
    await Future<void>.delayed(Duration.zero);
    expect(adds, 0);
    expect(people.changes, isEmpty);
  });

  // Harm: failed delivery must remain reachable through Retry even while its refusal is visible.
  test('the retry command finishes failed registration delivery', () async {
    final settings = Settings(MemorySettingsStore());
    final fixture = ProjectAccessFixture()..fail = 'upload';
    addTearDown(settings.dispose);
    addTearDown(fixture.registry.dispose);
    final access = await fixture.access(settings);
    final developers = ProjectDevelopers(project: 'demo', people: access);
    addTearDown(developers.dispose);
    await developers.load();
    await expectLater(access.register(), throwsFormatException);
    await developers.retry();
    expect(developers.problem, isNotNull);
    fixture.fail = null;
    final finished = Completer<void>();
    developers.addListener(() {
      if (!developers.busy && !finished.isCompleted) finished.complete();
    });
    projectPersonCommands(developers: developers).last.run();
    await finished.future;
    expect(settings.projectHost('demo'), 'orchard');
    expect(fixture.savedMachines.single.hostProject, 'orchard');
    expect(fixture.filed.length, 1);
  });

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

class _UnscopedPeople implements ProjectPeople {
  final person = AccessDeveloper(login: 'worker', role: 'developer', fingerprint: 'SHA256:${'A' * 43}');
  final changes = <String>[];
  @override
  Future<AccessDevelopers> read(String project) async => AccessDevelopers([person]);
  @override
  Future<void> change(String project, AccessDeveloper person, {required bool remove}) async {
    changes.add('$project/${person.login}/$remove');
  }
}
