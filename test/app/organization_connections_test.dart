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
  late String hostSays;

  setUp(() {
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
        return turnedAway ? _Turned() : _Master();
      },
      run: (_) async => ProcessResult(0, 0, '', ''),
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

  Future<CardHostConnections> connections(OrganizationView view, {Future<String> Function()? publicKey}) async {
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
    portsBusy = false;
    await made.connect('build');
    expect(made.connected('build'), isTrue);
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
}
