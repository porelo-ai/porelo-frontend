import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/access_developers.dart';
import 'package:porelo_frontend/src/app/commands.dart';
import 'package:porelo_frontend/src/app/host_access.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/project_access.dart';
import 'package:porelo_frontend/src/app/project_access_contract.dart';
import 'package:porelo_frontend/src/app/project_developers.dart';
import 'package:porelo_frontend/src/app/registry.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/app/signed_host_actions.dart';
import 'package:porelo_host/porelo_host.dart';

import '../support/host_registry.dart';
import '../support/project_access.dart';

void main() {
  late Settings settings;
  late _FilingFixture fixture;
  final bob = AccessDeveloper(login: 'bob', role: 'developer', fingerprint: personFingerprint);
  setUp(() {
    settings = Settings(MemorySettingsStore());
    fixture = _FilingFixture();
  });
  tearDown(() {
    settings.dispose();
    fixture.registry.dispose();
  });

  // Harm: post-filing failures must not throw away the only deliverable signed change.
  for (final stage in ['delivery', 'publication lookup', 'publish', 'upload', 'apply']) {
    test('arbitrary $stage refusal retains the exact filed receipt for Retry', () async {
      final access = await fixture.access(settings);
      fixture.refusalStage = stage;
      fixture.refusal = const RegistryRefusal('An unfamiliar refusal that can recover.');
      await expectLater(access.register(), throwsA(isA<RegistryRefusal>()));
      final receipt = settings.projectAccess('demo')!;
      expect(receipt.state, ProjectAccessState.filed);
      expect(access.supersededChangeId, isNull);
      expect(access.unavailable(delivery: true), isNull);
      fixture.refusalStage = null;
      await access.retry();
      expect(settings.projectAccess('demo')!.change.id, receipt.change.id);
      expect(settings.projectAccess('demo')!.confirmed, isTrue);
      expect(fixture.filed, hasLength(1));
    });
  }

  // Harm: a delivered change whose server was given back stays as a Retry that can never succeed.
  test('a delivered registration whose server was given back is forgotten and ends', () async {
    final base = await fixture.access(settings);
    var refuse = true;
    final access = ProjectAccess(
      project: base.project,
      registry: base.registry,
      settings: settings,
      core: fixture,
      transport: fixture,
      rememberMachine: (machine) async {
        if (refuse) throw const RegistryRefusal('Local recording is temporarily unavailable.');
        fixture.savedMachines.add(machine);
      },
    );
    await expectLater(access.register(), throwsA(isA<RegistryRefusal>()));
    final receipt = settings.projectAccess('demo')!;
    expect(receipt.state, ProjectAccessState.delivered);
    await settings.rememberHostReturned('orchard');
    fixture.calls.clear();
    await access.retry();
    expect(settings.projectAccess('demo'), isNull);
    expect(access.pending, isFalse);
    expect(access.supersededChangeId, isNull);
    expect(fixture.calls, isEmpty);
    refuse = false;
  });

  // Harm: a stale signed-action callback must resolve uncertain signing before checking its view.
  for (final entry in ['verify', 'connect']) {
    test('registration $entry resolves an unfiled ID before a stale view refusal', () async {
      final access = await fixture.access(settings);
      final registration = RegistryProjectRegistration(access);
      final state = await registration.verify('demo', registering: true);
      fixture.fail = 'file';
      await expectLater(access.register(), throwsFormatException);
      final id = settings.projectAccess('demo')!.change.id;
      fixture.fail = null;
      fixture.authorized = false;
      fixture.lookups.clear();
      await expectLater(
        entry == 'verify' ? registration.verify('demo', registering: true) : registration.connect(state),
        throwsA(isA<RegistryRefusal>()),
      );
      expect(fixture.lookups, [id]);
      expect(settings.projectAccess('demo'), isNull);
    });
  }

  // Harm: current admin loss must not strand registration authorized at its filed revision.
  test('signed registration verifies connects and resumes after active signer loss', () async {
    final access = await fixture.access(settings);
    fixture.fail = 'upload';
    await expectLater(access.register(), throwsFormatException);
    final receipt = settings.projectAccess('demo')!;
    fixture.fail = null;
    fixture.authorized = false;
    fixture.signers = [];
    final registration = RegistryProjectRegistration(access);
    final state = await registration.verify('demo', registering: true);
    state.check('demo');
    final machine = await registration.connect(state);
    await registration.register(state, machine);
    expect(settings.projectAccess('demo')!.change.id, receipt.change.id);
    expect(settings.projectAccess('demo')!.confirmed, isTrue);
    expect(fixture.filed, hasLength(1));
  });

  // Harm: a verdict for another filing must not destroy this receipt.
  for (final outcome in ['refused', 'overtaken']) {
    for (final pin in ['exact', 'wrong id', 'wrong revision']) {
      test('typed $outcome with $pin selects only the judged receipt', () async {
        final access = await fixture.access(settings);
        fixture.fail = 'upload';
        await expectLater(access.register(), throwsFormatException);
        final receipt = settings.projectAccess('demo')!;
        fixture.fail = null;
        final id = pin == 'wrong id' ? 'f' * 32 : receipt.change.id;
        final revision = pin == 'wrong revision' ? 'f' * 40 : receipt.revision!;
        fixture.deliveryVerdict = outcome == 'refused'
            ? ProjectAccessRevisionRefused(id, revision)
            : ProjectAccessRevisionOvertaken(id, revision);
        fixture.calls.clear();
        await expectLater(access.retry(), throwsA(isA<RegistryRefusal>()));
        expect(
          settings.projectAccess('demo')!.state,
          pin == 'exact' ? ProjectAccessState.superseded : ProjectAccessState.filed,
        );
        expect(fixture.calls, isEmpty);
        if (pin == 'exact') {
          expect(settings.projectAccessReason('demo'), isNotEmpty);
          await access.discard(receipt.change.id);
          expect(settings.projectAccess('demo'), isNull);
        } else {
          fixture.deliveryVerdict = null;
          await access.retry();
          expect(settings.projectAccess('demo')!.confirmed, isTrue);
        }
      });
    }
  }

  // Harm: a later verified head can contain the filed revision and must not lose its delivery.
  test('a later head containing the filed revision remains deliverable', () async {
    final access = await fixture.access(settings);
    fixture.fail = 'upload';
    await expectLater(access.register(), throwsFormatException);
    final receipt = settings.projectAccess('demo')!;
    fixture.fail = null;
    fixture.currentAccess = 'c' * 40;
    await access.retry();
    expect(settings.projectAccess('demo')!.confirmed, isTrue);
    expect(settings.projectAccess('demo')!.change.id, receipt.change.id);
    expect(fixture.filed, hasLength(1));
  });

  // Harm: a signing failure must retain the request ID until explicit recovery.
  test('a signing failure retains the receipt with Retry', () async {
    final access = await fixture.access(settings);
    fixture.fail = 'file';
    await expectLater(access.change('demo', bob, remove: false), throwsFormatException);
    expect(settings.projectAccess('demo'), isNotNull, reason: 'the unresolved request must retain its ID');
    expect(settings.projectAccess('demo')!.state, ProjectAccessState.unfiled);
    expect(access.unavailable(delivery: true), isNull);
    fixture.fail = null;
    await access.register();
    expect(fixture.changes.values.single.action, 'register');
  });

  // Harm: expected-view pins must not prevent reconciliation of older durable work.
  for (final entry in ['register', 'adapter', 'retry']) {
    for (final moved in ['project', 'card']) {
      for (final signed in [false, true]) {
        test('$entry reconciles ${signed ? 'filed' : 'unfiled'} before expected $moved checks', () async {
          final access = await fixture.access(settings);
          fixture.fail = signed ? 'upload' : 'file';
          fixture.lookupFailureAfterFile = const FormatException('lookup unavailable');
          await expectLater(access.register(), throwsFormatException);
          final old = settings.projectAccess('demo')!;
          fixture.fail = null;
          fixture.lookupFailure = null;
          fixture.lookupFailureAfterFile = null;
          final registration = RegistryProjectRegistration(access);
          // Keep the dialog's original state while the stored receipt is still unresolved.
          final expected = VerifiedHostProject(
            project: 'demo',
            host: fixture.host,
            revision: projectRevision,
            adminSigners: [hostKey],
            admitted: true,
          );
          if (moved == 'project') fixture.verifiedRevision = 'c' * 40;
          if (moved == 'card') fixture.host = PreparedHost.read({...sshCompletion(), 'address': '203.0.113.9'});
          fixture.calls.clear();
          final selected = !signed && entry != 'retry'
              ? await registration.verify('demo', registering: true)
              : expected;
          final work = entry == 'retry'
              ? access.retry()
              : entry == 'adapter'
              ? registration.register(
                  selected,
                  const Machine(name: 'host', kind: 'host', hostProject: 'orchard', socketPath: '/unused'),
                )
              : access.register(expected: selected);
          if (signed) {
            await expectLater(work, throwsA(isA<RegistryRefusal>()));
            expect(access.supersededChangeId, isNull);
            expect(settings.projectAccess('demo')!.stored, old.stored);
          } else {
            await work;
            if (entry == 'retry') {
              expect(settings.projectAccess('demo'), isNull);
            } else {
              expect(settings.projectAccess('demo')!.confirmed, isTrue);
              expect(settings.projectAccess('demo')!.change.id, isNot(old.change.id));
            }
          }
          if (!signed) expect(fixture.lookups, contains(old.change.id));
        });
      }
    }
  }

  // Harm: a refusal after persisting a new ID must not erase uncertain signed work.
  test('authorization refusal retains a new unfiled receipt for Retry', () async {
    final access = await fixture.access(settings);
    var reads = 0;
    fixture.onRead = () {
      if (++reads == 2) fixture.authorized = false;
    };
    await expectLater(access.register(), throwsA(isA<RegistryRefusal>()));
    expect(settings.projectAccess('demo'), isNotNull, reason: 'the unresolved request must retain its ID');
    expect(settings.projectAccess('demo')!.state, ProjectAccessState.unfiled);
    expect(access.unavailable(delivery: true), isNull);
    expect(fixture.calls, isEmpty);
  });

  // Harm: a locally signed self-revocation must still reach the host.
  for (final action in ['lock', 'remove']) {
    test('a self-$action at the filed revision can publish and deliver', () async {
      final alice = AccessDeveloper(login: 'alice', role: 'admin', fingerprint: adminFingerprint);
      fixture.members['alice'] = alice;
      fixture.afterFile = (revision) {
        fixture.currentAccess = revision;
        fixture.authorized = false;
      };
      final access = await fixture.access(settings);
      if (action == 'lock') {
        await access.lock('alice', locked: true, selected: alice);
      } else {
        await access.change('demo', alice, remove: true);
      }
      expect(fixture.calls, containsAllInOrder(['file', 'publish', 'upload', 'apply']));
      expect(settings.projectAccess('demo')!.confirmed, isTrue);
      expect(fixture.hostPeople['demo'], action == 'lock' ? {'alice': 'locked'} : isEmpty);
    });
  }

  // Harm: a returned server leaves a Retry stuck; an admission refresh must retain signed work.
  for (final refusal in ['returned', 'admission']) {
    test('a filed $refusal refusal keeps the correct recovery choice', () async {
      final store = MemorySettingsStore();
      final first = Settings(store);
      addTearDown(first.dispose);
      final access = await fixture.access(first);
      fixture.fail = 'publish';
      await expectLater(access.register(), throwsFormatException);
      final id = first.projectAccess('demo')!.change.id;
      fixture.fail = null;
      if (refusal == 'returned') {
        await first.rememberHostReturned('orchard');
      } else {
        fixture.registrySource.admitted = false;
        await fixture.registry.refresh();
      }
      fixture.calls.clear();
      if (refusal == 'returned') {
        await access.retry();
        expect(first.projectAccess('demo'), isNull);
        expect(access.supersededChangeId, isNull);
        expect(fixture.calls, isEmpty);
        return;
      }
      await expectLater(access.retry(), throwsA(isA<RegistryRefusal>()));
      expect(access.supersededChangeId, isNull);
      final restored = Settings(store);
      addTearDown(restored.dispose);
      await restored.load();
      final resumed = await fixture.access(restored);
      await resumed.read('demo');
      expect(resumed.unavailable(), contains('not admitted'));
      expect(resumed.unavailable(delivery: true), isNull);
      fixture.registrySource.admitted = true;
      await fixture.registry.refresh();
      await resumed.retry();
      expect(restored.projectAccess('demo')!.confirmed, isTrue);
      expect(restored.projectAccess('demo')!.change.id, id);
    });
  }

  // Harm: uncertain signing must never lose the only ID that recovers a signed commit.
  for (final entry in ['retry', 'register', 'change']) {
    test('$entry resolves a lost filing receipt before checking its old base', () async {
      final store = MemorySettingsStore();
      final first = Settings(store);
      addTearDown(first.dispose);
      final access = await fixture.access(first);
      fixture.fail = 'file-after-commit';
      fixture.lookupFailureAfterFile = const FormatException('Core lookup unavailable');
      await expectLater(access.register(), throwsA(isA<Exception>()));
      final id = first.projectAccess('demo')!.change.id;
      final restored = Settings(store);
      addTearDown(restored.dispose);
      await restored.load();
      final resumed = await fixture.access(restored);
      fixture.fail = null;
      fixture.lookupFailure = null;
      fixture.lookupFailureAfterFile = null;
      if (entry == 'retry') {
        await resumed.retry();
      } else if (entry == 'register') {
        await resumed.register();
      } else {
        await expectLater(resumed.change('demo', bob, remove: false), throwsA(isA<RegistryRefusal>()));
        expect(restored.projectAccess('demo')!.change.id, id);
        expect(restored.projectAccess('demo')!.revision, fixture.filed[id]);
        await resumed.retry();
      }
      expect(fixture.filed.keys, [id]);
      expect(fixture.calls.where((call) => call == 'file'), hasLength(1));
      expect(restored.projectAccess('demo')!.confirmed, isTrue);
    });
  }

  // Harm: a transient Core refusal must not erase uncertain work or start a replacement.
  test('replacement retains an unresolved receipt when Core lookup refuses', () async {
    final access = await fixture.access(settings);
    fixture.fail = 'file';
    fixture.lookupFailureAfterFile = const RegistryRefusal('Core lookup unavailable');
    await expectLater(access.register(), throwsA(isA<Exception>()));
    final id = settings.projectAccess('demo')!.change.id;
    fixture.fail = null;
    fixture.readFailure = const RegistryRefusal('Core read unavailable');
    fixture.calls.clear();
    await expectLater(access.change('demo', bob, remove: false), throwsA(isA<RegistryRefusal>()));
    expect(settings.projectAccess('demo')!.change.id, id);
    expect(fixture.calls, isEmpty);
  });

  // Harm: obsolete signed edits must not block all future work or erase confirmed registration.
  for (final moved in ['access']) {
    test('an overtaken $moved receipt offers scoped discard after restart', () async {
      final store = MemorySettingsStore();
      final first = Settings(store);
      addTearDown(first.dispose);
      final access = await fixture.access(first);
      await access.register();
      final confirmed = first.projectRegistration('demo')!.stored;
      fixture.fail = 'upload';
      await expectLater(access.change('demo', bob, remove: false), throwsFormatException);
      final id = first.projectAccess('demo')!.change.id;
      fixture.fail = null;
      fixture.currentAccess = 'c' * 40;
      fixture.deliveryVerdict = ProjectAccessRevisionOvertaken(id, first.projectAccess('demo')!.revision!);
      fixture.calls.clear();
      final restored = Settings(store);
      addTearDown(restored.dispose);
      await restored.load();
      final resumed = await fixture.access(restored);
      await expectLater(resumed.retry(), throwsA(isA<RegistryRefusal>()));
      final developers = ProjectDevelopers(project: 'demo', people: resumed);
      addTearDown(developers.dispose);
      await developers.load();
      final discard = projectPersonCommands(developers: developers)
          .where((command) => command.id == 'project.discardAccess');
      expect(discard, hasLength(1));
      expect(discard.single.unavailable, isNull);
      final finished = Completer<void>();
      developers.addListener(() {
        if (!developers.busy && !finished.isCompleted) finished.complete();
      });
      discard.single.run();
      await finished.future;
      expect(restored.projectAccess('demo'), isNull, reason: 'Only the superseded receipt $id is discarded');
      expect(restored.projectRegistration('demo')!.stored, confirmed);
      expect(fixture.calls, isEmpty);
    });
  }

  // Harm: Core's delivery refusal must not hide an overtaken receipt's local cleanup.
  test('supersession is resolved even when Core refuses old delivery authority', () async {
    final access = await fixture.access(settings);
    fixture.fail = 'upload';
    await expectLater(access.register(), throwsFormatException);
    fixture.fail = null;
    fixture.currentAccess = 'c' * 40;
    fixture.deliveryAuthorized = false;
    fixture.calls.clear();
    await expectLater(access.retry(), throwsA(isA<RegistryRefusal>()));
    expect(access.supersededChangeId, settings.projectAccess('demo')!.change.id);
    expect(fixture.calls, isEmpty);
  });

  // Harm: a developer needs project authority even when no project admin has host admission.
  test('a developer is directed to project admins without host admission', () async {
    fixture.authorized = false;
    fixture.actor = const HostAdminIdentity('bob', personFingerprint);
    fixture.registrySource.admitted = false;
    final access = await fixture.access(settings);
    await access.read('demo');
    expect(access.unavailable(), contains('alice@example.org'));
  });

  // Harm: delivery proof must survive a failed local recording and its subsequent retry.
  test('retry retains delivered state until local registration is confirmed', () async {
    final access = await fixture.access(settings);
    fixture.failRememberMachine = true;
    await expectLater(access.register(), throwsFormatException);
    expect(settings.projectAccess('demo')!.state, ProjectAccessState.delivered);
    final observed = <ProjectAccessState>[];
    settings.addListener(() => observed.add(settings.projectAccess('demo')!.state));
    fixture.failRememberMachine = false;
    await access.retry();
    expect(observed, isNot(contains(ProjectAccessState.filed)));
    expect(observed.last, ProjectAccessState.confirmed);
    expect(fixture.calls.where((call) => call == 'upload'), hasLength(1));
    expect(fixture.calls.where((call) => call == 'apply'), hasLength(1));
  });

  // Harm: later signed work must not strand an already applied receipt's local recording.
  for (final moved in ['access', 'project']) {
    for (final entry in ['retry', 'registration']) {
      test('delivered $entry finishes local recording after $moved advances', () async {
        final access = await fixture.access(settings);
        fixture.failRememberMachine = true;
        await expectLater(access.register(), throwsFormatException);
        final receipt = settings.projectAccess('demo')!;
        expect(receipt.state, ProjectAccessState.delivered);
        fixture.failRememberMachine = false;
        if (moved == 'access') fixture.currentAccess = 'c' * 40;
        if (moved == 'project') fixture.verifiedRevision = 'c' * 40;
        fixture.deliveryVerdict = ProjectAccessRevisionRefused(receipt.change.id, receipt.revision!);
        fixture.calls.clear();
        if (entry == 'retry') {
          await access.retry();
        } else {
          final registration = RegistryProjectRegistration(access);
          final state = await registration.verify('demo', registering: true);
          state.check('demo');
          expect(state.revision, receipt.change.projectRevision);
          final machine = await registration.connect(state);
          await registration.register(state, machine);
        }
        expect(settings.projectAccess('demo')!.confirmed, isTrue);
        expect(settings.projectAccess('demo')!.change.id, receipt.change.id);
        expect(fixture.calls, everyElement('connect'));
        expect(fixture.savedMachines.single.hostProject, 'orchard');
        expect(fixture.filed, hasLength(1));
      });
    }
  }

  // Harm: a filed person change whose project moved on is retried forever, though Core refused or authorized it.
  for (final verdict in ['refused', 'authorized']) {
    test('a filed person change Core $verdict after the project advanced is judged by Core, not the view', () async {
      final access = await fixture.access(settings);
      await access.register();
      fixture.fail = 'publish';
      await expectLater(access.change('demo', bob, remove: false), throwsFormatException);
      fixture.fail = null;
      final receipt = settings.projectAccess('demo')!;
      expect(receipt.state, ProjectAccessState.filed);
      fixture.verifiedRevision = 'c' * 40;
      if (verdict == 'refused') {
        fixture.deliveryVerdict = ProjectAccessRevisionRefused(receipt.change.id, receipt.revision!);
        await expectLater(access.retry(), throwsA(isA<RegistryRefusal>()));
        expect(settings.projectAccess('demo')!.state, ProjectAccessState.superseded);
      } else {
        await access.retry();
        expect(settings.projectAccess('demo')!.confirmed, isTrue);
        expect(settings.projectAccess('demo')!.change.id, receipt.change.id);
      }
      expect(fixture.filed, hasLength(2));
    });
  }

  // Harm: migration must retain both uncertain IDs and exact signed or confirmed revisions.
  test('legacy receipts retain their lifecycle and reject impossible new states', () async {
    final access = await fixture.access(settings);
    await access.register();
    final confirmed = settings.projectAccess('demo')!;
    final change = confirmed.change;
    for (final legacy in [
      (revision: null, published: false, uploaded: false, confirmed: false, state: ProjectAccessState.unfiled),
      (
        revision: confirmed.revision,
        published: true,
        uploaded: false,
        confirmed: false,
        state: ProjectAccessState.filed,
      ),
      (
        revision: confirmed.revision,
        published: true,
        uploaded: true,
        confirmed: true,
        state: ProjectAccessState.confirmed,
      ),
    ]) {
      final migrated = ProjectAccessProgress.read({
        'change': change.stored,
        'revision': legacy.revision,
        'published': legacy.published,
        'uploaded': legacy.uploaded,
        'confirmed': legacy.confirmed,
      });
      expect(migrated.state, legacy.state);
      expect(migrated.revision, legacy.revision);
      expect(migrated.change.id, change.id);
    }
    for (final invalid in [
      {'state': 'unknown'},
      {'state': 'unfiled'},
      {'state': 'filed', 'revision': null},
      {'state': 'delivered', 'uploaded': false},
      {'state': 'superseded', 'revision': null},
    ]) {
      expect(() => ProjectAccessProgress.read({...confirmed.stored, ...invalid}), throwsFormatException);
    }
  });

  // Harm: pending registration must not deliver an older project than the dialog approved.
  for (final stage in ['receipt', 'resume']) {
    test('registration pins expected state through the pending $stage path', () async {
      final access = await fixture.access(settings);
      fixture.fail = 'upload';
      await expectLater(access.register(), throwsFormatException);
      fixture.fail = null;
      final registration = RegistryProjectRegistration(access);
      final expected = await registration.verify('demo', registering: true);
      if (stage == 'receipt') fixture.verifiedRevision = 'c' * 40;
      var reads = 0;
      fixture.onRead = () {
        if (++reads == 2) {
          if (stage == 'receipt') fixture.verifiedRevision = projectRevision;
          if (stage == 'resume') fixture.verifiedRevision = 'c' * 40;
        }
      };
      fixture.calls.clear();
      await expectLater(access.register(expected: expected), throwsA(isA<RegistryRefusal>()));
      expect(fixture.calls, isEmpty);
    });
  }

  // Harm: refusals must direct the blocked person to a role that can authorize the action.
  for (final admin in [false, true]) {
    test('${admin ? 'an unadmitted admin' : 'a developer'} is directed to the right admins', () async {
      fixture.registrySource.assignedAdmins = ['bob'];
      fixture.authorized = admin;
      if (admin) {
        fixture.registrySource.admitted = false;
      } else {
        fixture.actor = const HostAdminIdentity('bob', personFingerprint);
      }
      final access = await fixture.access(settings);
      await access.read('demo');
      expect(access.unavailable(), contains(admin ? 'Bob (bob)' : 'alice@example.org'));
      expect(access.unavailable(), isNot(contains(admin ? 'alice@example.org' : 'Bob (bob)')));
      await expectLater(
        access.register(),
        throwsA(
          isA<RegistryRefusal>().having(
            (refusal) => refusal.whoMay.map((contact) => contact.login).toList(),
            'permitted role',
            [admin ? 'bob' : 'alice'],
          ),
        ),
      );
      expect(fixture.calls, isEmpty);
    });
  }

  // Harm: historical confirmation must not block re-registration or bypass host application.
  for (final moved in ['access', 'key', 'unchanged', 'readmitted']) {
    test('confirmed registration permits a fresh host delivery after $moved', () async {
      final access = await fixture.access(settings);
      await access.register();
      if (moved == 'access') await access.change('demo', bob, remove: false);
      if (moved == 'key') {
        fixture.actor = const HostAdminIdentity('alice', personFingerprint);
        fixture.registrySource.rotatedAdminFingerprint = personFingerprint;
        await fixture.registry.refresh();
      }
      if (moved == 'readmitted') {
        fixture.registrySource.admitted = false;
        await fixture.registry.refresh();
        await expectLater(access.register(), throwsA(isA<RegistryRefusal>()));
        fixture.registrySource.admitted = true;
        await fixture.registry.refresh();
      }
      fixture.calls.clear();
      await access.register();
      expect(fixture.calls, containsAllInOrder(['upload', 'apply']));
      expect(fixture.changes.values.where((change) => change.action == 'register'), hasLength(2));
      expect(settings.projectAccess('demo')!.confirmed, isTrue);
    });
  }

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
    fixture.lookupFailureAfterFile = const FormatException('Core lookup unavailable');
    await expectLater(access.change('demo', bob, remove: false), throwsFormatException);
    fixture.lookupFailure = null;
    fixture.lookupFailureAfterFile = null;
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
    fixture.lookupFailureAfterFile = const FormatException('Core lookup unavailable');
    await expectLater(access.change('demo', bob, remove: false), throwsFormatException);
    fixture.lookupFailure = null;
    fixture.lookupFailureAfterFile = null;
    fixture.eligible = false;
    await access.retry();
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
      expect(fixture.filed.length, 2);
    });
  }

  // Harm: a historical registration must survive a failed bring of newer access.
  test('confirmed registration survives while newer access is registered after restart', () async {
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
    expect(fixture.filed.length, 3);
    expect(fixture.changes.values.where((change) => change.action == 'register'), hasLength(2));
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

  // Harm: picker changes must not lose an already signed unlock.
  test('a signed unlock retries its own accepted revision after eligibility changes', () async {
    final access = await fixture.access(settings);
    await access.change('demo', bob, remove: false);
    await access.lock('bob', locked: true);
    fixture.fail = 'upload';
    await expectLater(access.lock('bob', locked: false), throwsFormatException);
    final receipt = settings.projectAccess('demo')!;
    fixture.fail = null;
    fixture.eligible = false;
    fixture.calls.clear();
    await access.retry();
    expect(settings.projectAccess('demo')!.change.id, receipt.change.id);
    expect(settings.projectAccess('demo')!.confirmed, isTrue);
    expect(fixture.calls, ['connect', 'upload', 'apply']);
    expect(fixture.hostPeople['demo'], {'bob': 'active'});
  });

  // Harm: an adapter's stale Machine must not prevent resolution of durable work.
  for (final signed in [false, true]) {
    test('adapter resolves ${signed ? 'filed' : 'unfiled'} before checking a mismatched machine', () async {
      final access = await fixture.access(settings);
      fixture.fail = signed ? 'upload' : 'file';
      await expectLater(access.register(), throwsFormatException);
      final old = settings.projectAccess('demo')!;
      fixture.fail = null;
      final registration = RegistryProjectRegistration(access);
      final expected = VerifiedHostProject(
        project: 'demo',
        host: fixture.host,
        revision: projectRevision,
        adminSigners: [hostKey],
        admitted: true,
      );
      if (signed) fixture.verifiedRevision = 'c' * 40;
      fixture.lookups.clear();
      fixture.calls.clear();
      await expectLater(
        registration.register(
          expected,
          const Machine(name: 'wrong host', kind: 'host', hostProject: 'other', socketPath: '/unused'),
        ),
        throwsA(isA<RegistryRefusal>()),
      );
      if (signed) {
        expect(access.supersededChangeId, isNull);
        expect(settings.projectAccess('demo')!.stored, old.stored);
      } else {
        expect(fixture.lookups, [old.change.id]);
        expect(settings.projectAccess('demo'), isNull);
      }
      expect(fixture.calls, isEmpty);
    });
  }

  // Harm: an absent cached person must not bypass reconciliation of durable work.
  for (final signed in [false, true]) {
    test('lock resolves ${signed ? 'filed' : 'unfiled'} before checking a missing person', () async {
      final access = await fixture.access(settings);
      fixture.fail = signed ? 'upload' : 'file';
      await expectLater(access.register(), throwsFormatException);
      final old = settings.projectAccess('demo')!;
      fixture.fail = null;
      access.current = null;
      if (signed) fixture.verifiedRevision = 'c' * 40;
      fixture.lookups.clear();
      fixture.calls.clear();
      await expectLater(access.lock('bob', locked: true), throwsA(isA<RegistryRefusal>()));
      if (signed) {
        expect(access.supersededChangeId, isNull);
        expect(settings.projectAccess('demo')!.stored, old.stored);
      } else {
        expect(fixture.lookups, [old.change.id]);
        expect(settings.projectAccess('demo'), isNull);
      }
      expect(fixture.calls, isEmpty);
    });
  }

  // Harm: current eligibility or signer loss must not strand any filed action.
  for (final action in ['add', 'unlock', 'lock', 'remove', 'register']) {
    for (final head in ['base', 'filed']) {
      test('filed $action uses exact Core authority before publication with $head head', () async {
        if (action != 'add' && action != 'register') {
          fixture.members['bob'] = AccessDeveloper(
            login: 'bob',
            role: 'developer',
            fingerprint: personFingerprint,
            locked: action == 'unlock',
          );
        }
        final access = await fixture.access(settings);
        fixture.afterFile = (revision) {
          if (head == 'filed') fixture.currentAccess = revision;
          fixture.authorized = false;
          fixture.eligible = false;
        };
        switch (action) {
          case 'register':
            await access.register();
          case 'add':
            await access.change('demo', bob, remove: false);
          case 'remove':
            await access.change('demo', fixture.members['bob']!, remove: true);
          case 'lock':
            await access.lock('bob', locked: true, selected: fixture.members['bob']);
          case 'unlock':
            await access.lock('bob', locked: false, selected: fixture.members['bob']);
        }
        expect(fixture.deliveryBeforePublish, isTrue, reason: 'Core must judge the filed request before publishing');
        expect(settings.projectAccess('demo')!.confirmed, isTrue);
        expect(fixture.filed, hasLength(1));
        expect(fixture.hostPeople['demo'], switch (action) {
          'add' || 'unlock' => {'bob': 'active'},
          'lock' => {'bob': 'locked'},
          _ => isEmpty,
        });
      });
    }
  }

  // Harm: Core must never substitute a different revision for the filed request.
  test('a delivery verdict at another revision cannot publish or reach the host', () async {
    final access = await fixture.access(settings);
    fixture.fail = 'publish';
    await expectLater(access.register(), throwsFormatException);
    fixture.fail = null;
    fixture.deliveryRevision = registryBefore;
    fixture.calls.clear();
    await expectLater(access.retry(), throwsA(isA<RegistryRefusal>()));
    expect(access.supersededChangeId, isNull);
    expect(settings.projectAccess('demo')!.state, ProjectAccessState.filed);
    expect(fixture.calls, isEmpty);
  });

  // Harm: refusal wording must not discard a signed change, including across restart.
  for (final stage in ['delivery', 'publication lookup', 'publish', 'upload', 'apply']) {
    for (final transient in [false, true]) {
      test('$stage refusal with ${transient ? 'temporary' : 'final'} words retains Retry across restart', () async {
        final store = MemorySettingsStore();
        final first = Settings(store);
        addTearDown(first.dispose);
        final access = await fixture.access(first);
        await access.register();
        final history = first.projectRegistration('demo')!.stored;
        fixture.refusalStage = stage;
        fixture.refusal = RegistryRefusal(
          transient
              ? 'Unlock your signing agent before changing this project.'
              : 'The filed project change is permanently refused.',
        );
        await expectLater(access.register(), throwsA(isA<RegistryRefusal>()));
        final receipt = first.projectAccess('demo')!;
        final restored = Settings(store);
        addTearDown(restored.dispose);
        await restored.load();
        final resumed = await fixture.access(restored);
        expect(receipt.state, ProjectAccessState.filed);
        expect(resumed.supersededChangeId, isNull);
        expect(resumed.unavailable(delivery: true), isNull);
        expect(restored.projectRegistration('demo')!.stored, history);
        fixture.refusalStage = null;
        await resumed.retry();
        expect(restored.projectAccess('demo')!.change.id, receipt.change.id);
        expect(restored.projectAccess('demo')!.confirmed, isTrue);
      });
    }
  }

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

class _FilingFixture extends ProjectAccessFixture {
  void Function(String revision)? afterFile;
  String? refusalStage;
  RegistryRefusal? refusal;
  bool deliveryBeforePublish = false;
  ProjectAccessDelivery? deliveryVerdict;

  void _refuse(String stage) {
    if (refusalStage == stage) throw refusal!;
  }

  @override
  Future<ProjectAccessDelivery> delivery(ProjectAccessChange change, String revision) async {
    deliveryBeforePublish |= !published.contains(revision);
    _refuse('delivery');
    if (deliveryVerdict case final verdict?) return verdict;
    return super.delivery(change, revision);
  }

  @override
  Future<bool> publishedRevision(ProjectAccessChange change, String revision) async {
    _refuse('publication lookup');
    return super.publishedRevision(change, revision);
  }

  @override
  Future<void> publish(ProjectAccessChange change, String revision) async {
    _refuse('publish');
    await super.publish(change, revision);
  }

  @override
  Future<void> upload(ProjectAccessChange change, String revision) async {
    _refuse('upload');
    await super.upload(change, revision);
  }

  @override
  Future<ProjectAccessStatus> apply(ProjectAccessChange change, String revision) async {
    _refuse('apply');
    return super.apply(change, revision);
  }

  @override
  Future<String> file(ProjectAccessChange change) async {
    final revision = await super.file(change);
    afterFile?.call(revision);
    return revision;
  }
}
