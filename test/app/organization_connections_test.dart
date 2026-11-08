@Tags(['linux'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/host_progress.dart';
import 'package:porelo_frontend/src/app/organization_connections.dart';
import 'package:porelo_frontend/src/app/organization_source.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/app/tunnel.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';
import 'package:porelo_host/porelo_host.dart';

import '../features/support/world.dart' show FakeBackend;
import '../support/organization_fixtures.dart';

const _key = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC';
const _otherHostKey = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD';

/// An ssh master that stays up until it is ended.
class _Master extends Fake implements Process {
  final _exit = Completer<int>();

  /// Whether it was ended, taking every session over it along.
  bool get ended => _exit.isCompleted;

  @override
  Stream<List<int>> get stdout => const Stream.empty();
  @override
  Stream<List<int>> get stderr => const Stream.empty();
  @override
  Future<int> get exitCode => _exit.future;
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    if (!_exit.isCompleted) _exit.complete(255);
    return true;
  }
}

/// An ssh master the host turns away, as it does while it has made no account.
class _Turned extends Fake implements Process {
  @override
  Stream<List<int>> get stdout => const Stream.empty();
  @override
  Stream<List<int>> get stderr => Stream.value(utf8.encode('r6q@host: Permission denied (publickey).\n'));
  @override
  Future<int> get exitCode async => 255;
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => true;
}

/// The host vault, opened at once.
class _Unlocked implements HostUnlocker {
  @override
  Future<HostUnlockResult> unlock(HostCardSsh card, String config) async =>
      const HostUnlockResult(HostUnlockState.unlocked);

  @override
  Future<void> cancel(String host) async {}
}

/// The fixture's organization, with mia's card holding the key the tests connect with.
final _hostOfMia = OrganizationHost(
  name: 'build',
  address: buildHost.address,
  port: buildHost.port,
  hostKey: buildHost.hostKey,
  admins: const ['mia'],
  projects: const ['demo'],
);

OrganizationView _mia({OrganizationHost host = buildHost}) {
  final view = organizationFor('mia', host: host);
  return organizationFor(
    'mia',
    host: host,
    persons: [
      for (final person in view.persons)
        person.login == 'mia'
            ? OrganizationPerson(login: 'mia', standing: CardStanding.trusted, key: HostFiles.signingFingerprint(_key))
            : person,
    ],
  );
}

/// Settings kept in memory, whose saving can be made to fail.
class _Saves extends MemorySettingsStore {
  bool failing = false;

  @override
  Future<void> write(Map<String, Object?> values) async {
    // As the file store does: it says nothing of a write that failed.
    if (failing) return;
    await super.write(values);
  }
}

void main() {
  late Directory folder;
  late List<List<String>> launches;
  late Machines machines;
  late bool portsBusy;
  late List<String> refreshed;
  late _Saves store;
  late bool turnedAway;
  late List<_Master> masters;
  late String hostSays;
  late List<List<String>> ran;

  setUp(() {
    ran = [];
    masters = [];
    turnedAway = false;
    hostSays = '{}';
    folder = Directory.systemTemp.createTempSync('c-');
    portsBusy = false;
    launches = [];
    refreshed = [];
    final tunnels = Tunnels(
      configEnvironment: {'XDG_CONFIG_HOME': folder.path},
      start: (command) async {
        launches.add(command);
        if (turnedAway) return _Turned();
        final master = _Master();
        masters.add(master);
        return master;
      },
      run: (command) async {
        ran.add(command);
        return ProcessResult(0, 0, '', '');
      },
      keyAvailable: (_) async => true,
      portsAvailable: (card) async {
        if (portsBusy) throw HostFilesRefused('Host ${card.name} cannot start: a port is busy.');
      },
      unlocker: _Unlocked(),
      messengerSocket: path.join(folder.path, 'm'),
    );
    store = _Saves();
    final settings = Settings(store);
    machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: tunnels);
    addTearDown(() async {
      await tunnels.dropEverything();
      machines.dispose();
      settings.dispose();
      folder.deleteSync(recursive: true);
    });
  });

  Future<CardHostConnections> connections(
    OrganizationView view, {
    Future<String> Function()? publicKey,
    Future<bool> Function(int port, String host)? forgeProbe,
    DateTime Function()? now,
  }) async {
    final organization = Organization(FixtureOrganization(view));
    addTearDown(organization.dispose);
    await organization.refresh();
    final made = CardHostConnections(
      organization: organization,
      machines: machines,
      publicKey: publicKey ?? () async => _key,
      hostProgress: SshHostProgress(
        run: (program, arguments, {inDirectory, environment = const {}, input}) async {
          refreshed.add(arguments[arguments.length - 2]);
          return (code: 0, out: hostSays, err: '');
        },
      ),
      endpoint: (host) => path.join(folder.path, '$host.socket'),
      forgeProbe: forgeProbe,
      now: now,
    );
    addTearDown(made.dispose);
    return made;
  }

  String config(String host) => path.join(folder.path, 'porelo', 'ssh', '$host.conf');

  // Harm: other programs read what Connect writes; a changed place or shape leaves them with no host.
  test('Connect writes the machine and the files where and as other programs read them', () async {
    final made = await connections(_mia());
    await made.connect('build');
    expect(made.connected('build'), isTrue);
    final machine = machines.all.singleWhere((machine) => machine.name == 'build');
    expect(machine.host, 'build');
    expect(machine.kind, 'host');
    expect(machine.sshConfig, config('build'));
    expect(machine.stored['host'], 'build');
    expect(File(config('build')).existsSync(), isTrue);
    expect(File('${config('build')}.known_hosts').readAsStringSync(), contains(buildHost.hostKey));
    expect(File('${config('build')}.pub').readAsStringSync(), contains(_key));
    expect(File(config('build')).readAsStringSync(), contains('203.0.113.7'));
    expect(launches, hasLength(1));
  });

  // Harm: two projects on one host would hold two connections, which the host's one account cannot tell apart.
  test('two projects on one host are one connection, and a second Connect changes nothing', () async {
    final view = organizationFor(
      'mia',
      moreProjects: const [
        OrganizationProject(name: 'third', admins: ['pat'], members: ['mia'], host: 'build'),
      ],
    );
    final made = await connections(view);
    final before = machines.all.length;
    await made.connect('build');
    await made.connect('build');
    expect(machines.all.length, before + 1);
    expect(launches, hasLength(1));
  });

  // Harm: a person is told nothing of why, or a half-written connection refuses the host's next card.
  test('a connection that does not come up is refused in its words and leaves nothing', () async {
    final made = await connections(_mia());
    portsBusy = true;
    await expectLater(
      made.connect('build'),
      throwsA(isA<OrganizationRefused>().having((refused) => refused.words, 'words', contains('a port is busy'))),
    );
    expect(made.connected('build'), isFalse);
    expect(File(config('build')).existsSync(), isFalse);
    expect(made.lastAttempt('build')!.lines, [
      contains('The organization names build'),
      'Opening the connection.',
      contains('a port is busy'),
      contains('It ended unconnected: '),
    ], reason: 'What it did, kept to be opened.');
    portsBusy = false;
    await made.connect('build');
    expect(made.connected('build'), isTrue);
  });

  // Harm: a person sees last time's protocol, of a Connect that worked, on a machine taken down since.
  test('a disconnect puts the attempt away', () async {
    final made = await connections(_mia());
    await made.connect('build');
    expect(made.lastAttempt('build'), isNotNull);
    await made.disconnect('build');
    expect(made.lastAttempt('build'), isNull);
  });

  // Harm: two presses raise one tunnel twice, and the first's saving drops the second's.
  test('a second Connect while one runs joins it', () async {
    final made = await connections(_mia());
    final first = made.connect('build');
    final attempt = made.lastAttempt('build');
    final second = made.connect('build');
    await Future.wait([first, second]);
    expect(identical(made.lastAttempt('build'), attempt), isTrue);
    expect(attempt!.lines.where((line) => line == 'Opening the connection.'), hasLength(1));
  });

  // Harm: a person connects to an address nobody vouched for.
  // Harm: a host running no forge and no homeserver can never be reached, and its admin is told to enter something.
  test('a host with no forge and no homeserver is connected', () async {
    final plain = OrganizationHost(
      name: 'build',
      address: '203.0.113.7',
      port: 22,
      hostKey: buildHost.hostKey,
      admins: const ['mia'],
    );
    final made = await connections(_mia(host: plain));
    await made.connect('build');
    expect(made.connected('build'), isTrue);
  });

  // Harm: *Open its forge* opens a forwarded address that no longer leads anywhere, or never one at all.
  test("a host's forge address is the card's while connected, and none once disconnected", () async {
    final made = await connections(_mia());
    expect(made.forgeUrl('build'), isNull);
    await made.connect('build');
    expect(made.forgeUrl('build'), 'http://build.localhost:8081/');
    await made.disconnect('build');
    expect(made.forgeUrl('build'), isNull);
  });

  // Harm: a new host offers its token only once connected, and makes the account only with the token: nobody gets in.
  test("a host waiting for its first token keeps its host admin's connection files, to give it", () async {
    final made = await connections(_mia(host: _hostOfMia));
    turnedAway = true;
    hostSays = '{"organization": "waiting-for-token"}';
    await made.connect('build');
    expect(made.connected('build'), isTrue);
    expect(made.up('build'), isFalse);
    expect(File(config('build')).existsSync(), isTrue);
    expect(await made.progress('build'), isA<HostProgress>().having((said) => said.waitsForToken, 'waits', isTrue));

    // With the token given the host lets them in: asked again, the connection itself comes up.
    turnedAway = false;
    hostSays = '{}';
    final before = launches.length;
    await made.connect('build');
    expect(launches.length, greaterThan(before));
    expect(machines.tunnels.of(machines.all.singleWhere((each) => each.name == 'build'))?.state, TunnelState.up);
  });

  // Harm: a machine still reads as waiting after its token was given or its connection let go, and the
  // row then offers neither Connect nor anything that helps.
  test('what a connect found waiting ends with the token, or with the connection', () async {
    final made = await connections(_mia(host: _hostOfMia));
    turnedAway = true;
    hostSays = '{"organization": "waiting-for-token"}';
    await made.connect('build');
    expect(made.waitsForToken('build'), isTrue);
    hostSays = '{}';
    await made.progress('build');
    expect(made.waitsForToken('build'), isFalse, reason: 'the machine says it no longer waits');
    hostSays = '{"organization": "waiting-for-token"}';
    await made.connect('build');
    expect(made.waitsForToken('build'), isTrue);
    await made.disconnect('build');
    expect(made.waitsForToken('build'), isFalse);
  });

  // Harm: right after Prepare the machine has not yet made the person's account, as its first follow runs within five
  // minutes; its turn-away then read as a refusal in red, and the connection was taken down instead of waited for.
  test('a machine just prepared that turns one away is waited for, kept, and not refused', () async {
    final made = await connections(_mia(host: _hostOfMia));
    machines.tunnels.awaitAdmission('build', by: DateTime.now().add(const Duration(minutes: 5)));
    turnedAway = true;
    await made.connect('build');
    expect(made.waitsForAdmission('build'), isTrue);
    expect(made.connected('build'), isTrue, reason: 'kept, so it connects by itself once admitted');
    expect(made.up('build'), isFalse);
    final tunnel = machines.tunnels.of(machines.all.singleWhere((each) => each.name == 'build'))!;
    expect(tunnel.admitting, isTrue);

    turnedAway = false;
    await made.connect('build');
    expect(made.up('build'), isTrue);
    expect(made.waitsForAdmission('build'), isFalse);
  });

  // Harm: a machine just prepared that waits for its first token makes no account however long one waits; shown as a
  // wait for its follow, the person was never offered the token, and after five minutes read a refusal.
  test('a machine just prepared that waits for its token offers the token, during and after the wait', () async {
    final made = await connections(_mia(host: _hostOfMia));
    machines.tunnels.awaitAdmission('build', by: DateTime.now().add(const Duration(minutes: 5)));
    turnedAway = true;
    hostSays = '{"organization": "waiting-for-token"}';
    await made.connect('build');
    expect(made.waitsForToken('build'), isTrue, reason: 'during the wait');
    machines.tunnels.awaitAdmission('build', by: DateTime.now().subtract(const Duration(seconds: 1)));
    await made.connect('build');
    expect(made.waitsForToken('build'), isTrue, reason: 'after the wait');
  });

  // Harm: a connection this computer raises again by itself, turned away by a machine waiting for its first token,
  // never says that the token is what it waits for.
  test('a connection raised again by itself says when the machine waits for its token', () async {
    final made = await connections(_mia(host: _hostOfMia));
    await made.connect('build');
    expect(made.up('build'), isTrue);
    final machine = machines.all.singleWhere((each) => each.name == 'build');
    masters.last.kill();
    await pumpEventQueue();
    turnedAway = true;
    hostSays = '{"organization": "waiting-for-token"}';
    await machines.tunnels.raiseAgainIfItDropped(machine);
    await pumpEventQueue();
    expect(made.waitsForToken('build'), isTrue);
  });

  // Harm: at five minutes a machine that truly refuses the key still reads as one to wait for, while no raise runs to
  // say otherwise.
  test('once the wait has passed, a kept turn-away says the refusal, and says it changed', () async {
    final made = await connections(_mia(host: _hostOfMia));
    machines.tunnels.awaitAdmission('build', by: DateTime.now().add(const Duration(milliseconds: 300)));
    turnedAway = true;
    await made.connect('build');
    final tunnel = machines.tunnels.of(machines.all.singleWhere((each) => each.name == 'build'))!;
    expect(tunnel.admitting, isTrue);
    var told = 0;
    void heard() => told++;
    machines.tunnels.addListener(heard);
    addTearDown(() => machines.tunnels.removeListener(heard));
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(tunnel.admitting, isFalse);
    expect(made.waitsForAdmission('build'), isFalse);
    expect(tunnel.problem, contains('refused this account'));
    expect(told, greaterThan(0), reason: 'whoever shows it hears that it changed');
  });

  // Harm: a key the machine truly refuses is waited for forever, as though the machine had not yet read it.
  test('once the wait for the first follow has passed, a turn-away is a refusal again', () async {
    final made = await connections(_mia(host: _hostOfMia));
    machines.tunnels.awaitAdmission('build', by: DateTime.now().subtract(const Duration(seconds: 1)));
    turnedAway = true;
    await expectLater(
      made.connect('build'),
      throwsA(isA<OrganizationRefused>().having((refused) => refused.words, 'words', contains('refused this account'))),
    );
    expect(made.waitsForAdmission('build'), isFalse);
  });

  // Harm: a host admin of a host that follows, or a member, is told they are connected when the host turned them away.
  test('a host that turns one away and waits for nothing is a refusal, nothing kept', () async {
    final admin = await connections(_mia(host: _hostOfMia));
    turnedAway = true;
    await expectLater(admin.connect('build'), throwsA(isA<OrganizationRefused>()));
    expect(admin.connected('build'), isFalse);
    expect(File(config('build')).existsSync(), isFalse);
  });

  // Harm: root is asked for someone it does not know, and their refusal read as the host's state.
  test('someone who is no host admin is not asked to give a token', () async {
    final member = await connections(_mia());
    turnedAway = true;
    hostSays = '{"organization": "waiting-for-token"}';
    await expectLater(member.connect('build'), throwsA(isA<OrganizationRefused>()));
    expect(member.connected('build'), isFalse);
    expect(refreshed, isEmpty);
  });

  test('a host with no address and host key yet is refused, nothing written', () async {
    final made = await connections(organizationFor('olive'));
    await expectLater(
      made.connect('spare'),
      throwsA(isA<OrganizationRefused>().having((refused) => refused.words, 'words', contains('has not entered'))),
    );
    expect(launches, isEmpty);
    expect(File(config('spare')).existsSync(), isFalse);
  });

  // Harm: an unreadable key shows a stack trace, or a key's text in a message.
  test('a key that cannot be read is said without its words', () async {
    final made = await connections(_mia(), publicKey: () async => throw Exception('private detail'));
    await expectLater(
      made.connect('build'),
      throwsA(isA<OrganizationRefused>().having((refused) => refused.words, 'words', isNot(contains('private')))),
    );
  });

  // Harm: the row says connected and offers nothing while the connection still uses the old address or key.
  group('a connection the organization has moved past', () {
    late Organization organization;
    late CardHostConnections made;

    setUp(() async {
      organization = Organization(FixtureOrganization(_mia()));
      addTearDown(organization.dispose);
      await organization.refresh();
      made = CardHostConnections(
        organization: organization,
        machines: machines,
        publicKey: () async => _key,
        endpoint: (host) => path.join(folder.path, '$host.socket'),
      );
      addTearDown(made.dispose);
      await made.connect('build');
    });

    Future<void> reads(OrganizationView view) async {
      (organization.source as FixtureOrganization).view = view;
      await organization.refresh();
    }

    test('a corrected address offers Connect again', () async {
      expect(made.connected('build'), isTrue);
      await reads(
        _mia(
          host: const OrganizationHost(
            name: 'build',
            address: '203.0.113.99',
            port: 22,
            hostKey: _otherHostKey,
            webPort: 8081,
            gitPort: 8082,
            matrixPort: 8083,
            admins: ['hana'],
            projects: ['demo'],
          ),
        ),
      );
      expect(made.connected('build'), isFalse);
    });

    // Harm: a command for the host goes to the address the organization has left.
    test('the old connection is not used to ask the host', () async {
      await reads(
        _mia(
          host: const OrganizationHost(
            name: 'build',
            address: '203.0.113.99',
            port: 22,
            hostKey: _otherHostKey,
            webPort: 8081,
            gitPort: 8082,
            matrixPort: 8083,
            admins: ['hana'],
            projects: ['demo'],
          ),
        ),
      );
      await expectLater(made.refresh('build'), throwsA(isA<OrganizationRefused>()));
      await expectLater(made.progress('build'), throwsA(isA<OrganizationRefused>()));
    });

    test('a changed key of mine offers Connect again', () async {
      await reads(
        organizationFor(
          'mia',
          persons: const [OrganizationPerson(login: 'mia', standing: CardStanding.trusted, key: 'SHA256:anotherkey')],
        ),
      );
      expect(made.connected('build'), isFalse);
    });
  });

  // Harm: an offline copy of the organization pins an address or host key it has since replaced.
  test('an organization that could not be read now makes no new connection', () async {
    final made = await connections(organizationFor('mia', stale: true));
    await expectLater(made.connect('build'), throwsA(isA<OrganizationRefused>()));
    expect(launches, isEmpty);
    expect(made.connected('build'), isFalse);
  });

  // Harm: a save that fails spins the button for good, with a tunnel up that nothing here says is up.
  test('a connection that cannot be saved is said, taken down, and can be tried again', () async {
    final made = await connections(_mia());
    store.failing = true;
    await expectLater(made.connect('build'), throwsA(isA<OrganizationRefused>()));
    expect(made.connected('build'), isFalse);

    store.failing = false;
    await made.connect('build');
    expect(made.connected('build'), isTrue);
  });

  // Harm: an address or host key the admin corrected stays pinned at the old one for good.
  test('a changed host key replaces the connection', () async {
    final organization = Organization(FixtureOrganization(_mia()));
    addTearDown(organization.dispose);
    await organization.refresh();
    final made = CardHostConnections(
      organization: organization,
      machines: machines,
      publicKey: () async => _key,
      endpoint: (host) => path.join(folder.path, '$host.socket'),
    );
    addTearDown(made.dispose);
    await made.connect('build');
    (organization.source as FixtureOrganization).view = _mia(
      host: const OrganizationHost(
        name: 'build',
        address: '203.0.113.7',
        port: 22,
        hostKey: _otherHostKey,
        webPort: 8081,
        gitPort: 8082,
        matrixPort: 8083,
        admins: ['hana'],
        projects: ['demo'],
      ),
    );
    await organization.refresh();
    await made.connect('build');
    expect(machines.all.where((machine) => machine.name == 'build'), hasLength(1));
    expect(File('${config('build')}.known_hosts').readAsStringSync(), contains(_otherHostKey));
    expect(File('${config('build')}.known_hosts').readAsStringSync(), isNot(contains(buildHost.hostKey)));
  });

  // Harm: the plugin, seeing this computer's entry marked, adds its own beside it.
  test('this computer is never marked as disconnected', () async {
    final here = machines.all.singleWhere((machine) => machine.isThisComputer);
    await machines.disconnect(here);
    expect(machines.all.singleWhere((machine) => machine.isThisComputer).disconnected, isFalse);
  });

  // Harm: a disconnected host keeps its pin and refuses the next card.
  // Harm: a person's decision to stay away is undone by the next notice or restart, or Connect cannot bring it back.
  test('Disconnect keeps the entry, marked, and only Connect brings it back', () async {
    final made = await connections(_mia());
    await made.connect('build');
    await made.disconnect('build');
    expect(made.connected('build'), isFalse);
    final kept = machines.all.singleWhere((machine) => machine.name == 'build');
    expect(kept.disconnected, isTrue);
    expect(Machine.fromStored(kept.stored).disconnected, isTrue, reason: 'it survives a restart');
    expect(machines.tunnels.of(kept)?.state, isNot(TunnelState.up));
    await machines.raiseAgainIfNeeded(kept);
    expect(machines.tunnels.of(kept)?.state, isNot(TunnelState.up), reason: 'nothing raises it again');
    await made.connect('build');
    expect(made.connected('build'), isTrue);
    expect(machines.all.where((machine) => machine.name == 'build'), hasLength(1));
  });

  // Harm: a raise queued meanwhile runs without its configuration and pins.
  test('a raise queued while a tunnel is taken down keeps the files it published', () async {
    final made = await connections(_mia());
    await made.connect('build');
    final machine = machines.all.singleWhere((machine) => machine.name == 'build');
    // A probe holds the master, so the drop ends only once it lets go; a raise queued meanwhile takes the tunnel.
    final probe = machines.tunnels.holdForTrial(machine);
    expect(await probe.ready, isTrue);
    final down = machines.tunnels.dropAndUnpublish(machine);
    await pumpEventQueue();
    expect(await machines.tunnels.raiseFor(machine), isTrue);
    await probe.release();
    await down;
    for (final file in [config('build'), '${config('build')}.known_hosts', '${config('build')}.pub']) {
      expect(File(file).existsSync(), isTrue, reason: file);
    }
  });

  // Harm: a refresh reaches a machine this person is not connected to.
  test('Refresh asks the connected machine, and asks for Connect first otherwise', () async {
    final made = await connections(_mia());
    await expectLater(made.refresh('build'), throwsA(isA<OrganizationRefused>()));
    expect(refreshed, isEmpty);
    await made.connect('build');
    await made.refresh('build');
    expect(refreshed, ['root@build']);
  });

  // Harm: a forward to a forge that stopped answering is never noticed, or another port than the card's is asked.
  test("the forge is asked through the card's own port, and only while the connection is up", () async {
    final asked = <(int, String)>[];
    final made = await connections(
      _mia(),
      forgeProbe: (port, host) async {
        asked.add((port, host));
        return false;
      },
    );
    expect(await made.forgeAnswers('build'), isNull, reason: 'nothing to ask without a connection');
    await made.connect('build');
    expect(await made.forgeAnswers('build'), isFalse);
    expect(asked, [(8081, 'build')]);
  });

  // Harm: a forward that stopped answering stays as it is, and Open its forge opens the same empty reply.
  // Harm: raising the forge's forward anew cuts the person's terminals, daemon link and vault over the same master.
  test("raising the forward anew re-adds only the forge's forward on the live master", () async {
    final made = await connections(_mia());
    await made.connect('build');
    final tunnel = machines.tunnels.of(machines.all.singleWhere((machine) => machine.name == 'build'));
    ran.clear();
    await made.raiseForwardAnew('build');
    expect(launches, hasLength(1), reason: 'no new master');
    expect(masters.single.ended, isFalse, reason: 'the master and every session over it stay');
    expect(
      identical(machines.tunnels.of(machines.all.singleWhere((machine) => machine.name == 'build')), tunnel),
      isTrue,
      reason: 'the tunnel was not dropped',
    );
    expect(made.up('build'), isTrue);
    const forward = ['-L', '127.0.0.1:8081:/run/porelo-forge/web.sock', 'build'];
    expect(
      [for (final command in ran) command.sublist(1)],
      [
        ['-F', config('build'), '-O', 'cancel', ...forward],
        ['-F', config('build'), '-O', 'forward', ...forward],
      ],
    );
  });

  // Harm: every click raises the forward again while the cause is on the host.
  test('a second raise within half a minute raises nothing and says the cause is on the host', () async {
    var now = DateTime.utc(2026, 11, 8, 20);
    final made = await connections(_mia(), now: () => now);
    await made.connect('build');
    ran.clear();
    await made.raiseForwardAnew('build');
    expect(ran, hasLength(2));
    now = now.add(const Duration(seconds: 10));
    await expectLater(
      made.raiseForwardAnew('build'),
      throwsA(isA<OrganizationRefused>().having((refused) => refused.words, 'words', contains('on the host'))),
    );
    expect(ran, hasLength(2), reason: 'raised once');
    now = now.add(const Duration(seconds: 30));
    await made.raiseForwardAnew('build');
    expect(ran, hasLength(4));
  });

  // Harm: a raise asked of a machine this person is not connected to makes a connection nobody asked for.
  test('a forward is raised anew only for a connected machine', () async {
    final made = await connections(_mia());
    await expectLater(made.raiseForwardAnew('build'), throwsA(isA<OrganizationRefused>()));
    expect(launches, isEmpty);
  });

  group("a forge's answer through a forward", () {
    Future<int> serving(void Function(Socket socket) answer) async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      server.listen(answer);
      return server.port;
    }

    // Harm: a forge that answers is taken for dead and its forward torn down.
    test('a status line is an answer', () async {
      final port = await serving((socket) {
        socket.listen((_) {
          socket.write('HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n');
          unawaited(socket.close());
        });
      });
      expect(await forgeAnswersAt(port), isTrue);
    });

    // Harm: the browser's empty reply is taken for a working forge.
    test('an empty reply is none', () async {
      final port = await serving((socket) => socket.destroy());
      expect(await forgeAnswersAt(port), isFalse);
    });

    // Harm: a forge that never answers holds the page forever.
    test('silence until the deadline is none', () async {
      final port = await serving((socket) => socket.listen((_) {}));
      expect(await forgeAnswersAt(port, deadline: const Duration(milliseconds: 200)), isFalse);
    });

    // Harm: a forge slow at every step holds the page for a deadline per step.
    test('one deadline holds for connecting, asking and the first byte together', () async {
      final port = await serving((socket) {
        socket.listen((_) {
          Timer(const Duration(milliseconds: 200), () {
            socket.write('HTTP/1.1 200 OK\r\n\r\n');
            unawaited(socket.close());
          });
        });
      });
      final answered = await forgeAnswersAt(
        port,
        deadline: const Duration(milliseconds: 300),
        connect: (port) async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return Socket.connect(InternetAddress.loopbackIPv4, port);
        },
      );
      expect(answered, isFalse, reason: '400 ms in all is past one deadline of 300');
    });

    // Harm: a forward that is gone is taken for a forge that answers.
    test('nothing listening is none', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      await server.close();
      expect(await forgeAnswersAt(port), isFalse);
    });
  });
}
