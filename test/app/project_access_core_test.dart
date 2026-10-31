import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/access_developers.dart';
import 'package:porelo_frontend/src/app/identity.dart';
import 'package:porelo_frontend/src/app/project_access_contract.dart';
import 'package:porelo_frontend/src/app/project_access_core.dart';
import 'package:porelo_frontend/src/app/project_copies.dart';
import 'package:porelo_frontend/src/app/registry.dart';
import 'package:porelo_frontend/src/app/registry_checkout.dart';
import 'package:porelo_frontend/src/app/run_here.dart';
import 'package:porelo_host/porelo_host.dart';

const _project = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _base = '1111111111111111111111111111111111111111';
const _filed = '2222222222222222222222222222222222222222';
const _moved = '3333333333333333333333333333333333333333';
const _id = '0123456789abcdef0123456789abcdef';
const _url = 'git@example.org:team/demo.git';
const _accessUrl = 'git@example.org:team/demo-access.git';
const _checkout = '/private/registry/checkout';
const _projectYaml =
    '''
access:
  repository: $_accessUrl
repositories:
  code:
    upstream: https://example.org/team/code.git
''';

String _key(int byte) =>
    'ssh-ed25519 ${base64Encode([0, 0, 0, 11, ...utf8.encode('ssh-ed25519'), 0, 0, 0, 32, ...List.filled(32, byte)])}';

final _alice = _key(1);
final _bob = _key(2);
final _hostKey = _key(7);

Map<String, Object?> _person(String login, String key, String role) => {
  'login': login,
  'ssh': key,
  'role': role,
  'hosts': ['orchard'],
  'expires': '2030-01-01',
  'revoked': false,
  'locked': false,
};

class _Checkout implements RegistryCheckout {
  @override
  String get repository => 'git@example.org:team/registry.git';
  @override
  String get root => '/private/registry';
  @override
  String get folder => _checkout;
  @override
  Future<String> fetch() async => 'c' * 40;
  @override
  Future<void> prepareRetry({required String base, required String file, required String content}) =>
      throw UnimplementedError();
  @override
  Future<void> prepareFiling() async {}
  @override
  Future<void> publishMade(
    String revision, {
    required String base,
    required String id,
    required String file,
    String? lastRead,
  }) async {}
  @override
  Future<void> publish(String revision) async {}
}

class _RegistryCore implements RegistryCore {
  @override
  Future<RegistryRead> read(String checkout) async => RegistryRead.from({
    'revision': 'c' * 40,
    'people': [
      for (final (login, key) in [('alice', _alice), ('bob', _bob)])
        {
          'login': login,
          'name': login.toUpperCase(),
          'email': '$login@example.org',
          'key': key,
          'fingerprint': HostFiles.signingFingerprint(key),
          'state': 'trusted',
          'why': '',
        },
    ],
    'owners': <Object?>[],
    'warnings': <Object?>[],
    'hosts': [
      {
        'host': 'orchard',
        'card': {
          'host': 'orchard',
          'address': '203.0.113.7',
          'ssh_port': 22,
          'ssh_host_key': _hostKey,
          'services': {
            'forge': {'web_port': 3000, 'git_port': 3001},
            'matrix': {'port': 8448},
          },
          'signed_by': HostFiles.signingFingerprint(_alice),
        },
        'admins': [
          {'login': 'alice', 'fingerprint': HostFiles.signingFingerprint(_alice)},
        ],
        'projects': [
          {'name': 'demo', 'admin': 'alice', 'access_repository': _accessUrl},
        ],
      },
    ],
  });

  @override
  Future<RegistryFiled> file(String checkout, RegistryFiling filing) => throw UnimplementedError();
}

/// Core, git and the access repository's history at once, as each command answers.
class _Here {
  final calls = <List<String>>[];
  final directories = <String?>[];
  Map<String, Object?> verification = {
    'project': 'demo',
    'commit': _project,
    'access_commit': _base,
    'persons': [_person('alice', _alice, 'admin')],
    'admins': ['alice'],
    'certifiers': <String>[],
    'signers': [_alice],
  };
  Map<String, Object?> follow = {
    'name': 'demo',
    'url': _url,
    'commit': _project,
    'verified': true,
    'signed_by': [_alice],
    'access_commit': _base,
  };

