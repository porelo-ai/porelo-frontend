import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:porelo_frontend/src/app/access_developers.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';
import 'package:porelo_frontend/src/app/host_access.dart' show HostAdminIdentity;
import 'package:porelo_frontend/src/app/identity.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/project_access_contract.dart';
import 'package:porelo_frontend/src/app/project_access_transport.dart';
import 'package:porelo_frontend/src/app/project_copies.dart';
import 'package:porelo_frontend/src/app/registry.dart';
import 'package:porelo_frontend/src/app/run_here.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/app/tunnel.dart';

import '../features/support/world.dart' show FakeBackend;

import 'package:porelo_host/porelo_host.dart';

import '../support/signed_host.dart';

const _project = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _base = '1111111111111111111111111111111111111111';
const _filed = '2222222222222222222222222222222222222222';
const _id = '0123456789abcdef0123456789abcdef';
const _staging = '.local/share/porelo-host/setup/demo/.incoming-$_id';
const _sync = 'exec "\${SHELL:-/bin/sh}" -lc \'/usr/bin/sudo -n /usr/local/sbin/porelo-host-person sync demo\'';

String _key(int byte) =>
    'ssh-ed25519 ${base64Encode([0, 0, 0, 11, ...utf8.encode('ssh-ed25519'), 0, 0, 0, 32, ...List.filled(32, byte)])}';

final _alice = _key(1);
final _bob = _key(2);
final _hostKey = _key(7);

final _host = PreparedHost.card({
  'host': 'orchard',
  'address': '203.0.113.7',
  'ssh_port': 22,
  'ssh_host_key': _hostKey,
  'services': {
    'forge': {'web_port': 3000, 'git_port': 3001},
    'matrix': {'port': 8448},
  },
});

IdentityCard _card({String login = 'alice'}) => IdentityCard(
  login: login,
  name: 'Alice',
  email: null,
  fingerprint: HostFiles.signingFingerprint(_alice),
  key: _alice,
  created: '2026-10-31',
  expires: '2026-11-30',
  predecessor: null,
  card: 'login: "$login"\n',
  agent: AgentState.holds,
  agentWord: 'holds',
  revoked: false,
  cardRefused: null,
  registry: const [],
  forge: null,
  pending: const [],
);

ProjectAccessView _view() => ProjectAccessView(
  project: 'demo',
  host: _host,
  projectRevision: _project,
  accessRevision: _filed,
  projectYaml: '',
  actor: HostAdminIdentity('alice', HostFiles.signingFingerprint(_alice)),
  admittedFingerprint: HostFiles.signingFingerprint(_alice),
  canAdmin: true,
  signingAvailable: true,
  adminSigners: [_alice],
  access: AccessDevelopers(const []),
  eligible: const {},
);

final _change = ProjectAccessChange(
  id: _id,
  project: 'demo',
  host: 'orchard',
  hostCard: _host,
  repository: 'git@example.org:team/demo-access.git',
  projectRevision: _project,
  baseRevision: _base,
  actor: 'alice',
  actorFingerprint: HostFiles.signingFingerprint(_alice),
  action: 'add',
  person: AccessDeveloper(login: 'bob', role: 'developer', fingerprint: HostFiles.signingFingerprint(_bob)),
);

/// The host as its commands answer, recording each one.
class _Remote implements Remote {
  final runs = <({String host, String user, String command, String? input})>[];
  final copies = <(String, String)>[];
  final copied = <String, List<int>>{};
  RemoteResult copying = const RemoteResult(0, '');
  RemoteResult syncing = const RemoteResult(0, '');
  List<String> said = [];

  @override
  Future<RemoteResult> run(
    String host,
    String user,
    String command, {
    String? input,
    void Function(String line)? onLine,
  }) async {
    runs.add((host: host, user: user, command: command, input: input));
    if (command == _sync) {
      said.forEach(onLine ?? (_) {});
      return syncing;
    }
    return const RemoteResult(0, '');
  }

  @override
  Future<RemoteResult> copy(String host, String user, String from, String to) async {
    copies.add((from, to));
    copied[to] = await File(from).readAsBytes();
    return copying;
  }
}

/// A card tunnel's SSH master, up until it is taken down.
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

/// The host vault, opened at once.
class _Unlocked implements HostUnlocker {
  @override
  Future<HostUnlockResult> unlock(HostCardSsh card, String config) async =>
      const HostUnlockResult(HostUnlockState.unlocked);

  @override
  Future<void> cancel(String host) async {}
}

