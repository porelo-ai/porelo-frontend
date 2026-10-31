import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';
import 'package:porelo_frontend/src/app/join_adapters.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/project_join.dart';
import 'package:porelo_frontend/src/app/registry.dart';
import 'package:porelo_frontend/src/app/registry_checkout.dart';
import 'package:porelo_frontend/src/app/registry_read_source.dart';
import 'package:porelo_frontend/src/app/run_here.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/app/tunnel.dart';
import 'package:porelo_host/porelo_host.dart';

import '../features/support/world.dart' show FakeBackend;
import '../support/host_admin.dart';
import '../support/project_join.dart';
import '../support/signed_host.dart';

const _revokedSigner = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC';
const _otherSigner = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB';

/// Core's `registry joinable` answer, exactly in the agreed shape, as decoded JSON.
Map<String, Object?> _joinable() => jsonDecode(jsonEncode(_answer)) as Map<String, Object?>;

final _answer = {
  'projects': [
    {
      'project': 'demo',
      'host': 'orchard',
      'host_account': 'alice',
      'host_card': {'host': 'orchard', ...hostValues()..remove('name'), 'signed_by': 'SHA256:${'A' * 43}'},
      'homeserver': 'https://matrix.orchard.porelo.internal',
      'source': 'https://forge.example/team/demo.git',
      'access_repository': 'https://forge.example/team/access.git',
      'revision': 'a' * 40,
      'signers': [personKey, _otherSigner],
      'admins': [
        {'login': 'bob', 'name': 'Bob', 'email': null},
      ],
    },
  ],
  'refused': [
    {
      'project': 'billing',
      'host': 'orchard',
      'access_repository': 'https://forge.example/team/billing-access.git',
      'why': 'not signed by a verified admin',
      'admins': [
        {'login': 'carol', 'name': 'Carol', 'email': 'carol@example.org'},
      ],
    },
  ],
};

/// A key's `SHA256:` fingerprint, as the daemon names what it pinned.
String _fingerprint(String key) =>
    'SHA256:${base64Encode(sha256.convert(base64Decode(key.split(' ')[1])).bytes).replaceAll('=', '')}';

/// Changes one projects[] or refused[] entry of Core's answer, or one of its admins or its host card.
Ran Function() _with(void Function(Map<String, Object?> json) change) => () {
  final json = _joinable();
  change(json);
  return (code: 0, out: jsonEncode(json), err: '');
};

Map<String, Object?> _project(Map<String, Object?> json) => (json['projects'] as List).single as Map<String, Object?>;
Map<String, Object?> _refused(Map<String, Object?> json) => (json['refused'] as List).single as Map<String, Object?>;

/// Core's `identity show --json` answer for the person `alice`, in its full shape.
final _shown = {
  'login': 'alice',
  'name': 'Alice',
  'email': null,
  'fingerprint': _fingerprint(personKey),
  'key': personKey,
  'created': '2026-10-31',
  'expires': '2026-11-30',
  'predecessor': null,
  'card': 'login: "alice"\n',
  'agent': 'holds',
  'agent_holds_key': true,
  'revoked': false,
  'card_refused': null,
  'registry': [
    {
      'address': _registryAddress,
      'filed': 'done',
      'revision': 'b' * 40,
      'may_file': true,
      // An owner without an accepted card, as Core names one.
      'who_may': [
        {'login': 'carol', 'name': null, 'email': null},
      ],
    },
  ],
  'forge': null,
  'pending': <Object?>[],
};

const _registryAddress = 'https://forge.example/team/registry.git';

/// The registry checkout, never cloned or fetched here.
class _Checkout implements RegistryCheckout {
  _Checkout(this.repository);

  @override
  final String repository;

  @override
  String get root => '/private/registry';

  @override
  String get folder => '/private/registry/registry-${repository.hashCode}';

  /// Whether the next fetch fails.
  bool fails = false;

  @override
  Future<String> fetch() async => fails ? throw const WorkspaceRefused('The registry could not be fetched.') : 'b' * 40;

