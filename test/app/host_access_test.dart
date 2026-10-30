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

  // Harm: restarting repeats a signed admission or uploads an already accepted bundle.
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
      if (failure == 'sync') expect(fixture.calls.where((call) => call.startsWith('upload')), hasLength(1));
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
        tresor: '',
        folder: null,
        signingKey: '',
        identity: '/keys/private',
        publicKey: '/keys/public',
        collection: '',
        vpnPeerPublicKey: '',
        vpnPeerAddress: '',
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
        tresor: '',
        folder: null,
        signingKey: '',
        identity: '/keys/private',
        publicKey: '/keys/public',
        collection: '',
        vpnPeerPublicKey: '',
        vpnPeerAddress: '',
      ).withPreparedHost(PreparedHost.read(sshCompletion())),
    );
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
