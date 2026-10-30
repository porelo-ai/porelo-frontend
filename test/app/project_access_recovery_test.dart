import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/access_developers.dart';
import 'package:porelo_frontend/src/app/project_access.dart';
import 'package:porelo_frontend/src/app/project_developers.dart';
import 'package:porelo_frontend/src/app/registry.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_host/porelo_host.dart';

import '../support/host_registry.dart';
import '../support/project_access.dart';

void main() {
  late Settings settings;
  late ProjectAccessFixture fixture;
  final bob = AccessDeveloper(login: 'bob', role: 'developer', fingerprint: personFingerprint);
  setUp(() {
    settings = Settings(MemorySettingsStore());
    fixture = ProjectAccessFixture();
  });
  tearDown(() {
    settings.dispose();
    fixture.registry.dispose();
  });

  // Harm: unlocking must never restore access for an unapproved key.
  for (final refused in [true, false]) {
    test('unlock refuses ${refused ? 'a refused card' : 'an ineligible key'} before signing', () async {
      final access = await fixture.access(settings);
      await access.change('demo', bob, remove: false);
      await access.lock('bob', locked: true);
      fixture.calls.clear();
      if (refused) {
        fixture.registrySource.refusedPerson = true;
        await fixture.registry.refresh();
      } else {
        fixture.eligible = false;
      }
      await expectLater(access.lock('bob', locked: false), throwsA(isA<RegistryRefusal>()));
      expect(fixture.calls, isEmpty);
      expect(fixture.hostPeople['demo'], {'bob': 'locked'});
    });
  }

  // Harm: a different project's members and key-replacement verdict must not leak into this picker.
  test('a wrong-project refresh clears admission and candidates', () async {
    final access = await fixture.access(settings);
    await access.read('demo');
    fixture.verifiedProject = 'other';
    await expectLater(access.read('demo'), throwsA(isA<RegistryRefusal>()));
    expect(access.candidates, isEmpty);
    expect(access.admission, isNull);
    expect(access.unavailable(), isNotNull);
  });

  // Harm: an unaccepted registry refresh must not keep a grant selectable.
  test('a refused registry refresh invalidates candidates and admission', () async {
    final access = await fixture.access(settings);
    await access.read('demo');
    fixture.registrySource.fail = 'read';
    await fixture.registry.refresh();
    expect(fixture.registry.problem, isNotNull);
    expect(access.candidates, isEmpty);
    expect(access.admission, isNull);
  });

  // Harm: stale unsigned requests must not permanently prevent all subsequent changes.
  test('an obsolete unfiled request can be replaced after restart', () async {
    final store = MemorySettingsStore();
    final first = Settings(store);
    addTearDown(first.dispose);
    final access = await fixture.access(first);
    fixture.fail = 'file';
    await expectLater(access.change('demo', bob, remove: false), throwsFormatException);
    final restored = Settings(store);
    addTearDown(restored.dispose);
    await restored.load();
    final resumed = await fixture.access(restored);
    fixture.fail = null;
    fixture.currentAccess = 'c' * 40;
    await resumed.change('demo', bob, remove: false);
    expect(fixture.filed.length, 1);
    expect(fixture.hostPeople['demo'], {'bob': 'active'});
  });

  // Harm: replacing an obsolete selection must never discard signed work.
  test('signed progress cannot be forgotten by the unsigned cleanup', () async {
    final access = await fixture.access(settings);
    fixture.fail = 'upload';
    await expectLater(access.register(), throwsFormatException);
    final revision = settings.projectAccess('demo')!.revision;
    await expectLater(settings.forgetUnfiledProjectAccess('demo'), throwsStateError);
    fixture.fail = null;
    await access.retry();
    expect(fixture.filed.length, 1);
    expect(settings.projectAccess('demo')!.revision, revision);
    expect(settings.projectHost('demo'), 'orchard');
  });

  // Harm: a refused-key unsigned request must not wedge a newly authorized replacement.
  test('retry forgets an unsigned request after its candidate becomes ineligible', () async {
    final access = await fixture.access(settings);
    fixture.fail = 'file';
    await expectLater(access.change('demo', bob, remove: false), throwsFormatException);
    fixture.eligible = false;
    await expectLater(access.retry(), throwsA(isA<RegistryRefusal>()));
    expect(settings.projectAccess('demo'), isNull);
    fixture.fail = null;
    await access.register();
    expect(fixture.changes.values.single.action, 'register');
  });

  // Harm: a stale displayed membership must not silently target a newer role or lock.
  for (final action in ['remove', 'lock']) {
    test('$action refuses a membership changed since display', () async {
      fixture.members['bob'] = bob;
      final access = await fixture.access(settings);
      final developers = ProjectDevelopers(project: 'demo', people: access);
      addTearDown(developers.dispose);
      await developers.load();
      fixture.members['bob'] = AccessDeveloper(login: 'bob', role: 'admin', fingerprint: personFingerprint);
      if (action == 'remove') {
        await developers.remove('bob');
      } else {
        await developers.lock('bob', locked: true);
      }
      expect(fixture.calls, isEmpty);
      expect(developers.problem, isNotNull);
    });
  }

  // Harm: a stale toggle must not sign a redundant change.
  test('locking an already locked member does not publish again', () async {
    final access = await fixture.access(settings);
    await access.change('demo', bob, remove: false);
    await access.lock('bob', locked: true);
    fixture.calls.clear();
    await expectLater(access.lock('bob', locked: true), throwsA(isA<RegistryRefusal>()));
    expect(fixture.calls, isEmpty);
  });

  // Harm: a host pin checked by the dialog must still hold at the signing boundary.
  for (final stage in ['connect', 'register']) {
    test('registration pins the entire card at $stage', () async {
      final access = await fixture.access(settings);
      final registration = RegistryProjectRegistration(access);
      final state = await registration.verify('demo', registering: true);
      final machine = await fixture.connect(await access.verify());
      fixture.calls.clear();
      fixture.host = PreparedHost.read({...sshCompletion(), 'address': '203.0.113.9'});
      await expectLater(
        stage == 'connect' ? registration.connect(state) : registration.register(state, machine),
        throwsA(isA<RegistryRefusal>()),
      );
      expect(fixture.calls, isEmpty);
    });
  }

  // Harm: failed local recording after confirmed host delivery must remain retryable without a second commit.
  for (final failure in ['machine', 'association']) {
    test('registration recovers $failure persistence failure after restart', () async {
      final store = _AssociationStore();
      final first = Settings(store);
      addTearDown(first.dispose);
      fixture.failRememberMachine = failure == 'machine';
      store.failAssociation = failure == 'association';
      final access = await fixture.access(first);
      await expectLater(access.register(), throwsA(isA<Exception>()));
      expect(first.projectAccess('demo')!.confirmed, isFalse);
      final restored = Settings(store);
      addTearDown(restored.dispose);
      await restored.load();
      fixture.failRememberMachine = false;
      store.failAssociation = false;
      final resumed = await fixture.access(restored);
      await resumed.retry();
      expect(restored.projectHost('demo'), 'orchard');
      expect(fixture.savedMachines.last.hostProject, 'orchard');
      await resumed.register();
      expect(fixture.filed.length, 1);
    });
  }

  // Harm: a later person edit must not erase proof of registration and permit a duplicate bring.
  test('confirmed registration survives later access edits and restart', () async {
    final store = MemorySettingsStore();
    final first = Settings(store);
    addTearDown(first.dispose);
    final access = await fixture.access(first);
    await access.register();
    await access.change('demo', bob, remove: false);
    final restored = Settings(store);
    addTearDown(restored.dispose);
    await restored.load();
    final resumed = await fixture.access(restored);
    await resumed.register();
    expect(fixture.filed.length, 2);
    expect(fixture.changes.values.where((change) => change.action == 'register'), hasLength(1));
  });

  // Harm: the final read must not substitute another project revision after the dialog verified it.
  test('registration refuses a revision changed at its final authorization read', () async {
    final access = await fixture.access(settings);
    final registration = RegistryProjectRegistration(access);
    final state = await registration.verify('demo', registering: true);
    final machine = await fixture.connect(await access.verify());
    fixture.calls.clear();
    var reads = 0;
    fixture.onRead = () {
      if (++reads == 2) fixture.verifiedRevision = 'c' * 40;
    };
    await expectLater(registration.register(state, machine), throwsA(isA<RegistryRefusal>()));
    expect(fixture.calls, isEmpty);
  });

  // Harm: a failed refresh must disable cached admission and picker grants.
  test('a failed Core refresh clears previously available admission', () async {
    final access = await fixture.access(settings);
    await access.read('demo');
    fixture.readFailure = const RegistryRefusal('The project read was refused.');
    await expectLater(access.read('demo'), throwsA(isA<RegistryRefusal>()));
    expect(access.candidates, isEmpty);
    expect(access.admission, isNull);
  });

  // Harm: a refused key must not regain access by retrying an already signed unlock.
  test('an unlock retry rechecks key eligibility before delivery', () async {
    final access = await fixture.access(settings);
    await access.change('demo', bob, remove: false);
    await access.lock('bob', locked: true);
    fixture.fail = 'upload';
    await expectLater(access.lock('bob', locked: false), throwsFormatException);
    fixture.fail = null;
    fixture.eligible = false;
    fixture.calls.clear();
    await expectLater(access.retry(), throwsA(isA<RegistryRefusal>()));
    expect(fixture.calls, isEmpty);
    expect(fixture.hostPeople['demo'], {'bob': 'locked'});
  });

  // Harm: concurrent controls must update availability and preserve the explicit refusal.
  test('project mutation lock notifies listeners on acquisition and release', () async {
    final observed = <bool>[];
    settings.addListener(() => observed.add(settings.projectChangeRunning('demo')));
    final release = Completer<void>();
    final running = settings.withProjectChange('demo', () => release.future);
    await expectLater(settings.withProjectChange('demo', () async {}), throwsA(isA<RegistryRefusal>()));
    release.complete();
    await running;
    expect(observed, [true, false]);
  });
}

class _AssociationStore extends MemorySettingsStore {
  bool failAssociation = false;
  @override
  Future<void> write(Map<String, Object?> values) async {
    if (failAssociation && values['projectHosts'] is Map && (values['projectHosts'] as Map).isNotEmpty) {
      throw const FormatException('association persistence failed');
    }
    await super.write(values);
  }
}