  @override
  Future<void> prepareRetry({required String base, required String file, required String content}) =>
      throw UnimplementedError();

  @override
  Future<void> prepareFiling() async {}

  @override
  Future<void> publishMade(String revision, {required String base}) async {}

  @override
  Future<void> publish(String revision) async {}
}

/// Core's registry read, accepted at once unless a test holds it or makes it refuse a commit.
class _RegistryCore implements RegistryCore {
  Completer<void>? hold;
  Map<String, dynamic>? refusedCommit;

  /// Whether the read accepted no revision yet.
  bool noRevision = false;

  @override
  Future<RegistryRead> read(String checkout) async {
    await hold?.future;
    return RegistryRead.from({
      'revision': noRevision ? null : 'b' * 40,
      'people': <Object?>[],
      'owners': <Object?>[],
      'warnings': <Object?>[],
      'hosts': <Object?>[],
      'refused_commit': ?refusedCommit,
    });
  }

  @override
  Future<RegistryFiled> file(String checkout, RegistryFiling filing) => throw UnimplementedError();
}

/// An ssh master that stays up until it is stopped.
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

/// The words after each [flag] in [command].
List<String> _after(String flag, List<String> command) => [
  for (var i = 0; i < command.length - 1; i++)
    if (command[i] == flag) command[i + 1],
];

/// Core's command line, answering what a test sets and recording every call.
class _Core {
  final calls = <List<String>>[];
  Ran answer = (code: 0, out: jsonEncode(_joinable()), err: '');

  Future<Ran> run(
    String program,
    List<String> arguments, {
    String? inDirectory,
    Map<String, String> environment = const {},
    String? input,
  }) async {
    calls.add([program, ...arguments]);
    return answer;
  }
}

/// An account daemon whose follow is recorded and which can lose its connection.
class _Daemon extends FakeBackend {
  _Daemon() : super(const []);

  /// Every follow asked of it.
  final asked = <({String name, String url, String? signedBy, List<String>? signers, bool? unverified})>[];

  /// What it follows, by name.
  final kept = <String, Followed>{};

  /// Opens that fail before the next one answers.
  int opensFail = 0;

  /// Whether the next follow is recorded but its answer lost with the connection.
  bool dropsAnswer = false;

  /// The keys the daemon answers as pinned instead of those it was given.
  List<String>? answersPinned;

  @override
  Future<ServiceInfo> open() async {
    if (opensFail > 0) {
      opensFail--;
      throw const VarlinkDisconnected('no tunnel');
    }
    return whatItIs;
  }

  @override
  Future<List<Followed>> following() async => kept.values.toList();

  @override
  Future<Followed> follow(
    String name,
    String url, {
    String? signedBy,
    List<String>? signers,
    bool? unverified,
    bool? acceptRewrite,
  }) async {
    asked.add((name: name, url: url, signedBy: signedBy, signers: signers, unverified: unverified));
    final pinned = [for (final key in answersPinned ?? signers ?? const <String>[]) _fingerprint(key)];
    kept[name] = Followed(
      name: name,
      url: url,
      outcome: 'APPLIED',
      accessCommit: 'a' * 40,
      unverified: unverified == true,
      signers: pinned,
    );
    if (dropsAnswer) {
      dropsAnswer = false;
      throw const VarlinkDisconnected('the connection went away');
    }
    // `Follow` answers its outcome and what it pinned; the access commit and the signers in force only `Following`.
    return Followed(name: '', outcome: 'APPLIED', commit: 'f' * 40, recorded: true, pinned: pinned);
  }
}

