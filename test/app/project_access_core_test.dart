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
const _newer = 'dddddddddddddddddddddddddddddddddddddddd';
const _accepted = 'cccccccccccccccccccccccccccccccccccccccc';
const _id = '0123456789abcdef0123456789abcdef';
const _url = 'git@example.org:team/demo.git';
const _accessUrl = 'git@example.org:team/demo-access.git';
const _checkout = '/private/registry/checkout';
const _otherAccess = 'git@example.org:mallory/access.git';
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

Map<String, Object?> _hostCard(String host) => {
  'host': host,
  'address': '203.0.113.7',
  'ssh_port': 22,
  'ssh_host_key': _hostKey,
  'services': {
    'forge': {'web_port': 3000, 'git_port': 3001},
    'matrix': {'port': 8448},
  },
  'signed_by': HostFiles.signingFingerprint(_alice),
};

class _RegistryCore implements RegistryCore {
  /// Further hosts admitting Alice for demo, each with its card or none.
  Map<String, bool> moreHosts = {};

  /// The people's states, trusted unless named.
  Map<String, String> states = {};

  @override
  Future<RegistryRead> read(String checkout) async => RegistryRead.from({
    'revision': _accepted,
    'people': [
      for (final (login, key) in [('alice', _alice), ('bob', _bob)])
        {
          'login': login,
          'name': login.toUpperCase(),
          'email': '$login@example.org',
          'key': key,
          'fingerprint': HostFiles.signingFingerprint(key),
          'state': states[login] ?? 'trusted',
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
      for (final MapEntry(key: host, value: carded) in moreHosts.entries)
        {
          'host': host,
          'card': carded ? _hostCard(host) : null,
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

  /// The access repository's default branch, newest first, each with its change id or none; empty before its first
  /// commit.
  List<(String, String)> history = [(_base, '')];
  Ran? filing;
  Ran? verifying;
  bool fetchFails = false;

  /// The project file each commit of the project's repository holds; `HEAD` is its newest, unverified one.
  Map<String, String> projectFiles = {'HEAD': _projectYaml};

  /// The key each card in the registry's accepted commit carries.
  Map<String, String> cards = {'alice': _alice, 'bob': _bob};

  /// What git says of a commit's signature, as `%G? %GF`.
  String signature = 'G ${HostFiles.signingFingerprint(_alice)}';

  /// The card file Core was handed, as it read it.
  String? cardSent;

  String? get head => history.firstOrNull?.$1;

  int _at(String commit) => commit == 'HEAD' ? 0 : history.indexWhere((each) => each.$1 == commit);

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
        _ => () {
          if (arguments.contains('--card')) {
            cardSent = File(arguments[arguments.indexOf('--card') + 1]).readAsStringSync();
          }
          return filing ?? (code: 0, out: jsonEncode({'revision': _filed}), err: '');
        }(),
      };
    }
    expect(environment['GIT_CONFIG_GLOBAL'], '/dev/null', reason: 'git runs without the person\'s configuration');
    if (arguments.first == 'clone') Directory(arguments.last).createSync(recursive: true);
    final held = {for (final (commit, _) in history) commit};
    final project = inDirectory?.endsWith('project.git') ?? false;
    return switch (arguments.first) {
      'fetch' when fetchFails => (code: 128, out: '', err: 'private diagnostic'),
      'config' => (code: 0, out: '${inDirectory!.endsWith('access.git') ? _accessUrl : _url}\n', err: ''),
      'ls-remote' => (code: 0, out: head == null ? '' : 'ref: refs/heads/main\tHEAD\n$head\tHEAD\n', err: ''),
      'show' => (code: 0, out: projectFiles[arguments[1].split(':').first] ?? _projectYaml, err: ''),
      'rev-parse' when head == null && !project => (code: 1, out: '', err: ''),
      'rev-parse' => (code: 0, out: '${head ?? _project}\n', err: ''),
      'cat-file' when arguments[1] == 'blob' => (
        code: 0,
        out: () {
          final login = path.basenameWithoutExtension(arguments[2].split(':').last);
          return 'login: "$login"\nkey: "${cards[login]}"\n-----BEGIN SSH SIGNATURE-----\n';
        }(),
        err: '',
      ),
      'cat-file' => (code: project || held.contains(arguments.last.split('^').first) ? 0 : 1, out: '', err: ''),
      'merge-base' when project => (code: 0, out: '', err: ''),
      'merge-base' => (
        code: _at(arguments[2]) >= 0 && _at(arguments[3]) >= 0 && _at(arguments[2]) >= _at(arguments[3]) ? 0 : 1,
        out: '',
        err: '',
      ),
      'rev-list' => (
        code: 0,
        out: () {
          final at = _at(arguments.last.split('^').first);
          return [history[at].$1, if (at + 1 < history.length) history[at + 1].$1].join(' ');
        }(),
        err: '',
      ),
      '-c' => (code: 0, out: '$signature\n', err: ''),
      'log' when arguments.contains('-1') => (
        code: 0,
        out: '${history.where((each) => each.$1 == arguments.last).firstOrNull?.$2 ?? ''}\n',
        err: '',
      ),
      'log' when head == null && !project => (code: 128, out: '', err: 'fatal: bad revision HEAD'),
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
  late _RegistryCore registryCore;
  late IdentityCard card;
  late CoreProjectAccess core;

  CoreProjectAccess coreWith({
    String? Function(String)? pinnedHost,
    bool Function(String)? hostReturned,
    String? krl,
  }) => CoreProjectAccess(
    registry: () => registry,
    identity: () async => card,
    copies: ProjectCopies(root: path.join(root.path, 'copies'), run: here.run),
    run: here.run,
    agentKeys: () async => [_alice],
    pinnedHost: pinnedHost,
    hostReturned: hostReturned,
    krl: krl,
  );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('project-access-core-');
    here = _Here();
    card = _card();
    registryCore = _RegistryCore();
    registry = Registry(checkout: _Checkout(), core: registryCore);
    await registry.refresh();
    core = coreWith();
  });

  tearDown(() async {
    registry.dispose();
    await root.delete(recursive: true);
  });

  String copy(String which) => path.join(root.path, 'copies', 'demo', '$which.git');

  // The private copy of a card Core was handed: in the project's own folder, never the registry checkout's file.
  String cardCopy(String login) {
    final sent = here.named('porelo', 'project').last;
    final file = sent[sent.indexOf('--card') + 1];
    expect(path.dirname(path.dirname(file)), path.join(root.path, 'copies', 'demo'));
    expect(path.basename(file), '$login.card');
    return file;
  }

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
      cardCopy('alice'),
      '--id',
      _id,
      '--json',
    ]);
  });

  // Harm: a project whose access repository was just made, holding no commit, can never get its first access file
  // from here, or gets it filed on a base it does not have.
  test('an access repository holding no commit yet is read as no access file, and Register initializes it', () async {
    here.history = [];
    here.follow['access_commit'] = '';
    here.verification
      ..['access_commit'] = ''
      ..['persons'] = <Object?>[]
      ..['admins'] = <String>[];
    final view = await core.read('demo');
    expect(view.accessRevision, '', reason: 'no commit to write the first access file on');
    expect(view.canAdmin, isTrue, reason: 'Alice holds a key the project pins');
    final change = ProjectAccessChange.read(_change('register', base: '').stored);
    expect(change.baseRevision, '', reason: 'a registration kept and read back keeps its empty base');
    expect(await core.file(change), _filed);
    final init = here.named('porelo', 'project').last;
    expect(init.sublist(0, 4), ['porelo', 'project', 'access', 'init']);
    expect(init, isNot(contains('--base')), reason: 'the first access commit has no base');
  });

  // Harm: a registration whose filing failed before Core made the first commit is stuck for good, as its lookup
  // cannot read an access repository that still holds no commit.
  test('no filed commit is found in an access repository that still holds no commit', () async {
    here.history = [];
    expect(await core.filedRevision(_change('register', base: '')), isNull);
  });

  // Harm: an empty base let through for an edit would file it on no access state at all.
  test('only a registration may be kept without a base', () {
    expect(() => ProjectAccessChange.read(_change('add', base: '').stored), throwsA(isA<FormatException>()));
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
      cardCopy('bob'),
      '--role',
      'developer',
      '--base',
      _base,
      '--id',
      _id,
      '--json',
    ]);
  });

  // Harm: a card the registry did not accept - found in the checkout's working tree after a read that stopped early,
  // or while a key change rewrites it - would be signed into the access file and synced onto the host.
  test(
    'the card Core is handed is the registry\'s accepted one, read from its commit, never the checkout\'s file',
    () async {
      await core.read('demo');
      await core.file(_change('add'));
      final read = here.calls.where((call) => call.take(3).join(' ') == 'git cat-file blob').single;
      expect(read, ['git', 'cat-file', 'blob', '$_accepted:people/bob.card']);
      expect(here.directories[here.calls.indexOf(read)], _checkout);
      expect(here.cardSent, contains('key: "$_bob"'));
      expect(File(cardCopy('bob')).existsSync(), isFalse, reason: 'the copy is removed once Core answered');
    },
  );

  test('an accepted card carrying another key than the one chosen is not handed to Core', () async {
    await core.read('demo');
    here.cards['bob'] = _key(9);
    await expectLater(
      core.file(_change('add')),
      throwsA(isA<RegistryRefusal>().having((e) => e.words, 'words', contains('another key'))),
    );
    expect(here.named('porelo', 'project').where((call) => call[2] == 'access'), isEmpty);
  });

  test('nothing is filed while a key change holds the registry checkout', () async {
    await core.read('demo');
    final holder = Object();
    registry.hold(holder);
    addTearDown(() => registry.release(holder));
    await expectLater(
      core.file(_change('add')),
      throwsA(isA<RegistryRefusal>().having((e) => e.words, 'words', Registry.heldWords)),
    );
    expect(here.calls.where((call) => call.contains('blob') || call.contains('access')), isEmpty);
  });

  // Harm: a key this computer revoked, ahead of Core's own follow, would still be taken as a signer of the project or
  // of its access, and the access it signed delivered to the host.
  test('the revocation list Core\'s follow checks is handed to the verification whenever it is there', () async {
    final krl = path.join(root.path, 'revoked.krl');
    core = coreWith(krl: krl);
    await core.read('demo');
    expect(here.named('porelo', 'project').last, isNot(contains('--krl')));
    await File(krl).writeAsBytes([0]);
    await core.read('demo');
    final verify = here.named('porelo', 'project').last;
    expect(verify.sublist(verify.length - 3), ['--krl', krl, '--json']);
  });

  // Harm: an unsigned commit pushed to the project's repository names another access repository, and this computer
  // reaches it with the person's agent and keeps its copy, before anything was verified.
  test('the access repository is taken from the project file only at commits Core verified', () async {
    here.projectFiles['HEAD'] = _projectYaml.replaceAll(_accessUrl, _otherAccess);
    here.verification['commit'] = _newer;
    await core.read('demo');
    expect(here.named('git').where((call) => call[1] == 'show').map((call) => call[2]), [
      '$_project:project.yml',
      '$_newer:project.yml',
    ]);
    expect(here.named('git').where((call) => call[1] == 'clone').map((call) => call[5]), [_url, _accessUrl]);
  });

  // Harm: an access change goes, with the project's private bundles, to a host the project is not registered on here,
  // or a host given back or without a card blocks the one it is.
  test('the admitting host is the one the project is registered on here', () async {
    registryCore.moreHosts = {'grove': true};
    await registry.refresh();
    await expectLater(core.read('demo'), throwsA(isA<RegistryRefusal>()));
    expect((await coreWith(pinnedHost: (_) => 'orchard').read('demo')).host.name, 'orchard');
    expect((await coreWith(pinnedHost: (_) => 'grove').read('demo')).host.name, 'grove');
  });

  test('a host given back, or one without an accepted card, admits nothing', () async {
    registryCore.moreHosts = {'grove': true, 'shed': false};
    await registry.refresh();
    expect((await coreWith(hostReturned: (host) => host == 'grove').read('demo')).host.name, 'orchard');
  });

  // Harm: a name and an address from a card the registry does not trust are shown as whom to ask.
  test('whom to ask is named from trusted cards only', () async {
    registryCore.states = {'alice': 'first-seen'};
    await registry.refresh();
    final view = await core.read('demo');
    expect(view.whoMay.single.login, 'alice');
    expect(view.whoMay.single.name, 'alice');
    expect(view.whoMay.single.email, isNull);
  });

  // Harm: why the project's address was refused is replaced by a generic failure.
  test('a followed address refused as a source is said in its own words', () async {
    here.follow['url'] = 'ext::sh -c evil';
    await expectLater(
      core.read('demo'),
      throwsA(isA<RegistryRefusal>().having((e) => e.words, 'words', contains('credential-free HTTPS'))),
    );
    expect(here.named('git'), isEmpty);
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
    // The access repository after Core filed Bob's addition, and Core's verification of it.
    void filedAsMade() {
      here.history = [(_filed, _id), (_base, '')];
      here.verification
        ..['access_commit'] = _filed
        ..['persons'] = [_person('alice', _alice, 'admin'), _person('bob', _bob, 'developer')];
    }

    // Harm: an id taken for unfiled while the access repository could not be read would let the same change be
    // signed twice, or a filed one be forgotten.
    test('is looked up by its change id and an unreadable repository keeps the receipt', () async {
      expect(await core.filedRevision(_change('add')), isNull);
      filedAsMade();
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

    // Harm: a newer access state delivered in the filed one's place, or one Core checked without the access in force.
    test(
      'is delivered as exactly that commit, verified from the access in force here and signed by the actor',
      () async {
        filedAsMade();
        here.history = [(_moved, ''), ...here.history];
        final verdict = await core.delivery(_change('add'), _filed);
        expect(verdict, isA<ProjectAccessAuthorized>());
        expect((verdict as ProjectAccessAuthorized).view.accessRevision, _filed);
        final bundling = here.named('git').where((call) => call[1] == 'update-ref').last;
        expect(bundling, ['git', 'update-ref', 'refs/heads/main', '$_filed^{commit}']);
        final verify = here.named('porelo', 'project').last;
        expect(verify[verify.indexOf('--access-repository') + 1], endsWith('access.bundle'));
        expect(verify[verify.indexOf('--access-since') + 1], _base);
        final signed = here.calls.where((call) => call.first == 'git' && call[1] == '-c').single;
        expect(signed.sublist(signed.length - 4), [
          '-1',
          '--no-show-signature',
          '--format=%G? %GF',
          '$_filed^{commit}',
        ]);
        expect(signed[2], startsWith('gpg.ssh.allowedSignersFile='));
      },
    );

    // Harm: a commit someone else made under this change's id - on another base, with the id twice or beside another,
    // signed by another key, or granting another person, role or key - is delivered to the host and confirmed as this
    // change.
    for (final entry in <String, void Function(_Here)>{
      'of another change': (here) => here.history = [(_filed, 'f' * 32), (_base, '')],
      'made on another base': (here) => here.history = [(_filed, _id), (_moved, ''), (_base, '')],
      'carrying the id twice': (here) => here.history = [(_filed, '$_id,$_id'), (_base, '')],
      'carrying another id beside it': (here) => here.history = [(_filed, '$_id,${'f' * 32}'), (_base, '')],
      'signed by another key': (here) => here.signature = 'G ${HostFiles.signingFingerprint(_bob)}',
      'whose signature git does not take': (here) => here.signature = 'U ${HostFiles.signingFingerprint(_alice)}',
      'granting the person as admin': (here) => here.verification
        ..['persons'] = [_person('alice', _alice, 'admin'), _person('bob', _bob, 'admin')]
        ..['admins'] = ['alice', 'bob'],
      'granting the person another key': (here) =>
          here.verification['persons'] = [_person('alice', _alice, 'admin'), _person('bob', _key(9), 'developer')],
      'not granting the person': (here) => here.verification['persons'] = [_person('alice', _alice, 'admin')],
    }.entries) {
      test('a commit ${entry.key} is refused, never delivered or adopted', () async {
        filedAsMade();
        entry.value(here);
        expect(await core.delivery(_change('add'), _filed), isA<ProjectAccessRevisionRefused>());
        if (here.history.first.$2.contains(_id)) {
          await expectLater(core.filedRevision(_change('add')), throwsA(isA<RegistryRefusal>()));
        }
      });
    }

    // Harm: the first access commit, which has no parent, is never adopted, or a commit with a parent is taken as
    // the first.
    test('the first access commit of an empty repository is adopted only without a parent', () async {
      here.follow['access_commit'] = '';
      here.history = [(_filed, _id)];
      here.verification
        ..['access_commit'] = _filed
        ..['persons'] = [_person('alice', _alice, 'admin')];
      expect(await core.delivery(_change('register', base: ''), _filed), isA<ProjectAccessAuthorized>());
      here.history = [(_filed, _id), (_base, '')];
      expect(await core.delivery(_change('register', base: ''), _filed), isA<ProjectAccessRevisionRefused>());
    });

    // Harm: a commit without a parent taken as an edit's own, though only a registration starts an access file.
    test('a commit without a parent is never adopted for an edit with no base', () async {
      here.follow['access_commit'] = '';
      here.history = [(_filed, _id)];
      here.verification
        ..['access_commit'] = _filed
        ..['persons'] = [_person('alice', _alice, 'admin'), _person('bob', _bob, 'developer')];
      expect(await core.delivery(_change('add', base: ''), _filed), isA<ProjectAccessRevisionRefused>());
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
