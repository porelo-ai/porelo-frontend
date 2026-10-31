import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/join_adapters.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/project_join.dart';
import 'package:porelo_frontend/src/app/registry.dart';
import 'package:porelo_frontend/src/app/registry_checkout.dart';
import 'package:porelo_frontend/src/app/run_here.dart';
import 'package:porelo_frontend/src/app/settings.dart';

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
      'host_account': 'porelo-alice',
      'host_card': {...hostValues()..remove('name'), 'homeserver': 'matrix.orchard.porelo.internal'},
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
    final followed = kept[name] = Followed(
      name: name,
      url: url,
      commit: 'a' * 40,
      unverified: unverified == true,
      signers: [for (final key in answersPinned ?? signers ?? const <String>[]) _fingerprint(key)],
    );
    if (dropsAnswer) {
      dropsAnswer = false;
      throw const VarlinkDisconnected('the connection went away');
    }
    return followed;
  }
}

void main() {
  late _Core core;
  late CoreJoinDiscovery discovery;
  final checkout = RegistryCheckout(root: '/private/registry', repository: 'https://forge.example/team/registry.git');

  setUp(() {
    core = _Core();
    discovery = CoreJoinDiscovery(checkout: checkout, login: () async => 'alice', run: core.run);
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
    ('a host card without its homeserver', _with((json) => (_project(json)['host_card'] as Map).remove('homeserver'))),
    ('a blank homeserver', _with((json) => (_project(json)['host_card'] as Map)['homeserver'] = '  ')),
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
      discovery = CoreJoinDiscovery(checkout: checkout, login: () async => login, run: core.run);
      await expectLater(discovery.admissions(), throwsA(isA<RegistryRefusal>()));
    }
    expect(core.calls, isEmpty);
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
      host = DaemonJoinHost(connect: tunnel.connect, reach: (_) => daemon);
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
          commit: 'a' * 40,
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