ProjectAccessChange _changeOf({String id = _id, String action = 'add'}) => ProjectAccessChange(
  id: id,
  project: _change.project,
  host: _change.host,
  hostCard: _change.hostCard,
  repository: _change.repository,
  projectRevision: _change.projectRevision,
  baseRevision: _change.baseRevision,
  actor: _change.actor,
  actorFingerprint: _change.actorFingerprint,
  action: action,
  person: action == 'register' ? null : _change.person,
);

void main() {
  late Directory root;
  late Settings settings;
  late Machines machines;
  late RecordingTunnels tunnels;
  late _Remote remote;
  late List<List<String>> git;
  late IdentityCard card;
  late CardProjectAccessTransport transport;
  final configs = <(HostCardSsh, String)>[];

  setUp(() async {
    root = await Directory.systemTemp.createTemp('project-access-transport-');
    settings = Settings(MemorySettingsStore());
    tunnels = RecordingTunnels();
    machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: tunnels);
    remote = _Remote();
    git = [];
    card = _card();
    configs.clear();
    Future<Ran> run(
      String program,
      List<String> arguments, {
      String? inDirectory,
      Map<String, String> environment = const {},
      String? input,
    }) async {
      git.add([program, ...arguments]);
      // Each bundle holds the revision it was made at, so a delivered bundle names its commit.
      if (arguments.take(2).join(' ') == 'bundle create') {
        final made = git.lastWhere((call) => call[1] == 'update-ref')[3];
        await File(arguments[2]).writeAsString('bundle at $made');
      }
      return (code: 0, out: '', err: '');
    }

    transport = CardProjectAccessTransport(
      machines: machines,
      identity: () async => card,
      copies: ProjectCopies(root: path.join(root.path, 'copies'), run: run),
      remote: (card, config) {
        configs.add((card, config));
        return remote;
      },
      endpoint: (host) => path.join(root.path, '$host.sock'),
    );
    await Directory(path.join(root.path, 'copies', 'demo')).create(recursive: true);
  });

  tearDown(() async {
    machines.dispose();
    settings.dispose();
    await root.delete(recursive: true);
  });

  // Harm: a tunnel raised as another person than the one whose change it carries, or with another key.
  test('the card tunnel is the person\'s own, to the pinned host, naming the host it was raised for', () async {
    final machine = await transport.connect(_view());
    final raised = tunnels.requested.length;
    expect(tunnels.requested.last, same(machine));
    expect(machine.hostCard!.login, 'alice');
    expect(machine.hostCard!.publicKey, _alice);
    expect(machine.hostCard!.hostKey, _hostKey);
    expect(machine.hostProject, 'orchard');
    expect(machine.identity, isEmpty);
    card = _card(login: 'mallory');
    await expectLater(transport.connect(_view()), throwsA(isA<RegistryRefusal>()));
    expect(tunnels.requested, hasLength(raised));
  });

  group('with the tunnels the app runs', () {
    late Directory folder;
    late List<List<String>> launches;
    late Machines watched;
    late CardProjectAccessTransport through;

    setUp(() {
      folder = Directory.systemTemp.createTempSync('project-access-tunnels-');
      launches = [];
      final tunnels = Tunnels(
        configEnvironment: {'XDG_CONFIG_HOME': folder.path},
        start: (command) async {
          launches.add(command);
          return _Master();
        },
        run: (_) async => ProcessResult(0, 0, '', ''),
        keyAvailable: (_) async => true,
        portsAvailable: (_) async {},
        unlocker: _Unlocked(),
        messengerSocket: path.join(folder.path, 'm'),
      );
      watched = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: tunnels);
      through = CardProjectAccessTransport(
        machines: watched,
        identity: () async => card,
        copies: ProjectCopies(root: path.join(folder.path, 'copies')),
        remote: (card, config) => remote,
        endpoint: (host) => path.join(folder.path, '$host.sock'),
      );
      addTearDown(() async {
        await tunnels.dropEverything();
        watched.dispose();
        folder.deleteSync(recursive: true);
      });
    });

    HostCardSsh cardOf(String key) => HostCardSsh(
      name: 'orchard',
      address: '203.0.113.7',
      sshPort: 22,
      hostKey: _hostKey,
      login: 'alice',
      publicKey: key,
      webPort: 3000,
      gitPort: 3001,
      matrixPort: 8448,
    );

    // A host the person joined here, watched as Join keeps it.
    Future<Machine> joined(String key) async {
      final card = cardOf(key);
      final machine = Machine.fromHostCard(
        card,
        socketPath: path.join(folder.path, 'joined.sock'),
        sshConfig: card.configPath(environment: {'XDG_CONFIG_HOME': folder.path}, windows: false),
      );
      await watched.add(machine);
      expect(await watched.tunnels.raiseFor(machine), isTrue);
      return machine;
    }

    // Harm: Add a developer on a host joined here is refused for good, as its card has another endpoint already.
    test('a host joined here is reached through the machine it is watched as', tags: ['linux'], () async {
      final machine = await joined(_alice);
      final raised = launches.length;
      final connected = await through.connect(_view());
      expect(connected.hostProject, 'orchard');
      expect(connected.hostCard, machine.hostCard);
      expect(connected.socketPath, machine.socketPath);
      expect(connected.sshConfig, machine.sshConfig);
      expect(watched.tunnels.of(machine)?.state, TunnelState.up);
      expect(launches, hasLength(raised), reason: 'the joined tunnel carries the change, no second one is raised');
    });

    // Harm: a host watched with the person's older key keeps its card here, so the card now never raises.
    test('a host watched with an older key gives its tunnel up to the card now', tags: ['linux'], () async {
      final old = await joined(_key(5));
      final connected = await through.connect(_view());
      expect(connected.hostCard!.publicKey, _alice);
      expect(watched.tunnels.of(old)?.state, isNot(TunnelState.up));
      expect(watched.tunnels.of(connected)?.state, TunnelState.up);
    });
  });

  // Harm: an id not of the form a receipt holds names a path the host removes and recreates.
  test('a request id of another form names no folder on the host', () async {
    await transport.connect(_view());
    await expectLater(
      transport.upload(_changeOf(id: '../../x'), _filed),
      throwsA(isA<RegistryRefusal>().having((e) => e.words, 'words', 'Invalid project request ID.')),
    );
    expect(remote.runs, isEmpty);
  });

  // Harm: a setup folder made earlier with another mode lets other accounts read or swap the bundles placed in it.
  test('the setup folders are made owner-only, those there already too', () async {
    await transport.connect(_view());
    await transport.upload(_change, _filed);
    final reserve = remote.runs.first.command;
    for (final folder in ['.local/share/porelo-host/setup', '.local/share/porelo-host/setup/demo']) {
      expect(reserve, contains("d=$folder; if [ -L \"\$d\" ]"), reason: folder);
      expect(
        reserve,
        contains('[ -d "\$d" ] || /usr/bin/mkdir -m 0700 -- "\$d"; /usr/bin/chmod 0700 -- "\$d"'),
        reason: folder,
      );
    }
    expect(
      reserve,
      isNot(
        contains(
          'd=.local; if [ -L "\$d" ]; then echo "\$d is a link; nothing was placed." >&2; exit 1; fi; [ -d "\$d" ] || /usr/bin/mkdir -m 0700 -- "\$d"; /usr/bin/chmod',
        ),
      ),
    );
  });

  // Harm: nothing reaches the host through a tunnel this transport did not raise for the person.
  test('nothing is uploaded or synced before the tunnel is up', () async {
    await expectLater(transport.upload(_change, _filed), throwsA(isA<RegistryRefusal>()));
    await expectLater(transport.apply(_change, _filed), throwsA(isA<RegistryRefusal>()));
    expect(remote.runs, isEmpty);
    expect(remote.copies, isEmpty);
  });

  // Harm: the host takes a newer project or access state than the change names, or bundles another account could
  // read or swap while sync reads them.
  test('the bundles at exactly the change\'s commits are staged owner-only, checked and renamed into place', () async {
    await transport.connect(_view());
    await transport.upload(_change, _filed);
    expect(configs.single.$1.name, 'orchard');
    expect(git.where((call) => call[1] == 'update-ref').map((call) => call[3]), [
      '$_project^{commit}',
      '$_filed^{commit}',
    ]);
    expect(remote.runs.map((run) => run.host).toSet(), {'orchard'});
    expect(remote.runs.map((run) => run.user).toSet(), {''});
    final reserve = remote.runs.first.command;
    expect(reserve, contains('umask 077'));
    expect(reserve, contains('/usr/bin/mkdir -m 0700 -- $_staging'));
    expect(reserve, contains('is a link; nothing was placed.'));
    expect(remote.copies.map((each) => each.$2), ['$_staging/project.bundle', '$_staging/access.bundle']);
    expect(utf8.decode(remote.copied['$_staging/project.bundle']!), 'bundle at $_project^{commit}');
    expect(utf8.decode(remote.copied['$_staging/access.bundle']!), 'bundle at $_filed^{commit}');
    final place = remote.runs[1];
    expect(
      place.input,
      [
        '${sha256.convert(utf8.encode('bundle at $_project^{commit}'))}  project.bundle',
        '${sha256.convert(utf8.encode('bundle at $_filed^{commit}'))}  access.bundle',
        '',
      ].join('\n'),
    );
    expect(place.command, contains('/usr/bin/sha256sum --quiet --strict -c -'));
    expect(
      place.command,
      contains('/usr/bin/mv -fT -- $_staging/access.bundle .local/share/porelo-host/setup/demo/access.bundle'),
    );
    expect(place.command.indexOf('sha256sum'), lessThan(place.command.indexOf('mv -fT')));
    expect(remote.runs, hasLength(2));
    expect(Directory(path.join(root.path, 'copies', 'demo')).listSync(), isEmpty, reason: 'no local bundle is left');
  });

  // Harm: a half-copied upload left for sync, or placed as if whole.
  test('a failed copy places nothing and takes the staging away', () async {
    await transport.connect(_view());
    remote.copying = const RemoteResult(1, 'scp: write failed');
    await expectLater(
      transport.upload(_change, _filed),
      throwsA(isA<RegistryRefusal>().having((e) => e.words, 'words', 'scp: write failed')),
    );
    expect(remote.runs.last.command, contains('/usr/bin/rm -rf -- $_staging'));
    expect(remote.runs.where((run) => run.command.contains('mv -fT')), isEmpty);
  });

  // Harm: a sync run as another command, as root's, or with input the helper would read as a credential.
  test('sync runs in the person\'s own account and its answer is read field by field', () async {
    await transport.connect(_view());
    remote.said = [
      'a login banner',
      jsonEncode({
        'project': 'demo',
        'commit': _project,
        'access_commit': _filed,
        'added': ['bob'],
        'dropped': <String>[],
        'refused': <String>[],
        'unchanged': false,
      }),
    ];
    final status = await transport.apply(_change, _filed);
    expect(remote.runs.single.command, _sync);
    expect(remote.runs.single.input, '');
    expect(status.host, 'orchard');
    expect(status.project, 'demo');
    expect(status.projectRevision, _project);
    expect(status.accessRevision, _filed);
    expect(status.people, {'bob': 'active'});
  });

  // Harm: the host's refusal is hidden, or success is taken from an exit code or an answer that does not say it.
  for (final entry in <String, (RemoteResult, List<String>, String)>{
    'the host refuses the sync': (
      const RemoteResult(65, 'porelo-host-person: project demo is not registered on this host\n'),
      <String>[],
      'The host refused: project demo is not registered on this host',
    ),
    'the host refuses the person': (
      const RemoteResult(0, ''),
      [
        jsonEncode({
          'project': 'demo',
          'commit': _project,
          'access_commit': _filed,
          'added': <String>[],
          'dropped': <String>[],
          'refused': ['bob: not named in the host\'s applied registry'],
          'unchanged': false,
        }),
      ],
      'The host refused bob: not named in the host\'s applied registry.',
    ),
    'the host refuses the admin a registration registers': (
      const RemoteResult(0, ''),
      [
        jsonEncode({
          'project': 'demo',
          'commit': _project,
          'access_commit': _filed,
          'added': <String>[],
          'dropped': <String>[],
          'refused': ['alice: card key or expiry does not match the host\'s applied registry'],
          'unchanged': false,
        }),
      ],
      'The host refused alice: card key or expiry does not match the host\'s applied registry.',
    ),
    'the answer lacks its fields': (
      const RemoteResult(0, ''),
      [
        jsonEncode({'project': 'demo', 'commit': _project}),
      ],
      'The host\'s answer to the sync could not be read.',
    ),
    'the host says nothing': (
      const RemoteResult(0, ''),
      <String>[],
      'The host\'s answer to the sync could not be read.',
    ),
  }.entries) {
    test('${entry.key} is said in words and confirms nothing', () async {
      await transport.connect(_view());
      remote.syncing = entry.value.$1;
      remote.said = entry.value.$2;
      final change = entry.key.contains('registration') ? _changeOf(action: 'register') : _change;
      await expectLater(
        transport.apply(change, _filed),
        throwsA(isA<RegistryRefusal>().having((e) => e.words, 'words', entry.value.$3)),
      );
    });
  }
}
