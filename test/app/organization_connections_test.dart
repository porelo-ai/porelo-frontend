@Tags(['linux'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:porelo_frontend/client.dart' show Project;
import 'package:porelo_frontend/src/app/desk.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/host_follow.dart';
import 'package:porelo_frontend/src/app/host_progress.dart';
import 'package:porelo_frontend/src/app/organization_connections.dart';
import 'package:porelo_frontend/src/app/person_only_relay.dart';
import 'package:porelo_frontend/src/app/organization_source.dart';
import 'package:porelo_frontend/src/app/run_here.dart';
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
/// The daemon's relay stand-in: answers GetInfo as a Porelo daemon does, on the relay's own byte streams.
class _Relay extends Fake implements Process {
  final _out = StreamController<List<int>>();
  final _exit = Completer<int>();
  late final IOSink _in = IOSink(
    _Calls((call) {
      if (!call.contains(0) || _out.isClosed) return;
      final info = {
        'parameters': {
          'product': 'porelo',
          'version': '1',
          'vendor': 'fuin',
          'interfaces': ['org.fuin.porelo.Tasks1'],
        },
      };
      _out.add(utf8.encode('${jsonEncode(info)}\x00'));
    }),
  );

  @override
  IOSink get stdin => _in;
  @override
  Stream<List<int>> get stdout => _out.stream;
  @override
  Stream<List<int>> get stderr => const Stream.empty();
  @override
  Future<int> get exitCode => _exit.future;
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    unawaited(_out.close());
    if (!_exit.isCompleted) _exit.complete(-1);
    return true;
  }
}

class _Calls implements StreamConsumer<List<int>> {
  _Calls(this.heard);
  final void Function(List<int>) heard;

  @override
  Future<void> addStream(Stream<List<int>> stream) => stream.forEach(heard);
  @override
  Future<void> close() async {}
}

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

OrganizationView _mia({OrganizationHost host = buildHost, bool stale = false}) {
  final view = organizationFor('mia', host: host);
  return organizationFor(
    'mia',
    host: host,
    stale: stale,
    persons: [
      for (final person in view.persons)
        person.login == 'mia'
            ? OrganizationPerson(login: 'mia', standing: CardStanding.trusted, key: HostFiles.signingFingerprint(_key))
            : person,
    ],
  );
}

/// Hands the organization as Porelo kept it at once, then answers its check when the test lets it.
class _KeptFirst extends FixtureOrganization implements ReadsKeptFirst {
  _KeptFirst(super.view);

  final check = Completer<void>();

  @override
  Future<OrganizationView> readKeptFirst(void Function(OrganizationView kept) kept) async {
    kept(_mia(stale: true));
    await check.future;
    return read();
  }

  @override
  Future<ProjectView> readProjectKeptFirst(String project, void Function(ProjectView kept) kept) =>
      readProject(project);
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

  /// What the host's status read exits with, and says on its error stream then.
  late ({int code, String err}) hostEnds;

  /// Holds the host's answer to a read until the test lets it.
  late Completer<void>? holdAnswer;
  late List<List<String>> ran;
  late bool forwardRefused;
  late Completer<void>? holdStart;
  late FakeBackend daemon;

  setUp(() {
    daemon = FakeBackend(const []);
    ran = [];
    forwardRefused = false;
    holdStart = null;
    holdAnswer = null;
    masters = [];
    turnedAway = false;
    hostSays = '{}';
    hostEnds = (code: 0, err: '');
    folder = Directory.systemTemp.createTempSync('c-');
    // This account's alone, as the runtime directory is: the one place a socket the window made is later removed.
    Process.runSync('chmod', <String>['700', folder.path]);
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
        if (forwardRefused && command.contains('forward')) {
          return ProcessResult(0, 255, '', 'Port forwarding failed: [::1]:8081 is in use');
        }
        return ProcessResult(0, 0, '', '');
      },
      keyAvailable: (_) async => true,
      portsAvailable: (card) async {
        await holdStart?.future;
        if (portsBusy) throw HostFilesRefused('Host ${card.name} cannot start: a port is busy.');
      },
      unlocker: _Unlocked(),
      messengerSocket: path.join(folder.path, 'm'),
    );
    store = _Saves();
    final settings = Settings(store);
    machines = Machines(settings, reach: (_) => daemon, tunnels: tunnels);
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
    SshHostFollow? hostFollow,
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
          await holdAnswer?.future;
          return (code: hostEnds.code, out: hostSays, err: hostEnds.err);
        },
      ),
      endpoint: (host) => path.join(folder.path, '$host.socket'),
      hostFollow: hostFollow,
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

  // Harm: the host no longer has the program the row asked, so every project read as one that cannot say how it
  // stands with central, and work waiting there was never said; or the person's daemon on the host is passed over.
  test(
    "a project's central state is the person's own daemon's answer on the host, not a program run as root",
    () async {
      daemon.theProjectsItHas = [
        Project.from(const <String, dynamic>{
          'name': 'demo',
          'repositories': [
            {
              'name': 'api',
              'central': 'ahead',
              'ahead': 2,
              'aheadMeasured': '2026-11-10T20:00:00Z',
              'carriedHere': true,
            },
            {'name': 'docs', 'central': 'no-central', 'carriedHere': true},
            {'name': 'gone', 'central': 'ahead', 'ahead': 9, 'carriedHere': false},
          ],
        }),
      ];
      final made = await connections(_mia());
      await made.connect('build');
      final state = await made.central('build', 'demo');
      expect(refreshed, isEmpty, reason: 'nothing was run as root on the host');
      expect(state.repositories, [(state: 'ahead', commits: 2)]);
      expect(state.readAt, DateTime.utc(2026, 11, 10, 20));
      expect(state.words('GitHub'), '2 approved commits not yet at GitHub');
      expect((await made.central('build', 'unknown')).cannotSay, isTrue);
    },
  );

  // Harm: the page asks as soon as the connection is up, before the daemon's connection over it has opened; Porelo's
  // own backend then throws an error nothing catches, and the project stays as cannot say for good.
  test("central waits for the daemon's connection to open, and an error of the backend cannot say", () async {
    daemon.theProjectsItHas = [
      Project.from(const <String, dynamic>{
        'name': 'demo',
        'repositories': [
          {'name': 'api', 'central': 'ahead', 'ahead': 1, 'carriedHere': true},
        ],
      }),
    ];
    final opened = Completer<void>();
    daemon.answersLater = opened;
    // As Porelo's own backend does before open() answered.
    daemon.listingProjectsFails = StateError('open() has not answered yet');
    final made = await connections(_mia());
    await made.connect('build');
    final asked = made.central('build', 'demo');
    daemon.listingProjectsFails = null;
    opened.complete();
    expect((await asked).repositories, [(state: 'ahead', commits: 1)]);

    // Once the machine's own reread after connecting is over, so that only this ask meets the error.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    daemon.listingProjectsFails = StateError('open() has not answered yet');
    final failed = await made.central('build', 'demo');
    daemon.listingProjectsFails = null;
    expect(failed.cannotSay, isTrue);
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

  // Harm: Connect on Windows asks for a local unix socket, which Windows has no runtime folder for, and fails.
  test('Connect on Windows lists the host with no local socket, its daemon reached through the relay', () async {
    final before = desk;
    final started = <List<String>>[];
    final environment = {'SystemRoot': r'C:\Windows', 'APPDATA': folder.path};
    desk = Desk.of('windows', environment);
    addTearDown(() => desk = before);
    final tunnels = Tunnels(
      configEnvironment: environment,
      start: (command) async {
        started.add(command);
        return _Relay();
      },
      keyAvailable: (_) async => true,
      portsAvailable: (_) async {},
      unlocker: _Unlocked(),
      writer: _Unprotected(),
    );
    final settings = Settings(_Saves());
    final windows = Machines(settings, reach: (_) => daemon, tunnels: tunnels);
    addTearDown(() async {
      await tunnels.dropEverything();
      windows.dispose();
      settings.dispose();
    });
    final organization = Organization(
      FixtureOrganization(
        _mia(
          host: OrganizationHost(
            name: 'build',
            address: '203.0.113.7',
            port: 22,
            hostKey: buildHost.hostKey,
            admins: const ['mia'],
          ),
        ),
      ),
    );
    addTearDown(organization.dispose);
    await organization.refresh();
    final made = CardHostConnections(
      organization: organization,
      machines: windows,
      publicKey: () async => _key,
      // As Windows answers asking for a runtime folder's unix socket.
      endpoint: (host) => throw const ProcessException('id', ['-u'], 'The system cannot find the file specified.'),
    );
    addTearDown(made.dispose);

    await made.connect('build');

    expect(made.connected('build'), isTrue);
    final machine = windows.all.singleWhere((machine) => machine.name == 'build');
    expect(machine.socketPath, isEmpty);
    expect(machine.relay?.command, containsAllInOrder(['-F', machine.sshConfig]));
    expect(started, [machine.relay?.command], reason: 'the daemon was asked through the relay, and nothing else ran');
    expect(File(machine.sshConfig).readAsStringSync(), contains('203.0.113.7'), reason: 'the relay reads it');
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

  // Harm: a machine waiting for its first token goes unsaid on its page once its connection is let go, or once a read
  // of it fails, so its Machine Admin waits for an admission that never comes.
  test('the token a connect heard waited for outlasts the connection and a failed read, until it comes up', () async {
    final made = await connections(_mia(host: _hostOfMia));
    turnedAway = true;
    hostSays = '{"organization": "waiting-for-token"}';
    await made.connect('build');
    expect(made.tokenWaitHeard('build'), isNotNull);
    await made.disconnect('build');
    expect(made.tokenWaitHeard('build'), isNotNull, reason: 'the last word this window has of it');
    hostEnds = (code: 127, err: 'env: /usr/sbin/porelo-host: No such file or directory');
    await expectLater(made.connect('build'), throwsA(isA<OrganizationRefused>()));
    expect(made.tokenWaitHeard('build'), isNotNull, reason: 'a read that failed says nothing of the token');
    hostEnds = (code: 0, err: '');
    turnedAway = false;
    hostSays = '{}';
    await made.connect('build');
    expect(made.tokenWaitHeard('build'), isNull, reason: 'it let this person in, so it had its token');
  });

  /// [_hostOfMia] with [admins] and, where given, another name, address and host key.
  OrganizationHost hostOfMia({
    String name = 'build',
    String? address,
    String? hostKey,
    List<String> admins = const ['mia'],
  }) => OrganizationHost(
    name: name,
    address: address ?? _hostOfMia.address,
    port: _hostOfMia.port,
    hostKey: hostKey ?? _hostOfMia.hostKey,
    admins: admins,
    projects: const ['demo'],
  );

  Future<void> reads(CardHostConnections made, OrganizationView view) async {
    (made.organization.source as FixtureOrganization).view = view;
    await made.organization.refresh();
  }

  /// Connects to a host that waits for its first token, and reads it once as its Machine Admin.
  Future<CardHostConnections> waitingForItsToken() async {
    final made = await connections(_mia(host: _hostOfMia));
    turnedAway = true;
    hostSays = '{"organization": "waiting-for-token"}';
    await made.connect('build');
    await made.progress('build');
    expect(made.waitsForToken('build'), isTrue);
    expect(made.heard('build')?.waitsForToken, isTrue);
    return made;
  }

  // Harm: once the machine took the token, its row, chip and page go on offering the token, because the read that
  // would say otherwise failed or has not run yet.
  test('taking the token ends every word of the wait, the connection\'s and the read\'s', () async {
    final made = await waitingForItsToken();
    made.hearTokenWait('build', waits: false);
    expect(made.waitsForToken('build'), isFalse, reason: "the row's wait");
    expect(made.heard('build')?.waitsForToken ?? false, isFalse, reason: "the read's wait");
    expect(made.tokenWaitHeard('build'), isNull);
  });

  // Harm: a Connect that comes up proves the machine took its token, yet the read heard before still says it waits.
  test('a Connect that comes up ends the wait a read heard, with no read since', () async {
    final made = await waitingForItsToken();
    turnedAway = false;
    await made.connect('build');
    expect(made.up('build'), isTrue);
    expect(made.heard('build')?.waitsForToken ?? false, isFalse);
  });

  // Harm: a connection that came up by itself still reads as waiting for the token on the machine's page.
  test('a connection raised again by itself that comes up ends the wait', () async {
    final made = await waitingForItsToken();
    final machine = machines.all.singleWhere((each) => each.name == 'build');
    turnedAway = false;
    await machines.tunnels.raiseAgainIfItDropped(machine);
    await pumpEventQueue();
    expect(made.up('build'), isTrue);
    expect(made.tokenWaitHeard('build'), isNull);
    expect(made.heard('build')?.waitsForToken ?? false, isFalse);
  });

  // Harm: the setup's word that the machine waits outlives a Connect that finds it up already.
  test('a Connect that finds the connection up already ends the wait', () async {
    final made = await connections(_mia(host: _hostOfMia));
    await made.connect('build');
    made.hearTokenWait('build', waits: true);
    await made.connect('build');
    expect(made.tokenWaitHeard('build'), isNull);
  });

  // Harm: a machine of the same name at another address, or a new one after the old was taken out, is said to wait
  // for a token because the old server did.
  test('a wait is no word of a machine removed or moved since', () async {
    final made = await connections(_mia(host: _hostOfMia));
    made.hearTokenWait('build', waits: true);
    await reads(made, _mia(host: hostOfMia(name: 'gone')));
    expect(made.tokenWaitHeard('build'), isNull, reason: 'removed');
    await reads(made, _mia(host: _hostOfMia));
    made.hearTokenWait('build', waits: true);
    await reads(
      made,
      _mia(
        host: hostOfMia(address: '203.0.113.99', hostKey: _otherHostKey),
      ),
    );
    expect(made.tokenWaitHeard('build'), isNull, reason: 'moved');
  });

  // Harm: root's word to someone who stopped being the Machine Admin while it was asked is kept as theirs.
  test('a wait heard after the role was taken meanwhile is not kept', () async {
    final made = await connections(_mia(host: _hostOfMia));
    turnedAway = true;
    hostSays = '{"organization": "waiting-for-token"}';
    final answer = holdAnswer = Completer<void>();
    final connecting = made.connect('build');
    while (refreshed.isEmpty) {
      await pumpEventQueue();
    }
    await reads(made, _mia(host: hostOfMia(admins: const ['hana'])));
    answer.complete();
    try {
      await connecting;
    } on OrganizationRefused {
      // Turned away with no wait of theirs to say.
    }
    expect(made.tokenWaitHeard('build'), isNull);
    expect(made.waitsForToken('build'), isFalse);
  });

  // Harm: someone no longer the machine's admin is offered its token on the row.
  test('the wait a Connect heard is dropped with the Machine Admin role', () async {
    final made = await waitingForItsToken();
    final notAdmin = _mia(host: hostOfMia(admins: const ['hana']));
    await reads(made, notAdmin);
    made.askOnce(notAdmin);
    expect(made.waitsForToken('build'), isFalse);
    expect(made.tokenWaitHeard('build'), isNull);
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

  /// A connection to build kept while the machine just prepared has not yet made the account, its own raises over,
  /// and the next raise held before it publishes anything: the hold to let go of, and the second *Connect*.
  Future<(Completer<void>, Future<void>)> raisedAgainAndHeld(CardHostConnections made, {void Function()? then}) async {
    machines.tunnels.awaitAdmission('build', by: DateTime.now().add(const Duration(minutes: 5)));
    turnedAway = true;
    await made.connect('build');
    expect(made.up('build'), isFalse, reason: 'kept while the machine makes the account');
    await machines.of(machines.all.singleWhere((each) => each.name == 'build')).untilAsked();
    await pumpEventQueue();
    turnedAway = false;
    then?.call();
    final gate = holdStart = Completer<void>();
    final again = made.connect('build');
    await pumpEventQueue();
    return (gate, again);
  }

  // Harm: a machine just prepared vanished from My machines while Connect raised it anew, with its files taken down
  // and its page saying the connection was down; the person took it for lost, or prepared it a second time.
  test('a machine just prepared stays listed, its files and its wait kept, while Connect raises it anew', () async {
    final made = await connections(_mia(host: _hostOfMia));
    final listed = <bool>[];
    void read() => listed.add(machines.all.any((each) => each.name == 'build'));
    addTearDown(() => machines.removeListener(read));
    final (gate, again) = await raisedAgainAndHeld(made, then: () => machines.addListener(read));
    final launched = launches.length;
    read();
    expect(listed.last, isTrue, reason: 'listed while it is raised anew');
    expect(File(config('build')).existsSync(), isTrue, reason: 'its files stay while it is raised anew');
    expect(made.waitsForAdmission('build'), isTrue, reason: 'still the wait for its follow, not a connection down');
    gate.complete();
    await again;
    read();
    expect(made.up('build'), isTrue);
    expect(launches, hasLength(launched + 1), reason: 'raised once by Connect, and not again behind it');
    expect(masters.single.ended, isFalse);
    expect(listed, isNot(contains(false)), reason: 'listed on every change while it was raised anew');
  });

  // Harm: a machine let go while Connect raised it was connected again behind the person's back.
  test('a disconnect while Connect raises it anew stands', () async {
    final made = await connections(_mia(host: _hostOfMia));
    final (gate, again) = await raisedAgainAndHeld(made);
    final off = made.disconnect('build');
    await pumpEventQueue();
    gate.complete();
    await again;
    await off;
    await pumpEventQueue();
    final machine = machines.all.singleWhere((each) => each.name == 'build');
    expect(machine.disconnected, isTrue);
    expect(machines.tunnels.of(machine)?.state, isNot(TunnelState.up));
  });

  // Harm: a refused raise left its connection's files behind, which other programs read as a machine to reach.
  test('a machine just prepared whose raise anew is refused is taken off, its files with it', () async {
    final made = await connections(_mia(host: _hostOfMia));
    final (gate, again) = await raisedAgainAndHeld(made);
    turnedAway = true;
    machines.tunnels.awaitAdmission('build', by: DateTime.now().subtract(const Duration(seconds: 1)));
    gate.complete();
    await expectLater(again, throwsA(isA<OrganizationRefused>()));
    await pumpEventQueue();
    expect(machines.all.where((each) => each.name == 'build'), isEmpty);
    expect(File(config('build')).existsSync(), isFalse);
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
    // Far enough ahead that the connect itself is still inside the wait on a busy runner (300 ms was not, run
    // 42572008122); the test then waits until it has passed, however long the connect took.
    final by = DateTime.now().add(const Duration(seconds: 3));
    machines.tunnels.awaitAdmission('build', by: by);
    turnedAway = true;
    await made.connect('build');
    final tunnel = machines.tunnels.of(machines.all.singleWhere((each) => each.name == 'build'))!;
    expect(tunnel.admitting, isTrue);
    var told = 0;
    void heard() => told++;
    machines.tunnels.addListener(heard);
    addTearDown(() => machines.tunnels.removeListener(heard));
    await Future<void>.delayed(by.difference(DateTime.now()) + const Duration(milliseconds: 300));
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

  // Harm: Connect, pressed while the state Porelo kept is shown and its check runs, is refused for good.
  test('a Connect while the kept organization is checked waits for the check, then connects', () async {
    final source = _KeptFirst(_mia());
    final organization = Organization(source);
    addTearDown(organization.dispose);
    final reading = organization.refresh();
    await pumpEventQueue();
    expect(organization.view?.stale, isTrue, reason: 'the kept state is shown while its check runs');
    final made = CardHostConnections(
      organization: organization,
      machines: machines,
      publicKey: () async => _key,
      hostProgress: SshHostProgress(
        run: (program, arguments, {inDirectory, environment = const {}, input}) async => (code: 0, out: '{}', err: ''),
      ),
      endpoint: (host) => path.join(folder.path, '$host.socket'),
    );
    addTearDown(made.dispose);
    final connecting = made.connect('build');
    await pumpEventQueue();
    expect(launches, isEmpty, reason: 'nothing is raised from the kept state');
    source.check.complete();
    await reading;
    await connecting;
    expect(made.connected('build'), isTrue);
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

  // Harm: the host is asked over and over whether it offers the start, or a host without it is offered it again.
  test('Read the organization now asks once whether the host offers it, and a host without it is greyed', () async {
    final asked = <String>[];
    var follows = 69;
    final made = await connections(
      _mia(),
      hostFollow: SshHostFollow(
        run: (program, arguments, {inDirectory, environment = const {}, input}) async {
          asked.add(arguments.last);
          if (arguments.last.contains('--help')) return (code: 0, out: '', err: '');
          return (code: follows, out: '', err: 'porelo: host follow is unavailable; update the host program\n');
        },
      ),
    );
    expect(made.whyNotFollowNow('build'), startsWith('Connect first'));
    await expectLater(made.followNow('build'), throwsA(isA<OrganizationRefused>()));
    expect(asked, isEmpty, reason: 'nothing runs without a connection');
    await made.connect('build');
    expect(made.whyNotFollowNow('build'), 'Asking build whether it offers this…');
    await pumpEventQueue();
    expect(made.whyNotFollowNow('build'), isNull);
    expect(made.whyNotFollowNow('build'), isNull);
    expect(asked, hasLength(1), reason: 'asked once per connection');
    await expectLater(made.followNow('build'), throwsA(isA<HostFollowUnavailable>()));
    expect(made.whyNotFollowNow('build'), 'porelo: host follow is unavailable; update the host program');
    final before = asked.length;
    await expectLater(made.followNow('build'), throwsA(isA<HostFollowUnavailable>()));
    expect(asked, hasLength(before), reason: 'a greyed host runs nothing');
    follows = 0;
    await made.disconnect('build');
    await made.connect('build');
    made.whyNotFollowNow('build');
    await pumpEventQueue();
    expect(made.whyNotFollowNow('build'), isNull, reason: 'a connection made anew asks again');
  });

  // Harm: a host whose Porelo knows no start is asked to run it, when the start is pressed before it was asked.
  test('Read the organization now asks an unasked host first, and runs nothing on one without it', () async {
    final asked = <String>[];
    final made = await connections(
      _mia(),
      hostFollow: SshHostFollow(
        run: (program, arguments, {inDirectory, environment = const {}, input}) async {
          asked.add(arguments.last);
          return (code: 2, out: '', err: "Unmatched argument at index 1: 'follow'\n");
        },
      ),
    );
    await made.connect('build');
    await expectLater(made.followNow('build'), throwsA(isA<HostFollowUnavailable>()));
    expect(asked, [contains('--help')], reason: 'only asked, never started');
    expect(made.whyNotFollowNow('build'), contains('offers no start'));
  });

  // Harm: what an earlier connection was told greys, or frees, the action on the next one.
  test('an answer to an earlier connection, or one heard while it was down, is not kept', () async {
    final answers = <Completer<Ran>>[];
    final made = await connections(
      _mia(),
      hostFollow: SshHostFollow(
        run: (program, arguments, {inDirectory, environment = const {}, input}) {
          final answer = Completer<Ran>();
          answers.add(answer);
          return answer.future;
        },
      ),
    );
    await made.connect('build');
    made.whyNotFollowNow('build');
    expect(answers, hasLength(1));
    await made.disconnect('build');
    await made.connect('build');
    expect(made.whyNotFollowNow('build'), 'Asking build whether it offers this…');
    expect(answers, hasLength(2), reason: 'the new connection asks for itself');
    answers[0].complete((code: 2, out: '', err: ''));
    answers[1].complete((code: 0, out: '', err: ''));
    await pumpEventQueue();
    expect(made.whyNotFollowNow('build'), isNull, reason: "the earlier connection's answer stands for nothing");

    // The tunnel drops while the host is asked: ssh's failure then says nothing of the host.
    await made.disconnect('build');
    await made.connect('build');
    made.whyNotFollowNow('build');
    masters.last.kill();
    await pumpEventQueue();
    answers.last.complete((code: 255, out: '', err: 'Connection closed by 203.0.113.7\n'));
    await pumpEventQueue();
    final machine = machines.all.singleWhere((machine) => machine.name == 'build');
    expect(await machines.tunnels.raiseFor(machine), isTrue);
    expect(made.up('build'), isTrue);
    expect(made.whyNotFollowNow('build'), isNot(contains('Connection closed')));
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
  // Harm: the forward raised anew holds 127.0.0.1 alone, and ::1 is left to whoever listens there.
  test("raising the forward anew re-adds only the forge's forward on the live master", () async {
    // Where ssh binds the forge's port itself; the window's relay needs nothing raised anew.
    final relayedBefore = PersonOnlyRelay.here;
    addTearDown(() => PersonOnlyRelay.here = relayedBefore);
    PersonOnlyRelay.here = false;
    final before = HostCardSsh.ipv6Loopback;
    addTearDown(() => HostCardSsh.ipv6Loopback = before);
    HostCardSsh.ipv6Loopback = true;
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
    const forward = [
      '-L',
      '127.0.0.1:8081:/run/porelo-forge/web.sock',
      '-L',
      '[::1]:8081:/run/porelo-forge/web.sock',
      'build',
    ];
    expect(
      [for (final command in ran) command.sublist(1)],
      [
        ['-F', config('build'), '-O', 'cancel', ...forward],
        ['-F', config('build'), '-O', 'forward', ...forward],
      ],
    );
  });

  // Harm: ssh cancelled the forward, raised it again on 127.0.0.1 alone and refused [::1], where another program had
  // taken the port meanwhile; the forward left half up sends a browser that tries ::1 first to that program.
  test('a forward refused when raised anew is cancelled again, not left half up', () async {
    // Where ssh binds the forge's port itself; the window's relay needs nothing raised anew.
    final relayedBefore = PersonOnlyRelay.here;
    addTearDown(() => PersonOnlyRelay.here = relayedBefore);
    PersonOnlyRelay.here = false;
    final before = HostCardSsh.ipv6Loopback;
    addTearDown(() => HostCardSsh.ipv6Loopback = before);
    HostCardSsh.ipv6Loopback = true;
    final made = await connections(_mia());
    await made.connect('build');
    ran.clear();
    forwardRefused = true;
    await expectLater(
      made.raiseForwardAnew('build'),
      throwsA(isA<OrganizationRefused>().having((refused) => refused.words, 'words', contains('in use'))),
    );
    expect([for (final command in ran) command[command.indexOf('-O') + 1]], ['cancel', 'forward', 'cancel']);
  });

  // Harm: every click raises the forward again while the cause is on the host.
  test('a second raise within half a minute raises nothing and says the cause is on the host', () async {
    // Where ssh binds the forge's port itself; the window's relay needs nothing raised anew.
    final relayedBefore = PersonOnlyRelay.here;
    addTearDown(() => PersonOnlyRelay.here = relayedBefore);
    PersonOnlyRelay.here = false;
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

  // Harm: the master's forward cancelled and re-added under the window's relay, leaving its port's socket to chance.
  test('where the window relays the forge\'s port, raising it anew runs nothing and keeps the master', () async {
    final relayedBefore = PersonOnlyRelay.here;
    addTearDown(() => PersonOnlyRelay.here = relayedBefore);
    PersonOnlyRelay.here = true;
    final made = await connections(_mia());
    await made.connect('build');
    ran.clear();

    await made.raiseForwardAnew('build');

    expect(ran, isEmpty);
    expect(launches, hasLength(1));
    expect(masters.single.ended, isFalse);
    expect(made.up('build'), isTrue);
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

/// Writes as on Linux, but leaves the folder's permissions alone: Windows' ACLs are not this test's.
class _Unprotected extends HostFileWriter {
  @override
  Future<void> protectDirectory(Directory directory) async {}
}