  /// The access repository's default branch, newest first, each with its change id or none.
  List<(String, String)> history = [(_base, '')];
  Ran? filing;
  Ran? verifying;
  bool fetchFails = false;

  String get head => history.first.$1;

  Future<Ran> run(
    String program,
    List<String> arguments, {
    String? inDirectory,
    Map<String, String> environment = const {},
    String? input,
  }) async {
    calls.add([program, ...arguments]);
    directories.add(inDirectory);
    if (program == 'porelo') {
      return switch (arguments.take(2).join(' ')) {
        'project following' => (
          code: 0,
          out: jsonEncode({
            'follows': [follow],
          }),
          err: '',
        ),
        'project verify' => verifying ?? (code: 0, out: jsonEncode(verification), err: ''),
        _ => filing ?? (code: 0, out: jsonEncode({'revision': _filed}), err: ''),
      };
    }
    expect(environment['GIT_CONFIG_GLOBAL'], '/dev/null', reason: 'git runs without the person\'s configuration');
    if (arguments.first == 'clone') Directory(arguments.last).createSync(recursive: true);
    final held = {for (final (commit, _) in history) commit};
    return switch (arguments.first) {
      'fetch' when fetchFails => (code: 128, out: '', err: 'private diagnostic'),
      'config' => (code: 0, out: '${inDirectory!.endsWith('access.git') ? _accessUrl : _url}\n', err: ''),
      'show' => (code: 0, out: _projectYaml, err: ''),
      'rev-parse' => (code: 0, out: '$head\n', err: ''),
      'cat-file' => (code: held.contains(arguments.last.split('^').first) ? 0 : 1, out: '', err: ''),
      'merge-base' => (code: held.contains(arguments[2]) ? 0 : 1, out: '', err: ''),
      'log' when arguments.contains('-1') => (
        code: 0,
        out: '${history.where((each) => each.$1 == arguments.last).firstOrNull?.$2 ?? ''}\n',
        err: '',
      ),
      'log' => (code: 0, out: [for (final (commit, id) in history) '$commit $id'].join('\n'), err: ''),
      _ => (code: 0, out: '', err: ''),
    };
  }

  List<List<String>> named(String program, [String? verb]) => [
    for (final call in calls)
      if (call.first == program && (verb == null || call[1] == verb)) call,
  ];
}

IdentityCard _card({AgentState agent = AgentState.holds, bool revoked = false}) => IdentityCard(
  login: 'alice',
  name: 'Alice',
  email: null,
  fingerprint: HostFiles.signingFingerprint(_alice),
  key: _alice,
  created: '2026-10-31',
  expires: '2026-11-30',
  predecessor: null,
  card: 'login: "alice"\n',
  agent: agent,
  agentWord: agent.name,
  revoked: revoked,
  cardRefused: null,
  registry: const [],
  forge: null,
  pending: const [],
);

ProjectAccessChange _change(String action, {String base = _base}) => ProjectAccessChange(
  id: _id,
  project: 'demo',
  host: 'orchard',
  hostCard: PreparedHost.card({
    'host': 'orchard',
    'address': '203.0.113.7',
    'ssh_port': 22,
    'ssh_host_key': _hostKey,
    'services': {
      'forge': {'web_port': 3000, 'git_port': 3001},
      'matrix': {'port': 8448},
    },
  }),
  repository: _accessUrl,
  projectRevision: _project,
  baseRevision: base,
  actor: 'alice',
  actorFingerprint: HostFiles.signingFingerprint(_alice),
  action: action,
  person: action == 'register'
      ? null
      : AccessDeveloper(login: 'bob', role: 'developer', fingerprint: HostFiles.signingFingerprint(_bob)),
);

