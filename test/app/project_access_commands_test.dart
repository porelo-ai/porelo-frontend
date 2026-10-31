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

  group('accepting a new key', () {
    const newFingerprint = 'SHA256:CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC';
    late Settings settings;
    late ProjectAccessFixture fixture;
    late ProjectDevelopers developers;

    Future<void> open({bool newKey = true}) async {
      settings = Settings(MemorySettingsStore());
      fixture = ProjectAccessFixture();
      fixture.members['bob'] = AccessDeveloper(login: 'bob', role: 'developer', fingerprint: personFingerprint);
      fixture.hostPeople['demo']!['bob'] = 'active';
      if (newKey) fixture.registrySource.selectedFingerprint = newFingerprint;
      addTearDown(settings.dispose);
      addTearDown(fixture.registry.dispose);
      developers = ProjectDevelopers(project: 'demo', people: await fixture.access(settings));
      addTearDown(developers.dispose);
      await developers.load();
    }

    Command? accept() => projectPersonCommands(
      developers: developers,
      person: 'bob',
    ).where((c) => c.id == 'project.acceptKey').firstOrNull;

    Future<void> run(Command command) async {
      final finished = Completer<void>();
      void done() {
        if (!developers.busy && !finished.isCompleted) finished.complete();
      }

      developers.addListener(done);
      command.run();
      await finished.future.timeout(const Duration(seconds: 5), onTimeout: () {});
      developers.removeListener(done);
    }

    // Harm: offering a key acceptance where none waits would sign an access change nobody asked for.
    test('is offered only where the registry card carries another key than the project pins', () async {
      await open(newKey: false);
      expect(accept(), isNull);
      await open();
      expect(accept()?.label, 'Accept the new key of bob');
      expect(accept()?.unavailable, isNull);
    });

    // Harm: a replacement filed on another base or without the new card's key leaves the old key in force.
    test('files the new key on the access commit in force and delivers it', () async {
      await open();
      await run(accept()!);
      expect(developers.problem, isNull);
      final change = fixture.changes.values.single;
      expect(change.action, 'replace');
      expect(change.baseRevision, registryBefore);
      expect(change.person?.fingerprint, newFingerprint);
      expect(fixture.members['bob']?.fingerprint, newFingerprint);
      expect(fixture.hostPeople['demo'], {'bob': 'active'});
    });

    // Harm: a non-admin or an admin whose agent holds no pinned key must never sign a key into the project.
    for (final refusal in ['non-admin', 'agent without the key']) {
      test('a $refusal sends no replacement and is told who may', () async {
        await open();
        final command = accept()!;
        if (refusal == 'non-admin') {
          fixture.authorized = false;
        } else {
          fixture.signing = false;
        }
        await developers.load();
        expect(accept()?.unavailable, refusal == 'non-admin' ? contains('alice@example.org') : isNotNull);
        await run(command);
        // A callback kept from before, or a direct call, still meets the check at mutation.
        await developers.acceptKey('bob');
        expect(developers.problem, isNotNull);
        expect(fixture.calls, isEmpty);
      });
    }

    // Harm: a retry after a failed delivery that signs again files a second replacement.
    test('a failed delivery retries the same filing', () async {
      await open();
      fixture.fail = 'upload';
      await run(accept()!);
      expect(developers.problem, isNotNull);
      fixture.fail = null;
      await developers.retry();
      expect(developers.problem, isNull);
      expect(fixture.filed.length, 1);
      expect(fixture.calls.where((call) => call == 'file').length, 1);
      expect(fixture.members['bob']?.fingerprint, newFingerprint);
    });
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