void main() {
  late _Core core;
  late CoreJoinDiscovery discovery;
  late Registry registry;
  final checkout = _Checkout(_registryAddress);

  setUp(() async {
    core = _Core();
    registry = Registry(checkout: checkout, core: _RegistryCore());
    await registry.refresh();
    discovery = CoreJoinDiscovery(registry: () => registry, login: () async => 'alice', run: core.run);
  });

  // Harm: a project whose access file names no homeserver is dropped, or another homeserver is taken for it.
  test('the homeserver comes from the project row, and a row naming none is still offered', () async {
    core.answer = _with((_) {})();
    expect(
      (await discovery.admissions()).whereType<JoinOffered>().single.homeserver,
      'https://matrix.orchard.porelo.internal',
    );
    core.answer = _with((json) => _project(json)['homeserver'] = null)();
    expect((await discovery.admissions()).whereType<JoinOffered>().single.homeserver, isNull);
  });

  // Harm: a project whose access file Core refused is offered to join, or its admins are not named to ask.
  test('a refused project is never offered, and its admins are named as contacts', () async {
    final json = _joinable();
    final offered = Map<String, Object?>.of((json['projects'] as List).single as Map<String, Object?>);
    (json['projects'] as List).add({...offered, 'project': 'billing'});
    core.answer = (code: 0, out: jsonEncode(json), err: '');
    final rows = await discovery.admissions();
    expect(core.calls.single, ['porelo', 'registry', 'joinable', checkout.folder, '--login', 'alice', '--json']);
    expect(rows.whereType<JoinOffered>().map((row) => row.project), ['demo']);
    final refused = rows.whereType<JoinUnreadable>().single;
    expect(refused.repository, 'https://forge.example/team/billing-access.git');
    expect(refused.words, contains('Carol (carol), carol@example.org'));
  });

  // Harm: a broken, partial or refused answer from Core shows as rows to click, or as an empty list.
  for (final (name, answer) in <(String, Ran Function())>[
    ('not JSON', () => (code: 0, out: 'projects: []', err: '')),
    (
      'a project without admins',
      () {
        final json = _joinable();
        ((json['projects'] as List).single as Map).remove('admins');
        return (code: 0, out: jsonEncode(json), err: '');
      },
    ),
    (
      'a project without its host account',
      () {
        final json = _joinable();
        ((json['projects'] as List).single as Map).remove('host_account');
        return (code: 0, out: jsonEncode(json), err: '');
      },
    ),
    (
      'a refusal without why',
      () {
        final json = _joinable();
        ((json['refused'] as List).single as Map).remove('why');
        return (code: 0, out: jsonEncode(json), err: '');
      },
    ),
    (
      'an admin without a name',
      () {
        final json = _joinable();
        (((json['refused'] as List).single as Map)['admins'] as List)[0] = {'login': 'carol', 'email': null};
        return (code: 0, out: jsonEncode(json), err: '');
      },
    ),
    (
      'the same project twice',
      () {
        final json = _joinable();
        (json['projects'] as List).add((json['projects'] as List).single);
        return (code: 0, out: jsonEncode(json), err: '');
      },
    ),
    ('a project row without its homeserver', _with((json) => _project(json).remove('homeserver'))),
    ('a blank homeserver', _with((json) => _project(json)['homeserver'] = '  ')),
    ('a project row without its repository', _with((json) => _project(json).remove('source'))),
    ('an admitted project nobody may grant', _with((json) => _project(json)['admins'] = [])),
    ('a blank refused project', _with((json) => _refused(json)['project'] = ' ')),
    ('a blank refused host', _with((json) => _refused(json)['host'] = '')),
    ('a blank why', _with((json) => _refused(json)['why'] = '\t')),
    (
      'a blank admin login',
      _with((json) => (_refused(json)['admins'] as List)[0] = {'login': ' ', 'name': 'Carol', 'email': null}),
    ),
    (
      'a blank admin name',
      _with((json) => (_project(json)['admins'] as List)[0] = {'login': 'bob', 'name': '  ', 'email': null}),
    ),
    ('a typed refusal', () => (code: 65, out: '{"reason":"registry-not-verified","words":"no"}', err: '')),
    ('an internal failure', () => (code: 70, out: jsonEncode(_joinable()), err: '')),
  ]) {
    test('an answer with $name offers nothing', () async {
      core.answer = answer();
      await expectLater(discovery.admissions(), throwsA(isA<RegistryRefusal>()));
    });
  }

  // Harm: Core is asked for someone else, or for nobody, so another person's admissions are offered.
  test('without a known login Core is not asked and nothing is offered', () async {
    for (final login in [null, '--json', 'Alice Smith']) {
      discovery = CoreJoinDiscovery(registry: () => registry, login: () async => login, run: core.run);
      await expectLater(discovery.admissions(), throwsA(isA<RegistryRefusal>()));
    }
    expect(core.calls, isEmpty);
  });

  // Harm: a row for another person than the login asked for is offered, and its tunnel logs in as them.
  test('a joinable row for another login than the one asked for offers nothing', () async {
    core.answer = _with((json) => _project(json)['host_account'] = 'bob')();
    await expectLater(discovery.admissions(), throwsA(isA<RegistryRefusal>()));
  });

  // Harm: a host account Core would never admit becomes a path on the host, or a tunnel is raised for it.
  test('a joinable row whose host account breaks Core\'s rule offers nothing', () async {
    for (final account in ['porelo_alice', 'Alice', '-alice', '../bob', 'a' * 33]) {
      core.answer = _with((json) => _project(json)['host_account'] = account)();
      await expectLater(discovery.admissions(), throwsA(isA<RegistryRefusal>()), reason: account);
    }
  });

  group('the card tunnel of a joinable row', () {
    late Directory folder;
    late List<List<String>> launches;
    late Machines machines;
    late bool portsBusy;

    setUp(() {
      folder = Directory.systemTemp.createTempSync('j-');
      portsBusy = false;
      launches = [];
      final tunnels = Tunnels(
        configEnvironment: {'XDG_CONFIG_HOME': folder.path},
        start: (command) async {
          launches.add(command);
          return _Master();
        },
        run: (_) async => ProcessResult(0, 0, '', ''),
        keyAvailable: (_) async => true,
        portsAvailable: (card) async {
          if (portsBusy) throw HostFilesRefused('Host ${card.name} cannot start: a port is busy.');
        },
        unlocker: _Unlocked(),
        messengerSocket: path.join(folder.path, 'm'),
      );
      final settings = Settings(MemorySettingsStore());
      machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: tunnels);
      addTearDown(() async {
        await tunnels.dropEverything();
        machines.dispose();
        settings.dispose();
        folder.deleteSync(recursive: true);
      });
    });

    Future<Machine> Function(JoinOffered) connect({String login = 'alice'}) => cardTunnel(
      machines,
      person: () async => (login: login, key: personKey),
      endpoint: (_) => path.join(folder.path, 'd'),
    );

    JoinOffered as(JoinOffered shown, {String? login, String? hostKey}) => JoinOffered(
      project: shown.project,
      host: PreparedHost.card({
        'host': shown.host.name,
        'address': shown.host.address,
        'ssh_port': shown.host.sshPort,
        'ssh_host_key': hostKey ?? shown.host.sshHostKey,
        'services': shown.host.services,
      }),
      login: login ?? shown.login,
      source: shown.source,
      revision: shown.revision,
      signers: shown.signers,
    );

    // Harm: the tunnel forwards another account's daemon, or lets the host write into another person's directory.
    test('forwards the daemon and return sockets of the person\'s own account only', tags: ['linux'], () async {
      final offer = (await discovery.admissions()).whereType<JoinOffered>().single;
      await expectLater(connect()(as(offer, login: 'bob')), throwsA(isA<RegistryRefusal>()));
      await expectLater(connect(login: 'bob')(offer), throwsA(isA<RegistryRefusal>()));
      expect(launches, isEmpty, reason: 'a row for another login than the card names raises nothing');
      final machine = await connect()(offer);
      final command = launches.single;
      expect(_after('-L', command).last, '${path.join(folder.path, 'd')}:/run/porelo-host/people/alice/porelod.sock');
      expect(_after('-R', command), ['/run/porelo-host/people/alice/return.sock:${path.join(folder.path, 'm')}']);
      expect(command.last, 'orchard');
      expect(offer.reaches(machine), isTrue, reason: 'the join reuses the account this tunnel reaches');
      expect(cardTunnelUp(machines)(machine), isTrue);
    });

    // Harm: a join that was not confirmed leaves its tunnel and pins, and the host's next card is refused for them.
    test('a card tunnel taken down after an unconfirmed join lets a rotated card raise', tags: ['linux'], () async {
      final offer = (await discovery.admissions()).whereType<JoinOffered>().single;
      final machine = await connect()(offer);
      final config = machine.sshConfig;
      expect(File('$config.known_hosts').existsSync(), isTrue);
      await cardTunnelDown(machines)(machine);
      expect(machines.tunnels.of(machine), isNull);
      for (final file in [config, '$config.known_hosts', '$config.pub']) {
        expect(File(file).existsSync(), isFalse, reason: file);
      }
      final rotated = await connect()(as(offer, hostKey: _otherSigner));
      expect(cardTunnelUp(machines)(rotated), isTrue);
      expect(File('$config.known_hosts').readAsStringSync(), contains(_otherSigner));
    });

    // Harm: taking down an unconfirmed join's tunnel removes the files a raise queued meanwhile published, and that
    // tunnel runs without its configuration and pins.
    test('a raise queued while a tunnel is taken down keeps the files it published', tags: ['linux'], () async {
      final offer = (await discovery.admissions()).whereType<JoinOffered>().single;
      final machine = await connect()(offer);
      final config = machine.sshConfig;
      // A probe holds the master, so the drop ends only once it lets go; a raise queued meanwhile takes the tunnel.
      final probe = machines.tunnels.holdForTrial(machine);
      expect(await probe.ready, isTrue);
      final down = cardTunnelDown(machines)(machine);
      await pumpEventQueue();
      expect(await machines.tunnels.raiseFor(machine), isTrue);
      await probe.release();
      await down;
      expect(cardTunnelUp(machines)(machine), isTrue);
      for (final file in [config, '$config.known_hosts', '$config.pub']) {
        expect(File(file).existsSync(), isTrue, reason: file);
      }
    });

    // Harm: a watched account reached with the person's older key keeps the host's card, so the card now never
    // raises, or the join goes on with the old key.
    test('a watched account of an older key gives its tunnel up to the card now', tags: ['linux'], () async {
      final offer = (await discovery.admissions()).whereType<JoinOffered>().single;
      final old = await cardTunnel(
        machines,
        person: () async => (login: 'alice', key: _otherSigner),
        endpoint: (_) => path.join(folder.path, 'd'),
      )(offer);
      await machines.add(old);
      final machine = await connect()(offer);
      expect(machine.hostCard!.publicKey, personKey);
      expect(cardTunnelUp(machines)(machine), isTrue);
      expect(File('${machine.sshConfig}.pub').readAsStringSync(), contains(personKey.split(' ')[1]));
    });

    // Harm: a tunnel that never came up keeps the host's card reserved, and the host's next card is refused for it.
    test('a card tunnel that does not come up keeps nothing of its card', tags: ['linux'], () async {
      final offer = (await discovery.admissions()).whereType<JoinOffered>().single;
      portsBusy = true;
      await expectLater(connect()(offer), throwsA(isA<RegistryRefusal>()));
      portsBusy = false;
      final rotated = await connect()(as(offer, hostKey: _otherSigner));
      expect(cardTunnelUp(machines)(rotated), isTrue);
    });

    // Harm: a card account whose tunnel is down, or which uses another ssh configuration, is taken as reached.
    test('a card account is up only with its own configuration and an up tunnel', tags: ['linux'], () async {
      final offer = (await discovery.admissions()).whereType<JoinOffered>().single;
      final card = joinCard(offer, personKey);
      final unraised = Machine.fromHostCard(
        card,
        socketPath: path.join(folder.path, 'd'),
        sshConfig: card.configPath(environment: {'XDG_CONFIG_HOME': folder.path}),
      );
      expect(cardTunnelUp(machines)(unraised), isFalse, reason: 'no tunnel was raised for it');
      final machine = await connect()(offer);
      final elsewhere = Machine.fromHostCard(card, socketPath: machine.socketPath, sshConfig: '/other/orchard.conf');
      expect(cardTunnelUp(machines)(elsewhere), isFalse);
    });

    // Harm: a login Core would never admit reaches the host as a path in a tunnel's forwards.
    test('a row with a login outside Core\'s rule raises nothing', () async {
      final shown = (await discovery.admissions()).whereType<JoinOffered>().single;
      final offer = JoinOffered(
        project: shown.project,
        host: shown.host,
        login: 'porelo_alice',
        source: shown.source,
        revision: shown.revision,
        signers: shown.signers,
      );
      await expectLater(connect(login: 'porelo_alice')(offer), throwsA(isA<HostFilesRefused>()));
      expect(launches, isEmpty);
    });
  });

  group('the app\'s join adapters', () {
    String? address;
    late _RegistryCore read;
    late RegistryReadSource registry;
    late List<List<String>> calls;
    late Map<String, Object?> shown;
    late Machines machines;

    setUp(() {
      address = null;
      read = _RegistryCore();
      registry = RegistryReadSource(
        repository: () => address,
        open: (repository) => Registry(checkout: _Checkout(repository), core: read),
        machines: () => const [],
      );
      calls = [];
      shown = jsonDecode(jsonEncode(_shown)) as Map<String, Object?>;
      final settings = Settings(MemorySettingsStore());
      machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: RecordingTunnels());
      addTearDown(machines.dispose);
      addTearDown(settings.dispose);
    });

    Future<Ran> run(
      String program,
      List<String> arguments, {
      String? inDirectory,
      Map<String, String> environment = const {},
      String? input,
    }) async {
      calls.add([program, ...arguments]);
      return arguments.first == 'identity'
          ? (code: 0, out: jsonEncode(shown), err: '')
          : (code: 0, out: jsonEncode(_joinable()), err: '');
    }

    Iterable<List<String>> joinable() => calls.where((call) => call.contains('joinable'));

    // Harm: joining reads another checkout than the registry pages, or one never cloned, fetched or accepted, or one
    // a fetch is moving, offering admissions from a registry not chosen or not read here.
    test('read the pages\' own registry checkout once its read has ended accepted', () async {
      final joins = appJoins(registry: registry, machines: machines, run: run);
      await expectLater(joins.discovery.admissions(), throwsA(isA<RegistryRefusal>()));
      expect(joinable(), isEmpty, reason: 'no registry was chosen yet');
      address = _registryAddress;
      await expectLater(joins.discovery.admissions(), throwsA(isA<RegistryRefusal>()));
      expect(joinable(), isEmpty, reason: 'the checkout was never fetched and read');
      read.hold = Completer<void>();
      final reading = registry.registry!.refresh();
      final asked = joins.discovery.admissions();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(joinable(), isEmpty, reason: 'a fetch and read of the checkout still runs');
      read.hold!.complete();
      await reading;
      final rows = await asked;
      expect(joinable().single, [
        'porelo',
        'registry',
        'joinable',
        registry.registry!.checkout.folder,
        '--login',
        'alice',
        '--json',
      ]);
      expect(rows.whereType<JoinOffered>().single.login, 'alice');
      read.noRevision = true;
      read.refusedCommit = {'commit': 'c' * 40, 'path': 'owners.yml', 'why': 'not signed by an owner'};
      await registry.registry!.refresh();
      await expectLater(
        joins.discovery.admissions(),
        throwsA(isA<RegistryRefusal>().having((e) => e.toString(), 'words', contains('no accepted revision'))),
      );
      expect(joinable(), hasLength(1), reason: 'the registry accepted no revision');
    });

    // Harm: one refused commit beside the accepted revision closes every host, and a host whose access file was
    // refused is never shown as its own row.
    test(
      'a refused commit beside the accepted revision still offers the healthy hosts and names the refused one',
      () async {
        address = _registryAddress;
        read.refusedCommit = {
          'commit': 'c' * 40,
          'path': 'hosts/grove/access.yml',
          'why': 'not signed by a host admin',
        };
        await registry.registry!.refresh();
        expect(registry.registry!.problem, isNotNull, reason: 'the pages say the refused commit');
        final answer = _joinable();
        (answer['refused'] as List).add({
          'project': null,
          'host': 'grove',
          'access_repository': null,
          'why': 'hosts/grove/access.yml in cccccccc: not signed by a host admin',
          'admins': [
            {'login': 'dave', 'name': null, 'email': null},
          ],
        });
        final joins = appJoins(
          registry: registry,
          machines: machines,
          run: (program, arguments, {inDirectory, environment = const {}, input}) async {
            calls.add([program, ...arguments]);
            return arguments.first == 'identity'
                ? (code: 0, out: jsonEncode(shown), err: '')
                : (code: 0, out: jsonEncode(answer), err: '');
          },
        );
        final rows = await joins.discovery.admissions();
        expect(rows.whereType<JoinOffered>().single.key, 'demo@orchard');
        final grove = rows.whereType<JoinUnreadable>().where((row) => row.host == 'grove').single;
        expect(grove.repository, isNull);
        expect(grove.words, allOf(contains('grove'), contains('dave (dave)')));
      },
    );

    // Harm: a failed fetch after a read with a refused commit is taken as read, and rows of a registry not read here
    // are offered.
    test('a failed fetch after a refused commit offers nothing', () async {
      address = _registryAddress;
      read.refusedCommit = {'commit': 'c' * 40, 'path': 'owners.yml', 'why': 'not signed by an owner'};
      await registry.registry!.refresh();
      final joins = appJoins(registry: registry, machines: machines, run: run);
      expect(await joins.discovery.admissions(), isNotEmpty);
      (registry.registry!.checkout as _Checkout).fails = true;
      await registry.registry!.refresh();
      await expectLater(joins.discovery.admissions(), throwsA(isA<RegistryRefusal>()));
      expect(joinable(), hasLength(1));
    });

    // Harm: a person whose identity Core names with an owner it has no card for is told Porelo knows no identity, and
    // finds no project to join.
    test('an identity naming a contact without an accepted card is read', () async {
      address = _registryAddress;
      await registry.registry!.refresh();
      final joins = appJoins(registry: registry, machines: machines, run: run);
      expect((await joins.discovery.admissions()).whereType<JoinOffered>(), hasLength(1));
    });

    // Harm: a login outside the host account rule is said as no identity at all, so the person looks for a card they
    // have.
    test('a login outside the host account rule is said in its own words', () async {
      address = _registryAddress;
      await registry.registry!.refresh();
      shown['login'] = 'Alice_Smith';
      final joins = appJoins(registry: registry, machines: machines, run: run);
      await expectLater(
        joins.discovery.admissions(),
        throwsA(
          isA<RegistryRefusal>().having(
            (e) => e.toString(),
            'words',
            allOf(contains('not one a host account takes'), isNot(contains('knows no identity'))),
          ),
        ),
      );
      expect(joinable(), isEmpty);
    });

    // Harm: a card that is revoked, does not verify, whose key the agent does not hold, or that the registry has not
    // accepted, finds joinable rows and publishes its key in a host's ssh configuration.
    for (final (name, change) in <(String, void Function(Map<String, Object?>))>[
      ('revoked', (card) => card['revoked'] = true),
      ('refused', (card) => card['card_refused'] = 'the signature does not verify'),
      (
        'not held by the agent',
        (card) => card
          ..['agent'] = 'not-held'
          ..['agent_holds_key'] = false,
      ),
      ('pending in the registry', (card) => ((card['registry'] as List).single as Map)['filed'] = 'pending'),
      ('filed in another registry', (card) => ((card['registry'] as List).single as Map)['address'] = 'git@x:o/r'),
      ('read in no registry', (card) => card['registry'] = <Object?>[]),
    ]) {
      test('a card $name joins nothing and says why', () async {
        address = _registryAddress;
        await registry.registry!.refresh();
        final joins = appJoins(registry: registry, machines: machines, run: run);
        final offer = (await joins.discovery.admissions()).whereType<JoinOffered>().single;
        change(shown);
        calls.clear();
        await expectLater(joins.discovery.admissions(), throwsA(isA<RegistryRefusal>()));
        expect(joinable(), isEmpty);
        await expectLater(joins.host.connect(offer), throwsA(isA<RegistryRefusal>()));
        expect((machines.tunnels as RecordingTunnels).requested.where((m) => m.hostCard != null), isEmpty);
      });
    }
  });

  group('on the account daemon', () {
    late Settings settings;
    late Machines machines;
    late _Daemon daemon;
    late FakeJoinHost tunnel;
    late DaemonJoinHost host;

    setUp(() {
      settings = Settings(MemorySettingsStore());
      machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: RecordingTunnels());
      daemon = _Daemon();
      tunnel = FakeJoinHost();
      host = DaemonJoinHost(
        connect: tunnel.connect,
        current: tunnel.current,
        raise: tunnel.raise,
        ready: tunnel.ready,
        release: tunnel.release,
        reach: (_) => daemon,
      );
      addTearDown(machines.dispose);
      addTearDown(settings.dispose);
    });

    Future<ProjectJoin> joining() async {
      final shown = (await discovery.admissions()).whereType<JoinOffered>().single;
      final join = ProjectJoin(offer: shown, discovery: discovery, host: host, machines: machines, settings: settings);
      addTearDown(join.dispose);
      return join;
    }

    // Harm: a join follows with other signers than Core verified, with one of them only, or unverified.
    test('a join follows only with the signers Core named', () async {
      final join = await joining();
      await join.join();
      expect(join.problem, isNull);
      expect(join.joined, isTrue);
      final asked = daemon.asked.single;
      expect(asked.name, 'demo');
      expect(asked.url, 'https://forge.example/team/demo.git');
      expect(asked.signers, [personKey, _otherSigner]);
      expect(asked.signedBy, isNull);
      expect(asked.unverified, isNot(isTrue));
    });

    // Harm: a follow already at the revision but pinned to only some, or to removed or revoked, signers is taken as joined.
    for (final (name, pinned) in [
      ('only some of', [personKey]),
      ('more than', [personKey, _otherSigner, _revokedSigner]),
      ('other than', [_revokedSigner]),
    ]) {
      test('a follow there pinned to $name Core\'s signers is followed again with them', () async {
        daemon.kept['demo'] = Followed(
          name: 'demo',
          url: 'https://forge.example/team/demo.git',
          accessCommit: 'a' * 40,
          signers: [for (final key in pinned) _fingerprint(key)],
        );
        final join = await joining();
        await join.join();
        expect(daemon.asked.single.signers, [personKey, _otherSigner]);
        expect(join.joined, isTrue);
      });
    }

    // Harm: a follow the daemon answers as pinned to other signers than Core's is taken as joined.
    test('a follow answered with other signers saves nothing', () async {
      daemon.answersPinned = [personKey];
      final join = await joining();
      await join.join();
      expect(join.joined, isFalse);
      expect(settings.projectHost('demo'), isNull);
      expect(machines.all.where((m) => m.kind == 'host'), isEmpty);
    });

    // Harm: a retry after the host connection failed follows the project a second time.
    test('a retry after a failed host connection does not follow twice', () async {
      final join = await joining();
      daemon.opensFail = 1;
      await join.join();
      expect(join.joined, isFalse);
      expect(daemon.asked, isEmpty);
      daemon.dropsAnswer = true;
      await join.join();
      expect(join.joined, isFalse);
      expect(daemon.asked, hasLength(1));
      await join.join();
      expect(join.problem, isNull);
      expect(join.joined, isTrue);
      expect(daemon.asked, hasLength(1));
    });
  });
}