void main() {
  late Directory root;
  late _Here here;
  late Registry registry;
  late IdentityCard card;
  late CoreProjectAccess core;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('project-access-core-');
    here = _Here();
    card = _card();
    registry = Registry(checkout: _Checkout(), core: _RegistryCore());
    await registry.refresh();
    core = CoreProjectAccess(
      registry: () => registry,
      identity: () async => card,
      copies: ProjectCopies(root: path.join(root.path, 'copies'), run: here.run),
      run: here.run,
      agentKeys: () async => [_alice],
    );
  });

  tearDown(() async {
    registry.dispose();
    await root.delete(recursive: true);
  });

  String copy(String which) => path.join(root.path, 'copies', 'demo', '$which.git');

  // Harm: verifying copies against keys or commits other than those this computer's follow holds in force, or
  // another project's, would let a rewritten history or a retired key decide who may change access.
  test('read verifies the copies against the follow in force and joins the registry admission', () async {
    final view = await core.read('demo');
    expect(here.named('porelo', 'project').first, ['porelo', 'project', 'following', '--json']);
    expect(here.named('porelo', 'project')[1], [
      'porelo',
      'project',
      'verify',
      '--repository',
      copy('project'),
      '--signed-by',
      _alice,
      '--project',
      'demo',
      '--since',
      _project,
      '--access-repository',
      copy('access'),
      '--access-since',
      _base,
      '--json',
    ]);
    expect(here.named('git').where((call) => call[1] == 'clone').map((call) => call.sublist(5)), [
      [_url, copy('project')],
      [_accessUrl, copy('access')],
    ]);
    expect(view.host.name, 'orchard');
    expect(view.projectRevision, _project);
    expect(view.accessRevision, _base);
    expect(view.actor.login, 'alice');
    expect(view.admittedFingerprint, HostFiles.signingFingerprint(_alice));
    expect(view.canAdmin, isTrue);
    expect(view.adminSigners, [_alice]);
    expect(view.source.access, _accessUrl);
    expect(view.eligible.keys, ['alice', 'bob']);
  });

  // Harm: a project followed without a pinned key, or not followed, would be read as verified access.
  for (final entry in <String, void Function(_Here)>{
    'not followed here': (here) => here.follow['name'] = 'other',
    'followed without a key': (here) => here.follow['verified'] = false,
  }.entries) {
    test('a project ${entry.key} is refused before anything is copied or verified', () async {
      entry.value(here);
      await expectLater(core.read('demo'), throwsA(isA<RegistryRefusal>()));
      expect(here.named('git'), isEmpty);
      expect(here.named('porelo', 'project').where((call) => call[2] == 'verify'), isEmpty);
    });
  }

  // Harm: a revoked key would still be offered to sign access changes.
  test('a revoked card reads no project', () async {
    card = _card(revoked: true);
    await expectLater(core.read('demo'), throwsA(isA<RegistryRefusal>()));
    expect(here.calls, isEmpty);
  });

  // Harm: Core's reason for refusing the verification would be hidden behind a generic retry.
  test('Core refusing the verification is said in its own words', () async {
    here.verifying = (
      code: 65,
      out: '',
      err: 'porelo: commit $_base at access.yml is not signed by a project signer\n',
    );
    await expectLater(
      core.read('demo'),
      throwsA(
        isA<ProjectAccessRetry>().having(
          (e) => e.words,
          'words',
          'commit $_base at access.yml is not signed by a project signer',
        ),
      ),
    );
  });

  // Harm: a registration sent as `add` into a repository holding no access file, or as `init` over one, edits the
  // wrong access state.
  test('before any access file, Register initializes it on the access repository\'s head', () async {
    here.verification
      ..['access_commit'] = ''
      ..['persons'] = <Object?>[]
      ..['admins'] = <String>[];
    final view = await core.read('demo');
    expect(view.accessRevision, _base, reason: 'the head commit the first access file is written on');
    expect(view.canAdmin, isTrue, reason: 'Alice holds a key the project pins');
    expect(await core.file(_change('register')), _filed);
    expect(here.named('porelo', 'project').last, [
      'porelo',
      'project',
      'access',
      'init',
      '--project',
      'demo',
      '--person',
      'alice',
      '--host',
      'orchard',
      '--card',
      path.join(_checkout, 'people', 'alice.card'),
      '--id',
      _id,
      '--json',
    ]);
  });

  test('Add a developer sends the person\'s registry card, the role, the base and the durable id', () async {
    await core.read('demo');
    expect(await core.file(_change('add')), _filed);
    expect(here.named('porelo', 'project').last, [
      'porelo',
      'project',
      'access',
      'add',
      '--project',
      'demo',
      '--person',
      'bob',
      '--host',
      'orchard',
      '--card',
      path.join(_checkout, 'people', 'bob.card'),
      '--role',
      'developer',
      '--base',
      _base,
      '--id',
      _id,
      '--json',
    ]);
  });

  // Harm: a lock or removal signed and pushed while nothing delivers it leaves the host granting what the access file
  // took away.
  for (final action in ['remove', 'lock', 'unlock', 'replace']) {
    test('$action is not sent to Core', () async {
      await core.read('demo');
      final before = here.calls.length;
      await expectLater(
        core.file(_change(action)),
        throwsA(isA<RegistryRefusal>().having((e) => e.words, 'words', CoreProjectAccess.notConnected)),
      );
      expect(here.calls.length, before);
    });
  }

  // Harm: Core's refusal would reach the dialog as a generic failure instead of its own words.
  test('Core refusing the filing reaches the dialog in its own words', () async {
    await core.read('demo');
    here.filing = (
      code: 65,
      out: jsonEncode({'reason': 'card-revoked', 'words': 'Bob\'s card key is revoked.'}),
      err: '',
    );
    await expectLater(
      core.file(_change('add')),
      throwsA(isA<RegistryRefusal>().having((e) => e.words, 'words', 'Bob\'s card key is revoked.')),
    );
  });

  group('the filed commit', () {
    // Harm: an id taken for unfiled while the access repository could not be read would let the same change be
    // signed twice, or a filed one be forgotten.
    test('is looked up by its change id and an unreadable repository keeps the receipt', () async {
      expect(await core.filedRevision(_change('add')), isNull);
      here.history = [(_filed, _id), (_base, '')];
      expect(await core.filedRevision(_change('add')), _filed);
      here.fetchFails = true;
      await expectLater(core.filedRevision(_change('add')), throwsA(isA<ProjectAccessRetry>()));
    });

    // Harm: publishing pushes a commit or claims one the access repository does not hold.
    test('is published only as the exact commit the access repository holds, and never pushed from here', () async {
      await expectLater(core.publish(_change('add'), _filed), throwsA(isA<ProjectAccessRetry>()));
      here.history = [(_filed, _id), (_base, '')];
      await core.publish(_change('add'), _filed);
      expect(await core.publishedRevision(_change('add'), _filed), isTrue);
      expect(here.named('git').where((call) => call[1] == 'push'), isEmpty);
    });

    // Harm: a commit of another change delivered as this one, or a newer access state delivered in its place.
    test('is delivered only when it carries this change\'s id, verified at exactly that commit', () async {
      here.history = [(_filed, 'f' * 32), (_base, '')];
      expect(await core.delivery(_change('add'), _filed), isA<ProjectAccessRevisionRefused>());
      here.history = [(_moved, ''), (_filed, _id), (_base, '')];
      here.verification['access_commit'] = _filed;
      final verdict = await core.delivery(_change('add'), _filed);
      expect(verdict, isA<ProjectAccessAuthorized>());
      expect((verdict as ProjectAccessAuthorized).view.accessRevision, _filed);
      final bundling = here.named('git').where((call) => call[1] == 'update-ref').last;
      expect(bundling, ['git', 'update-ref', 'refs/heads/main', '$_filed^{commit}']);
      final verify = here.named('porelo', 'project').last;
      expect(verify, isNot(contains('--access-since')));
      expect(verify[verify.indexOf('--access-repository') + 1], endsWith('access.bundle'));
    });

    // Harm: a filing the access repository moved past without holding is retried forever, or one still on its way is
    // discarded.
    test('is overtaken only when the access repository moved off its base without it', () async {
      await expectLater(core.delivery(_change('add'), _filed), throwsA(isA<ProjectAccessRetry>()));
      here.history = [(_moved, ''), (_base, '')];
      final verdict = await core.delivery(_change('add'), _filed);
      expect(verdict, isA<ProjectAccessRevisionOvertaken>());
    });
  });
}
