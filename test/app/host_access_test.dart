import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/host_access.dart';
import 'package:porelo_frontend/src/app/commands.dart';
import 'package:porelo_frontend/src/app/host_runs.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/host_access_contract.dart';
import 'package:porelo_frontend/src/app/registry.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/app/host_session.dart';
import 'package:porelo_host/porelo_host.dart';

import '../support/host_registry.dart';
import '../support/host_process.dart';
import '../features/support/world.dart' show FakeBackend;

void main() {
  late RegistryFixture fixture;
  late MemorySettingsStore store;
  late Settings settings;
  late HostAccess access;
  setUp(() async {
    fixture = RegistryFixture();
    store = MemorySettingsStore();
    settings = Settings(store);
    access = await fixture.access(settings);
    addTearDown(settings.dispose);
    addTearDown(fixture.registry.dispose);
  });
  Future<void> admit() => access.admit(
    host: 'orchard',
    person: 'bob',
    project: 'demo',
    accessRepository: 'git@example.org:team/demo-access.git',
  );

  // Harm: discarding an unfiled selection loses the published card and re-files it.
  for (final direct in [false, true]) {
    test('stale selection ${direct ? 'replacement' : 'discard'} retains publication across restart', () async {
      final card = PreparedHost.read(sshCompletion());
      await settings.rememberHostUp('orchard', _readyRecord());
      await access.publishReady('orchard', card);
      await access.bringToHost('orchard');
      fixture.fail = 'file';
      await expectLater(admit(), throwsException);
      fixture.fail = null;
      fixture.selectedFingerprint = 'SHA256:${'C' * 43}';
      await fixture.registry.refresh();
      if (direct) {
        await admit();
      } else {
        await expectLater(access.bringToHost('orchard'), throwsA(isA<RegistryRefusal>()));
      }
      final reopened = Settings(store);
      addTearDown(reopened.dispose);
      await reopened.load();
      final restored = HostAccess(
        registry: fixture.registry,
        settings: reopened,
        identity: () => fixture.actor,
        writer: WriterFixture(fixture),
        transport: fixture,
      );
      final filed = fixture.changes.length;
      await restored.bringToHost('orchard');
      expect(fixture.changes, hasLength(filed), reason: 'Bring must deliver without re-filing the unchanged card');
      expect(reopened.hostRegistry('orchard')!.lastAppliedRevision, fixture.registryRevision);
    });
  }

  // Harm: forgetting a refused unlock re-files a previously published card.
  test('discarded unlock retains confirmed host facts across restart', () async {
    await settings.rememberHostUp('orchard', _readyRecord());
    await access.publishReady('orchard', PreparedHost.read(sshCompletion()));
    await access.bringToHost('orchard');
    fixture.people['bob'] = 'locked';
    fixture.fail = 'file';
    await expectLater(access.membership(host: 'orchard', person: 'bob', action: 'unlock'), throwsException);
    fixture.fail = null;
    fixture.refusedPerson = true;
    await fixture.registry.refresh();
    await expectLater(access.bringToHost('orchard'), throwsA(isA<RegistryRefusal>()));
    final reopened = Settings(store);
    addTearDown(reopened.dispose);
    await reopened.load();
    expect(reopened.hostRegistryState('orchard').lastAppliedRevision, fixture.applied);
    final restored = HostAccess(
      registry: fixture.registry,
      settings: reopened,
      identity: () => fixture.actor,
      writer: WriterFixture(fixture),
      transport: fixture,
    );
    await restored.bringToHost('orchard');
    expect(fixture.changes.map((change) => change.action), ['host-card']);
    expect(fixture.people['bob'], 'locked');
  });

  // Harm: retrying publication after another operation creates a duplicate card commit.
  for (final operation in ['admit', 'deliver']) {
    test('publication after $operation is idempotent', () async {
      final card = PreparedHost.read(sshCompletion());
      await access.publishReady('orchard', card);
      if (operation == 'admit') {
        await admit();
      } else {
        await access.bringToHost('orchard');
      }
      final filed = fixture.changes.length;
      await access.publishReady('orchard', card);
      expect(fixture.changes, hasLength(filed));
    });
  }

  // Harm: a returned host publication destroys deletion recovery and blocks name reuse.
  test('publication on a returned host preserves its completed deletion', () async {
    await settings.rememberHostReturned('orchard');
    await access.bringToHost('orchard');
    await expectLater(
      access.publishReady('orchard', PreparedHost.read(sshCompletion())),
      throwsA(isA<RegistryRefusal>()),
    );
    await access.beginPreparation('orchard');
    expect(settings.hostReturned('orchard'), isFalse);
    expect(fixture.changes.map((change) => change.action), ['delete-card']);
  });

  // Harm: old membership progress without card metadata re-files an unchanged host card.
  for (final action in ['admit', 'lock', 'unlock', 'purge', 'deliver']) {
    test('legacy $action progress delivers without re-filing the retained card', () async {
      await settings.rememberHostUp('orchard', _readyRecord());
      await admit();
      final raw = await store.read();
      final progress = Map<String, Object?>.from((raw['hostRegistry'] as Map)['orchard'] as Map);
      final change = Map<String, Object?>.from(progress['change'] as Map)..['action'] = action;
      progress['change'] = change;
      progress.remove('published_card');
      raw['hostRegistry'] = {'orchard': progress};
      raw.remove('hostRegistryState');
      await store.write(raw);
      final reopened = Settings(store);
      addTearDown(reopened.dispose);
      await reopened.load();
      final restored = HostAccess(
        registry: fixture.registry,
        settings: reopened,
        identity: () => fixture.actor,
        writer: WriterFixture(fixture),
        transport: fixture,
      );
      final filed = fixture.changes.length;
      await restored.bringToHost('orchard');
      expect(fixture.changes, hasLength(filed));
      expect(restored.notOnHostYet('orchard'), isFalse);
    });
  }

  // Harm: a legacy unfiled selection discards the only memory of the published card.
  test('legacy unfiled stale admission keeps the retained published card after discard', () async {
    await settings.rememberHostUp('orchard', _readyRecord());
    fixture.fail = 'file';
    await expectLater(admit(), throwsException);
    final raw = await store.read();
    raw.remove('hostRegistryState');
    await store.write(raw);
    final reopened = Settings(store);
    addTearDown(reopened.dispose);
    await reopened.load();
    final restored = HostAccess(
      registry: fixture.registry,
      settings: reopened,
      identity: () => fixture.actor,
      writer: WriterFixture(fixture),
      transport: fixture,
    );
    fixture.fail = null;
    fixture.selectedFingerprint = 'SHA256:${'C' * 43}';
    await fixture.registry.refresh();
    await expectLater(restored.bringToHost('orchard'), throwsA(isA<RegistryRefusal>()));
    await restored.bringToHost('orchard');
    expect(fixture.changes.where((change) => change.action == 'host-card'), isEmpty);
  });

  // Harm: migration mistakes an unpublished replacement completion for the published card.
  test('legacy card comparison refuses publication until actual registry card values are verified', () async {
    final replacement = PreparedHost.read({...sshCompletion(), 'address': '203.0.113.8'});
    await settings.rememberHostUp('orchard', _readyRecord().withPreparedHost(replacement));
    await admit();
    final raw = await store.read();
    raw.remove('hostRegistryState');
    await store.write(raw);
    final reopened = Settings(store);
    addTearDown(reopened.dispose);
    await reopened.load();
    final restored = HostAccess(
      registry: fixture.registry,
      settings: reopened,
      identity: () => fixture.actor,
      writer: WriterFixture(fixture),
      transport: fixture,
    );
    await restored.bringToHost('orchard');
    expect(
      reopened.hostRegistryState('orchard').publishedCard,
      isNull,
      reason: 'a saved replacement is not evidence of its publication',
    );
    await expectLater(restored.publishReady('orchard', replacement), throwsA(isA<RegistryRefusal>()));
    expect(fixture.changes.map((change) => change.action), ['admit']);
  });

  // Harm: an interrupted operation or setup without a card blocks the returned name forever.
  for (final action in ['none', 'host-card', 'deliver', 'admit', 'lock']) {
    test('return supersedes interrupted $action and permits reuse after deletion', () async {
      if (action == 'host-card') {
        fixture.fail = 'publish';
        await expectLater(access.publishReady('orchard', PreparedHost.read(sshCompletion())), throwsException);
      } else if (action == 'deliver') {
        await admit();
        fixture.applied = registryBefore;
        fixture.fail = 'upload';
        await expectLater(access.bringToHost('orchard'), throwsException);
      } else if (action == 'admit' || action == 'lock') {
        fixture.fail = 'publish';
        if (action == 'admit') {
          await expectLater(admit(), throwsException);
        } else {
          await expectLater(access.membership(host: 'orchard', person: 'bob', action: 'lock'), throwsException);
        }
      }
      fixture.fail = null;
      await settings.rememberHostReturned('orchard');
      await access.bringToHost('orchard');
      await access.beginPreparation('orchard');
      expect(settings.hostReturned('orchard'), isFalse);
      expect(fixture.changes.last.action, 'delete-card');
    });
  }

  // Harm: an unrefreshed read attempts a rollback after a successful admission.
  test('successful admission never offers or sends an older registry', () async {
    await admit();
    expect(access.notOnHostYet('orchard'), isFalse);
    await access.bringToHost('orchard');
    expect(fixture.calls.where((call) => call == 'sync orchard $registryBefore'), isEmpty);
    expect(access.notOnHostYet('orchard'), isFalse);
  });

  // Harm: publication failure before progress exists silently leaves the host card unfiled.
  test('Bring recovers a ready completion retained before publication', () async {
    await settings.rememberHostUp('orchard', _readyRecord());
    fixture.listedHost = false;
    await fixture.registry.refresh();
    await access.bringToHost('orchard');
    expect(fixture.changes.map((change) => change.action), ['host-card']);
    expect(fixture.changes.single.card!.stored, sshCompletion());
    expect(fixture.calls.where((call) => call.startsWith('sync')), isEmpty);
  });

  // Harm: a previous publication masks the unpublished completion of a replacement server.
  test('Bring publishes a retained replacement after authorization was temporarily unavailable', () async {
    await access.publishReady('orchard', PreparedHost.read({...sshCompletion(), 'address': '203.0.113.8'}));
    await settings.rememberHostUp('orchard', _readyRecord());
    fixture.actor = null;
    await expectLater(
      access.publishReady('orchard', PreparedHost.read(sshCompletion())),
      throwsA(isA<RegistryRefusal>()),
    );
    fixture.actor = const HostAdminIdentity('alice', adminFingerprint);
    await access.bringToHost('orchard');
    expect(fixture.changes.map((change) => change.action), ['host-card', 'host-card']);
    expect(fixture.changes.last.card!.values['address'], '203.0.113.7');
  });

  // Harm: an unfiled admission of a changed or refused card blocks all later changes.
  for (final refused in [false, true]) {
    test('unfiled admission can be replaced after card ${refused ? 'refusal' : 'rotation'}', () async {
      fixture.fail = 'file';
      await expectLater(admit(), throwsException);
      fixture.fail = null;
      fixture.refusedPerson = refused;
      fixture.selectedFingerprint = 'SHA256:${'C' * 43}';
      await fixture.registry.refresh();
      await expectLater(access.bringToHost('orchard'), throwsA(isA<RegistryRefusal>()));
      await access.membership(host: 'orchard', person: 'bob', action: 'lock');
      expect(fixture.changes.map((change) => change.action), ['lock']);
      expect(fixture.people['bob'], 'locked');
    });
  }

  // Harm: retained host actions contact unpinned or no-longer-authorized hosts.
  for (final missing in [false, true]) {
    for (final operation in ['membership', 'bring', 'status']) {
      test('$operation refuses ${missing ? 'absent' : 'unassigned'} hosts before transport', () async {
        fixture.listedHost = !missing;
        fixture.assignedAdmins = [];
        await fixture.registry.refresh();
        final action = switch (operation) {
          'membership' => access.membership(host: 'orchard', person: 'bob', action: 'lock'),
          'bring' => access.bringToHost('orchard'),
          _ => access.refreshStatus('orchard'),
        };
        await expectLater(action, throwsA(isA<RegistryRefusal>()));
        expect(fixture.calls, isEmpty);
      });
    }
  }
  test('status validates host name and current admin before transport', () async {
    await expectLater(access.refreshStatus('../orchard'), throwsFormatException);
    fixture.actor = const HostAdminIdentity('bob', personFingerprint);
    await expectLater(access.refreshStatus('orchard'), throwsA(isA<RegistryRefusal>()));
    expect(fixture.calls, isEmpty);
  });

  // Harm: a deleted account is resurrected or a refused key regains access.
  for (final action in ['lock', 'unlock']) {
    test('$action refuses a purged membership without filing', () async {
      fixture.people['bob'] = 'purged';
      await expectLater(
        access.membership(host: 'orchard', person: 'bob', action: action),
        throwsA(isA<RegistryRefusal>()),
      );
      expect(fixture.changes, isEmpty);
    });
  }
  test('unlock refuses a registry card refused during the status read', () async {
    fixture.people['bob'] = 'locked';
    fixture.statusStarted = Completer<void>();
    final release = Completer<void>();
    fixture.holdStatus = release.future;
    final pending = access.membership(host: 'orchard', person: 'bob', action: 'unlock');
    final refusal = expectLater(pending, throwsA(isA<RegistryRefusal>()));
    await fixture.statusStarted!.future;
    fixture.refusedPerson = true;
    await fixture.registry.refresh();
    release.complete();
    await refusal;
    expect(fixture.changes, isEmpty);
  });

  // Harm: retrying an ancestor wedges delivery or restores superseded access.
  for (final advancedHost in [false, true]) {
    test('pending delivery advances safely when ${advancedHost ? 'host' : 'registry'} is newer', () async {
      fixture.fail = 'sync';
      await expectLater(admit(), throwsException);
      fixture.fail = null;
      const newer = '3333333333333333333333333333333333333333';
      fixture.parents[newer] = registryAfter;
      fixture.registryRevision = newer;
      if (advancedHost) fixture.applied = newer;
      fixture.people['bob'] = 'locked';
      await fixture.registry.refresh();
      fixture.calls.clear();
      await access.bringToHost('orchard');
      expect(fixture.calls.where((call) => call == 'sync orchard $registryAfter'), isEmpty);
      expect(access.statusFor('orchard')!.revision, newer);
      expect(fixture.people['bob'], 'locked');
      expect(access.pendingRevision('orchard'), isNull);
    });
  }
  test('pending upload receipt is rechecked after staged intake is lost', () async {
    fixture.requireStaged = true;
    fixture.fail = 'sync';
    await expectLater(admit(), throwsException);
    fixture.fail = null;
    fixture.staged.clear();
    await access.bringToHost('orchard');
    expect(fixture.calls.where((call) => call.startsWith('upload')), hasLength(2));
    expect(fixture.people['bob'], 'active');
    expect(access.pendingRevision('orchard'), isNull);
  });

  // Harm: a returned server still accepts retained admin commands.
  test('confirmed return disables memberships and clears stale ready completion', () async {
    await settings.rememberHostUp('orchard', _readyRecord());
    await access.publishReady('orchard', PreparedHost.read(sshCompletion()));
    final machines = Machines(settings, reach: (_) => FakeBackend(const []));
    final runs = HostRuns(machines, hostAccess: access);
    addTearDown(runs.dispose);
    addTearDown(machines.dispose);
    var opened = false;
    final command = preparedHostCommands(
      machine: const Machine(
        name: 'orchard',
        kind: 'host',
        hostProject: 'orchard',
        identity: '/keys/private',
        socketPath: '',
      ),
      settings: settings,
      hostRuns: runs,
      open: (_) => opened = true,
    ).singleWhere((command) => command.id == 'host.lockAdmin');
    await settings.rememberHostReturned('orchard');
    expect(command.run, throwsA(isA<RegistryRefusal>()));
    expect(opened, isFalse);
    await access.bringToHost('orchard');
    expect(access.notOnHostYet('orchard'), isFalse);
    expect(settings.hostUp('orchard')!.preparedHost, isNull);
    await expectLater(
      access.membership(host: 'orchard', person: 'bob', action: 'lock'),
      throwsA(isA<RegistryRefusal>()),
    );
  });

  // Harm: a forked registry restores access removed on another branch.
  test('a forked delivery is refused without upload or sync', () async {
    fixture.fail = 'sync';
    await expectLater(admit(), throwsException);
    fixture.fail = null;
    fixture.registryRevision = 'f' * 40;
    await fixture.registry.refresh();
    fixture.calls.clear();
    await expectLater(access.bringToHost('orchard'), throwsA(isA<RegistryRefusal>()));
    expect(fixture.calls, isEmpty);
    expect(access.pendingRevision('orchard'), registryAfter);
  });

  // Harm: a restarted retry forgets its original signature or rolls back a newer lock.
  test('descendant retry survives restart and preserves the original signed operation', () async {
    fixture.fail = 'sync';
    await expectLater(admit(), throwsException);
    const newer = '3333333333333333333333333333333333333333';
    fixture.parents[newer] = registryAfter;
    fixture.registryRevision = newer;
    fixture.people['bob'] = 'locked';
    await fixture.registry.refresh();
    await expectLater(access.bringToHost('orchard'), throwsException);
    final reopened = Settings(store);
    addTearDown(reopened.dispose);
    await reopened.load();
    final restored = HostAccess(
      registry: fixture.registry,
      settings: reopened,
      identity: () => fixture.actor,
      writer: WriterFixture(fixture),
      transport: fixture,
    );
    fixture.fail = null;
    await restored.bringToHost('orchard');
    expect(fixture.people['bob'], 'locked');
    expect(fixture.changes, hasLength(1));
    expect(reopened.hostRegistry('orchard')!.revision, registryAfter);
    expect(reopened.hostRegistry('orchard')!.lastAppliedRevision, newer);
    expect(restored.notOnHostYet('orchard'), isFalse);
  });

  // Harm: a changed unfiled selection prevents the next explicit admission indefinitely.
  test('a new selection replaces a stale unfiled admission directly', () async {
    fixture.fail = 'file';
    await expectLater(admit(), throwsException);
    fixture.fail = null;
    fixture.selectedFingerprint = 'SHA256:${'C' * 43}';
    await fixture.registry.refresh();
    await admit();
    expect(fixture.changes.single.fingerprint, fixture.selectedFingerprint);
    expect(fixture.people['bob'], 'active');
  });

  // Harm: a completed publication blocks a replacement server's changed SSH pin.
  test('a new ready card replaces an already completed publication', () async {
    await access.publishReady('orchard', PreparedHost.read(sshCompletion()));
    final replacement = PreparedHost.read({...sshCompletion(), 'address': '203.0.113.8'});
    await access.publishReady('orchard', replacement);
    expect(fixture.changes, hasLength(2));
    expect(fixture.changes.last.card!.values['address'], '203.0.113.8');
  });

  // Harm: a refused upload or stale sync grants access from a different signed state.
  test('refused upload prevents sync and wrong revision never confirms admission', () async {
    fixture.fail = 'upload';
    await expectLater(admit(), throwsA(isA<Exception>()));
    expect(fixture.calls.where((call) => call.startsWith('sync')), isEmpty);
    expect(access.pendingRevision('orchard'), registryAfter);
    fixture.fail = null;
    fixture.syncRevision = registryBefore;
    await expectLater(access.bringToHost('orchard'), throwsFormatException);
    expect(access.pendingRevision('orchard'), registryAfter);
    expect(access.notOnHostYet('orchard'), isTrue);
  });

  // Harm: restarting repeats a signed admission or loses delivery after intake disappears.
  for (final failure in ['publish', 'upload', 'sync']) {
    test('restart after $failure retries only unconfirmed work', () async {
      fixture.fail = failure;
      await expectLater(admit(), throwsA(isA<Exception>()));
      final calls = List.of(fixture.calls);
      fixture.fail = null;
      final reopened = Settings(store);
      addTearDown(reopened.dispose);
      await reopened.load();
      final restored = HostAccess(
        registry: fixture.registry,
        settings: reopened,
        identity: () => fixture.actor,
        writer: WriterFixture(fixture),
        transport: fixture,
      );
      await restored.bringToHost('orchard');
      expect(fixture.changes, hasLength(1));
      expect(fixture.calls.where((call) => call == 'file'), hasLength(1));
      if (failure == 'sync') expect(fixture.calls.where((call) => call.startsWith('upload')), hasLength(2));
      expect(reopened.hostRegistry('orchard')!.complete, isTrue);
      expect(restored.statusFor('orchard')!.words, 'Host result.');
      expect(calls.last, startsWith(failure));
    });
  }

  // Harm: failed signing or publication delivers an unsigned or unpublished state.
  for (final failure in ['file', 'publish']) {
    test('$failure refusal reaches no host upload', () async {
      fixture.fail = failure;
      await expectLater(admit(), throwsA(isA<Exception>()));
      expect(fixture.calls.where((call) => call.startsWith('upload') || call.startsWith('sync')), isEmpty);
    });
  }

  // Harm: host removal while progress is persisted still signs a membership change.
  test('host removed during persistence prevents signing', () async {
    final held = _HoldingStore();
    final durable = Settings(held);
    addTearDown(durable.dispose);
    final guarded = HostAccess(
      registry: fixture.registry,
      settings: durable,
      identity: () => fixture.actor,
      writer: WriterFixture(fixture),
      transport: fixture,
    );
    final pending = guarded.admit(
      host: 'orchard',
      person: 'bob',
      project: 'demo',
      accessRepository: 'git@example.org:team/demo-access.git',
    );
    final refusal = expectLater(pending, throwsA(isA<RegistryRefusal>()));
    await held.started.future;
    fixture.listedHost = false;
    await fixture.registry.refresh();
    held.release.complete();
    await refusal;
    expect(fixture.calls, isEmpty);
  });

  // Harm: host removal while signing still publishes a now-unauthorized membership.
  test('host removed during filing prevents publication', () async {
    final release = Completer<void>();
    fixture.holdFile = release.future;
    fixture.fileStarted = Completer<void>();
    final pending = admit();
    final refusal = expectLater(pending, throwsA(isA<RegistryRefusal>()));
    await fixture.fileStarted!.future;
    fixture.listedHost = false;
    await fixture.registry.refresh();
    release.complete();
    await refusal;
    expect(fixture.calls.where((call) => call.startsWith('publish')), isEmpty);
    expect(fixture.calls.where((call) => call.startsWith('upload')), isEmpty);
  });

  // Harm: permission lost during a status read still reaches the privileged sync.
  test('permission revoked during status prevents sync', () async {
    final release = Completer<void>();
    fixture.holdStatus = release.future;
    fixture.statusStarted = Completer<void>();
    final pending = admit();
    final refused = expectLater(pending, throwsA(isA<RegistryRefusal>()));
    await fixture.statusStarted!.future;
    fixture.actor = const HostAdminIdentity('bob', personFingerprint);
    release.complete();
    await refused;
    expect(fixture.calls.where((call) => call.startsWith('sync')), isEmpty);
  });

  // Harm: explicit repair trusts an old local receipt after a host lost its applied state.
  test('bring reconciles a host whose status contradicts the persisted receipt', () async {
    await admit();
    fixture.registryRevision = registryAfter;
    await fixture.registry.refresh();
    fixture.applied = registryBefore;
    await access.refreshStatus('orchard');
    expect(access.notOnHostYet('orchard'), isTrue);
    final syncs = fixture.calls.where((call) => call.startsWith('sync')).length;
    await access.bringToHost('orchard');
    expect(fixture.calls.where((call) => call.startsWith('sync')), hasLength(syncs + 1));
    expect(access.statusFor('orchard')!.revision, registryAfter);
  });

  // Harm: an in-flight admission overwrites provider success and permits a second give-back.
  test('concurrent confirmed give-back survives a delayed admission checkpoint', () async {
    await settings.rememberHostUp(
      'orchard',
      const HostUpRecord(
        host: 'orchard',
        hostName: 'orchard',
        scalewayProject: 'provider',
        account: 'root',
        publicKey: '/keys/public',
        collection: '',
      ),
    );
    final release = Completer<void>();
    fixture.holdUpload = release.future;
    fixture.uploadStarted = Completer<void>();
    final pending = admit().catchError((Object _) {});
    await fixture.uploadStarted!.future;
    final process = HostProcess();
    final down = HostSession(executable: 'fake', arguments: const [], start: (_, _) async => process);
    addTearDown(down.dispose);
    final completed = down.down();
    process.line(const Step('give-back', StepState.done, address: '203.0.113.7'));
    process.end(0);
    await completed;
    await confirmHostRegistryGiveBack(host: 'orchard', session: down, settings: settings, access: access);
    release.complete();
    await pending;
    expect(access.givenBack('orchard'), isTrue);
    final reopened = Settings(store);
    addTearDown(reopened.dispose);
    await reopened.load();
    final restored = HostAccess(
      registry: fixture.registry,
      settings: reopened,
      identity: () => fixture.actor,
      writer: WriterFixture(fixture),
      transport: fixture,
    );
    expect(restored.givenBack('orchard'), isTrue);
    await restored.bringToHost('orchard');
    expect(fixture.changes.last.action, 'delete-card');
  });

  // Harm: a response from another host confirms access on the intended one.
  test('a wrong host is refused and keeps the pending state', () async {
    fixture.answerHost = 'another';
    await expectLater(admit(), throwsFormatException);
    expect(settings.hostRegistry('orchard')!.complete, isFalse);
  });

  // Harm: retained callbacks bypass changed permissions or select refused cards.
  test('authorization is rechecked with identity fingerprint and contacts', () async {
    expect(access.unavailable(), isNull);
    Future<void> callback() => access.prepare(() async {
      fixture.calls.add('rent');
    });
    fixture.actor = const HostAdminIdentity('bob', personFingerprint);
    expect(access.unavailable(), contains('alice@example.org'));
    await expectLater(callback(), throwsA(isA<RegistryRefusal>()));
    await expectLater(admit(), throwsA(isA<RegistryRefusal>()));
    fixture.actor = const HostAdminIdentity('alice', personFingerprint);
    await expectLater(callback(), throwsA(isA<RegistryRefusal>()));
    fixture.actor = const HostAdminIdentity('alice', adminFingerprint);
    fixture.admin = false;
    await fixture.registry.refresh();
    await expectLater(callback(), throwsA(isA<RegistryRefusal>()));
    expect(fixture.calls, isEmpty);
  });

  test('refused people are never written and admission carries the selected fingerprint', () async {
    fixture.refusedPerson = true;
    await fixture.registry.refresh();
    await expectLater(admit(), throwsA(isA<RegistryRefusal>()));
    expect(fixture.changes, isEmpty);
    fixture.refusedPerson = false;
    await fixture.registry.refresh();
    await admit();
    final change = fixture.changes.single;
    expect(change.person, 'bob');
    expect(change.fingerprint, personFingerprint);
    expect(change.project, 'demo');
    expect(change.accessRepository, 'git@example.org:team/demo-access.git');
    expect(change.stored.keys, isNot(contains('secret')));
  });

  // Harm: partial sync or a purged account accepted again reads as successful admission.
  test('matching revision without the membership result cannot confirm', () async {
    fixture.people['bob'] = 'purged';
    fixture.applyMembership = false;
    await expectLater(admit(), throwsFormatException);
    expect(settings.hostRegistry('orchard')!.complete, isFalse);
  });

  // Harm: an account is purged without its separate lock and explicit decision.
  test('membership changes are host scoped and purge needs lock and confirmation', () async {
    for (final confirmed in [false, true]) {
      await expectLater(
        access.membership(host: 'orchard', person: 'bob', action: 'purge', confirmed: confirmed),
        throwsA(isA<RegistryRefusal>()),
      );
    }
    await expectLater(
      access.membership(host: 'orchard', person: 'absent', action: 'lock'),
      throwsA(isA<RegistryRefusal>()),
    );
    fixture.people['bob'] = 'locked';
    await access.membership(host: 'orchard', person: 'bob', action: 'lock');
    expect(fixture.changes.single.stored, containsPair('host', 'orchard'));
    fixture.people['bob'] = 'active';
    fixture.applied = registryBefore;
    await access.membership(host: 'orchard', person: 'bob', action: 'unlock');
    expect(fixture.changes.last.action, 'unlock');
    fixture.people['bob'] = 'locked';
    fixture.fail = 'sync';
    fixture.applied = registryBefore;
    await expectLater(
      access.membership(host: 'orchard', person: 'bob', action: 'purge', confirmed: true),
      throwsA(isA<Exception>()),
    );
    fixture.fail = null;
    fixture.people['bob'] = 'purged';
    await access.bringToHost('orchard');
    expect(access.statusFor('orchard')!.people, {'bob': 'purged'});
  });

  // Harm: publication retry rents again or corrupts public SSH service endpoints.
  test('ready card publication retries the same signed card without host sync', () async {
    final card = PreparedHost.read(sshCompletion());
    fixture.fail = 'publish';
    await expectLater(access.publishReady('orchard', card), throwsA(isA<Exception>()));
    fixture.fail = null;
    await access.publishReady('orchard', card);
    expect(fixture.changes, hasLength(1));
    expect(fixture.changes.single.card!.stored, sshCompletion());
    expect(fixture.calls.where((call) => call.startsWith('upload')), isEmpty);
    fixture.registryRevision = registryAfter;
    await fixture.registry.refresh();
    expect(access.notOnHostYet('orchard'), isTrue, reason: 'publishing a card does not confirm host sync');
  });

  // Harm: a credential-bearing or unsafe repository address is persisted in public access state.
  test('admission rejects unsafe repository syntax before filing', () async {
    for (final repository in [
      'git@example.org:repo?token=example',
      r'git@example.org:repo$(id)',
      'https://alice@example.org/repo',
    ]) {
      await expectLater(
        access.admit(host: 'orchard', person: 'bob', project: 'demo', accessRepository: repository),
        throwsFormatException,
      );
    }
    expect(fixture.changes, isEmpty);
  });

  // Harm: an expected upload refusal escapes the action instead of reaching its displayed result.
  test('Bring command delegates refusal handling and refuses a revoked retained callback', () async {
    final machines = Machines(settings, reach: (_) => FakeBackend(const []));
    final runs = HostRuns(machines, hostAccess: access);
    addTearDown(runs.dispose);
    addTearDown(machines.dispose);
    await settings.rememberHostUp(
      'orchard',
      const HostUpRecord(
        host: 'orchard',
        hostName: 'orchard',
        scalewayProject: 'provider',
        account: 'root',
        publicKey: '/keys/public',
        collection: '',
      ).withPreparedHost(PreparedHost.read(sshCompletion())),
    );
    await access.publishReady('orchard', PreparedHost.read(sshCompletion()));
    var attempts = 0;
    String? refusal;
    final command = preparedHostCommands(
      machine: const Machine(
        name: 'orchard',
        kind: 'host',
        hostProject: 'orchard',
        identity: '/keys/private',
        socketPath: '',
      ),
      settings: settings,
      hostRuns: runs,
      bringRegistry: () {
        attempts++;
        unawaited(
          access.bringToHost('orchard').catchError((Object error) {
            refusal = error.toString();
          }),
        );
      },
    ).singleWhere((command) => command.id == 'host.bringRegistry');
    fixture.fail = 'upload';
    command.run();
    await Future<void>.delayed(Duration.zero);
    expect(attempts, 1);
    expect(refusal, contains('registry intake refused'));
    fixture.actor = const HostAdminIdentity('bob', personFingerprint);
    expect(command.run, throwsA(isA<RegistryRefusal>()));
    expect(attempts, 1);
  });

  // Harm: host administration loses its preparation guard or bypasses current permission through a retained command.
  test('host commands retain preparation guards and recheck selected registry actions', () async {
    final machines = Machines(settings, reach: (_) => FakeBackend(const []));
    final runs = HostRuns(machines, hostAccess: access);
    addTearDown(runs.dispose);
    addTearDown(machines.dispose);
    const machine = Machine(name: 'orchard', kind: 'host', hostProject: 'orchard', socketPath: '');
    await settings.rememberHostUp(
      'orchard',
      const HostUpRecord(scalewayProject: 'provider', host: 'orchard', hostName: 'orchard', publicKey: hostKey),
    );
    var prepares = 0;
    final prepare = prepareServerCommand(access: access, open: () => prepares++);
    expect(prepare.home, Home.machineRow);
    prepare.run();
    expect(prepares, 1);
    final actions = <String>[];
    List<Command> commands() => preparedHostCommands(
      machine: machine,
      settings: settings,
      hostRuns: runs,
      open: actions.add,
      showValues: () {},
      bringRegistry: () {},
    );
    expect(commands().map((command) => command.id), [
      'host.adminValues',
      'host.bringRegistry',
      'host.admitAdmin',
      'host.lockAdmin',
      'host.unlockAdmin',
      'host.purgeAdmin',
    ]);
    expect(commands().every((command) => command.home == Home.machineMenu), isTrue);
    expect(
      commands().every((command) => command.unavailable != null),
      isTrue,
      reason: 'no membership command is offered before checked completion',
    );
    await settings.rememberHostUp('orchard', _readyRecord());
    final selected = commands()
        .where(
          (command) =>
              const ['host.admitAdmin', 'host.lockAdmin', 'host.unlockAdmin', 'host.purgeAdmin'].contains(command.id),
        )
        .toList();
    expect(
      selected.every((command) => command.unavailable == null),
      isTrue,
      reason: 'one-click host actions require no per-machine private key',
    );
    for (final command in selected) {
      command.run();
    }
    expect(actions, ['admit', 'lock', 'unlock', 'purge']);
    fixture.actor = const HostAdminIdentity('bob', personFingerprint);
    expect(prepare.run, throwsA(isA<RegistryRefusal>()));
    for (final command in selected) {
      expect(command.run, throwsA(isA<RegistryRefusal>()));
    }
    expect(prepares, 1);
    expect(actions, ['admit', 'lock', 'unlock', 'purge']);
  });

  // Harm: malformed persisted progress silently drops work or selects another host.
  test('pending progress rejects malformed ordering and fields', () {
    final change = HostRegistryChange(id: 'a' * 32, host: 'orchard', action: 'delete-card');
    final valid = HostRegistryProgress(change: change).stored;
    for (final fields in [
      {'revision': 'wrong'},
      {'uploaded': true},
      {'published': true},
      {'confirmed_revision': registryAfter},
      {'revision': registryAfter, 'confirmed_revision': registryAfter, 'published': false},
      {
        'change': HostRegistryChange(id: 'a' * 32, host: 'orchard', action: 'deliver').stored,
        'revision': registryAfter,
        'confirmed_revision': registryAfter,
        'published': true,
        'uploaded': false,
      },
      {
        'change': {...change.stored, 'host': '../other'},
      },
    ]) {
      expect(() => HostRegistryProgress.read({...valid, ...fields}), throwsFormatException);
    }
    expect(HostRegistryProgress.read(valid).change.host, 'orchard');
  });
}

HostUpRecord _readyRecord() => HostUpRecord.fromStored({
  'oneClick': true,
  'host': 'orchard',
  'hostName': 'orchard',
  'scalewayProject': 'provider',
  'account': 'root',
  'publicKey': '/keys/public',
  'collection': '',
  'preparedHost': sshCompletion(),
})!;

class _HoldingStore extends MemorySettingsStore {
  final started = Completer<void>();
  final release = Completer<void>();
  bool hold = true;

  @override
  Future<void> write(Map<String, Object?> values) async {
    if (hold) {
      hold = false;
      started.complete();
      await release.future;
    }
    await super.write(values);
  }
}
