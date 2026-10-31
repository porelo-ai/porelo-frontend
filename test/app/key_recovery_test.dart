import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/access_developers.dart';
import 'package:porelo_frontend/src/app/host_access.dart';
import 'package:porelo_frontend/src/app/host_access_contract.dart';
import 'package:porelo_frontend/src/app/key_recovery.dart';
import 'package:porelo_frontend/src/app/project_access_contract.dart';
import 'package:porelo_frontend/src/app/registry.dart';
import 'package:porelo_frontend/src/app/registry_checkout.dart';
import 'package:porelo_frontend/src/app/run_here.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_host/porelo_host.dart' show PreparedHost;

import '../support/host_registry.dart' show sshCompletion;

const _base = '1111111111111111111111111111111111111111';
const _revision = '2222222222222222222222222222222222222222';
const _other = '3333333333333333333333333333333333333333';
const _project = '4444444444444444444444444444444444444444';
const _checkout = '/private/registry/checkout';
const _backupFile = '/media/usb/porelo-backup';

// Built as the code builds it, so the expected arguments hold on Windows too.
final _bobCard = path.join(_checkout, 'people', 'bob.card');

/// An Ed25519 public key whose 32 key bytes are all [byte], shaped as OpenSSH writes it.
String _key(int byte) =>
    'ssh-ed25519 ${base64.encode([
      ...[0, 0, 0, 11],
      ...utf8.encode('ssh-ed25519'),
      ...[0, 0, 0, 32],
      ...List.filled(32, byte),
    ])}';

final _oldKey = _key(1);
final _newKey = _key(2);
final _adminKey = _key(3);
final _backupKey = _key(4);
final _old = sshFingerprint(_oldKey);
final _new = sshFingerprint(_newKey);
final _admin = sshFingerprint(_adminKey);

RegistryCard _card(String login, String key, {String state = 'trusted', String why = ''}) => RegistryCard(
  login: login,
  name: 'Name of $login',
  key: key,
  fingerprint: sshFingerprint(key),
  state: state,
  why: why,
);

RecoverySituation _situation({
  RecoveryScope scope = const RecoveryScope.project('demo'),
  List<RegistryCard>? cards,
  List<String> hosts = const ['walk1', 'walk2', 'walk3'],
  String? sole,
  bool backup = false,
  String actor = 'alice',
  bool resumeOnly = false,
}) => RecoverySituation(
  scope: scope,
  people: {'alice': _admin, 'bob': _old},
  cards: cards ?? [_card('alice', _adminKey), _card('bob', _newKey)],
  base: _base,
  actor: HostAdminIdentity(actor, actor == 'bob' ? _new : _admin),
  hosts: {'alice': hosts, 'bob': hosts},
  checkout: _checkout,
  soleAdmin: sole,
  backupRegistered: backup,
  resumeOnly: resumeOnly,
  // A project's backup key changes its own repository, read at another commit than its access file.
  backupBase: scope.kind == RecoveryKind.project ? _project : null,
);

/// The interface's settings over a store the test reads back whole.
class _Kept {
  final store = MemorySettingsStore();
  late final settings = Settings(store);
  late final receipts = SettingsReceipts(settings);

  Future<String> written() async => jsonEncode(await store.read());

  /// The same kept requests as a program started again reads them, with nothing of the earlier one running.
  Future<SettingsReceipts> restarted() async {
    final again = Settings(store);
    await again.load();
    return SettingsReceipts(again);
  }
}

/// Core's side as the controller sees it; every call is recorded.
class _Core implements KeyRecoveryCore {
  final calls = <String>[];
  RegistryRefusal? refuse;
  final answers = <Object>[];
  Exception? publishFails;
  // An answer that never comes: the program ends while Core runs.
  Completer<RecoveryFiled>? holdAnswer;
  // The list or card as read now moved past the review; how often it was checked.
  RecoveryRefused? moved;
  var checks = 0;

  @override
  Future<RegistryRefusal?> refusal(RecoveryScope scope, {bool backup = false}) async {
    calls.add(backup ? 'refusal backup' : 'refusal');
    return refuse;
  }

  @override
  Future<String?> fileFor(RecoveryReview review) async =>
      review.scope.inRegistry ? 'the file for ${review.login}' : null;

  @override
  Future<void> checkReviewed(RecoveryReview review) async {
    checks++;
    if (moved case final refused?) throw refused;
  }

  @override
  Future<RecoveryFiled> replace(RecoveryReview review, String id, {String? content, bool again = false}) async {
    calls.add('replace $id ${review.base}');
    if (holdAnswer case final held?) return held.future;
    final answer = answers.isEmpty ? const RecoveryFiled(revision: _revision, published: true) : answers.removeAt(0);
    if (answer is Exception) throw answer;
    return answer as RecoveryFiled;
  }

  @override
  Future<void> prepare(RecoveryScope scope) async => calls.add('prepare');

  @override
  Future<void> publish(RecoveryScope scope, String revision, {required String base}) async {
    calls.add('publish $revision $base');
    if (publishFails case final failure?) throw failure;
  }

  @override
  void hold(Object holder) {}

  @override
  void release(Object holder) {}
}

/// The hosts, answering per host what the test says: a [HostLock], or a throw for one not reached or broken.
class _Hosts implements RevocationHosts {
  final calls = <String>[];
  final answers = <String, Object>{};

  @override
  Future<HostLock> deliver(RecoveryReview review, String host, String revision) async {
    calls.add('$host $revision ${review.login}');
    final answer = answers[host] ?? HostReplaced(host);
    if (answer is Exception) throw answer;
    if (answer is Error) throw answer;
    return answer as HostLock;
  }
}

/// Core's `porelo` as the fake runner answering exactly the contracts' JSON.
class _Porelo {
  final calls = <List<String>>[];
  final replaceAnswers = <Ran>[];
  List<String> admins = ['alice'];

  /// The card file each replacement was handed, with its text and its folder's mode as Core met them.
  final handed = <({String file, String text, int folderMode})>[];

  /// Runs as a replacement starts, before Core reads its card: what moves meanwhile.
  void Function()? onReplace;

  Map<String, Object?> get _verified => {
    'project': 'demo',
    'commit': 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    'access_commit': _base,
    'persons': [
      {
        'login': 'alice',
        'ssh': _adminKey,
        'role': admins.contains('alice') ? 'admin' : 'developer',
        'hosts': ['walk1'],
        'expires': '2030-01-01T00:00:00Z',
        'revoked': false,
        'locked': false,
      },
      {
        'login': 'bob',
        'ssh': _oldKey,
        'role': 'developer',
        'hosts': ['walk1'],
        'expires': '2030-01-01T00:00:00Z',
        'revoked': false,
        'locked': false,
      },
    ],
    'admins': admins,
    'certifiers': <String>[],
    'signers': [_adminKey],
  };

  Future<Ran> run(
    String program,
    List<String> arguments, {
    String? inDirectory,
    Map<String, String> environment = const {},
    String? input,
  }) async {
    calls.add([program, ...arguments]);
    if (arguments.take(2).join(' ') == 'project verify') return (code: 0, out: jsonEncode(_verified), err: '');
    if (arguments.take(3).join(' ') == 'project access replace') {
      onReplace?.call();
      final card = arguments[arguments.indexOf('--card') + 1];
      handed.add((file: card, text: File(card).readAsStringSync(), folderMode: File(card).parent.statSync().mode));
      if (replaceAnswers.isNotEmpty) return replaceAnswers.removeAt(0);
      return (code: 0, out: jsonEncode({'revision': _revision}), err: '');
    }
    return (code: 64, out: '', err: 'unexpected call');
  }

  /// Each replacement's call, its card named by the text Core was handed: each attempt hands a copy of its own.
  List<List<String>> get replaces {
    final made = [
      for (final call in calls)
        if (call.skip(1).take(3).join(' ') == 'project access replace') call,
    ];
    return [
      for (final (i, call) in made.indexed)
        [for (final argument in call) argument == handed[i].file ? 'card: ${handed[i].text}' : argument],
    ];
  }
}

/// Core's project verbs over [porelo], beside a registry read whose cards are the ones the replacement is checked by.
Future<CliKeyRecoveryCore> _cliProject(_Porelo porelo) async {
  final registry = Registry(checkout: _Checkout(), core: _RegistryCore());
  addTearDown(registry.dispose);
  await registry.refresh();
  return _cliProjectOver(porelo, registry);
}

/// Bob's new card as the registry checkout holds it: its body, then its signature.
String _cardOf(String key) =>
    'login: "bob"\nname: "Name of bob"\nkey: "$key"\ncreated: "2026-10-31"\nexpires: "2026-11-30"\n'
    '-----BEGIN SSH SIGNATURE-----\nU1NIU0lH\n-----END SSH SIGNATURE-----\n';

CliKeyRecoveryCore _cliProjectOver(_Porelo porelo, Registry registry, {String Function()? card}) => CliKeyRecoveryCore(
  actor: () => HostAdminIdentity('alice', _admin),
  registry: registry,
  run: porelo.run,
  readFile: (file) async => file == _bobCard ? (card?.call() ?? _cardOf(_newKey)) : throw FileSystemException(file),
  project: (project) => ProjectAccessCoreAdapter(
    directory: '/workspace/$project',
    run: porelo.run,
    source: ProjectVerifySource(repository: '/workspace/demo.bundle', signedBy: [_adminKey]),
    registryCheckout: _checkout,
    agentKeys: () async => [_adminKey],
  ),
);

/// The registry checkout: records prepare and push; a push can be made to fail.
///
/// [made] is a commit Core made here and nobody pushed, refused as the real checkout refuses it: by a fresh filing
/// always, by a retry unless it is that request's own file on its base.
class _Checkout implements RegistryCheckout {
  final calls = <String>[];
  WorkspaceRefused? refusePush;
  WorkspaceRefused? refuseFetch;
  ({String base, String file, String content})? made;

  /// How often it was fetched; a fetch waits for [fetching] while given.
  var fetches = 0;
  Completer<void>? fetching;

  static const _unpublished = WorkspaceRefused('The registry checkout holds a commit the repository does not.');

  @override
  String get root => '/private/registry';

  @override
  String get repository => 'git@example.org:team/registry.git';

  @override
  String get folder => _checkout;

  @override
  Future<String> fetch() async {
    fetches++;
    await fetching?.future;
    if (refuseFetch case final refused?) throw refused;
    return _base;
  }

  @override
  Future<void> prepareFiling() async {
    calls.add('prepare');
    if (made != null) throw _unpublished;
  }

  @override
  Future<void> prepareRetry({required String base, required String file, required String content}) async {
    calls.add('prepare again $file');
    if (made case final held? when held != (base: base, file: file, content: content)) throw _unpublished;
  }

  @override
  Future<void> publish(String revision) async => calls.add('publish $revision');

  @override
  Future<void> publishMade(String revision, {required String base}) async {
    calls.add('push $revision $base');
    if (refusePush case final refused?) throw refused;
  }
}

/// Core's registry read and file: the read as `registry read --json` answers it, each filing recorded.
class _RegistryCore implements RegistryCore {
  final filed = <RegistryFiling>[];
  final fileFailures = <Exception>[];

  /// A filing waits for it while given: Core still commits.
  Completer<void>? filing;
  String bobState = 'trusted';
  String revision = _base;
  String bobKey = _newKey;

  @override
  Future<RegistryRead> read(String checkout) async => RegistryRead.from({
    'revision': revision,
    'people': [
      {'login': 'alice', 'name': 'Alice', 'key': _adminKey, 'fingerprint': _admin, 'state': 'trusted'},
      {'login': 'bob', 'name': 'Bob', 'key': bobKey, 'fingerprint': sshFingerprint(bobKey), 'state': bobState},
    ],
    'owners': [
      {'login': 'alice', 'fingerprint': _admin, 'backup': false},
      {'login': 'bob', 'fingerprint': _old, 'backup': false},
    ],
    'host_admins': {
      'walk1': [
        {'login': 'alice', 'fingerprint': _admin, 'backup': false},
        {'login': 'bob', 'fingerprint': _old, 'backup': false},
      ],
    },
    'warnings': <String>[],
    'hosts': [
      {
        'host': 'walk1',
        'card': null,
        'admins': [
          {'login': 'alice', 'fingerprint': _admin},
          {'login': 'bob', 'fingerprint': _old},
        ],
        'projects': [
          {'name': 'demo', 'admin': 'alice', 'access_repository': 'git@example.org:team/demo-access.git'},
        ],
      },
    ],
  });

  @override
  Future<RegistryFiled> file(String checkout, RegistryFiling filing) async {
    filed.add(filing);
    await this.filing?.future;
    if (fileFailures.isNotEmpty) throw fileFailures.removeAt(0);
    return const RegistryFiled(revision: _revision);
  }
}

final _owners = [
  'owners:',
  '  - login: alice',
  '    key: "$_adminKey"',
  '  - login: bob',
  '    key: "$_oldKey"',
  '  - login: bob',
  '    key: "$_backupKey"',
  '    backup: true',
  'host_admins:',
  '  walk1:',
  '    - login: alice',
  '      key: "$_adminKey"',
  '    - login: bob',
  '      key: "$_oldKey"',
  '',
].join('\n');

/// The backup-key use answer exactly as Core's contract shapes it.
String _used({
  String id = 'ID',
  String kind = 'project',
  String? name = 'demo',
  String? replaced,
  String? by,
  bool pushed = true,
  String revision = _revision,
}) => jsonEncode({
  'id': id,
  'scope': {'kind': kind, 'name': name},
  'revision': revision,
  'pushed': pushed,
  'replaced': replaced ?? _old,
  'by': by ?? _new,
});

String _idOf(List<String> command) => command[command.indexOf('--id') + 1];

/// The host's registry intake: records what it is given and answers what the test says it applied.
class _Transport implements HostRegistryTransport {
  final calls = <String>[];
  final uploaded = <String>{};
  String applied = _revision;
  String? answeringFor;
  Map<String, String> people = const {'bob': 'active'};

  @override
  Future<void> upload(String host, String revision) async {
    calls.add('upload $host $revision');
    uploaded.add('$host $revision');
  }

  @override
  Future<HostRegistryStatus> sync(String host, String revision) async {
    calls.add('sync $host $revision');
    // A sync of a revision never uploaded applies nothing new.
    final answered = uploaded.contains('$host $revision') ? applied : _other;
    return HostRegistryStatus(host: answeringFor ?? host, revision: answered, people: people, words: '');
  }

  @override
  Future<HostRegistryStatus> status(String host) async =>
      HostRegistryStatus(host: host, revision: applied, people: people, words: '');
}

void main() {
  group('the backup key replaces only its own entry, after review', () {
    late _Kept kept;
    setUp(() => kept = _Kept());

    KeyRecovery backupRecovery(
      _Core core,
      _Hosts hosts, {
      RecoveryScope scope = const RecoveryScope.project('demo'),
      RecoveryReceipts? receipts,
    }) {
      final recovery = KeyRecovery(
        situation: _situation(scope: scope, sole: 'bob', backup: true, actor: 'bob'),
        core: core,
        hosts: hosts,
        receipts: receipts ?? kept.receipts,
      );
      addTearDown(recovery.dispose);
      return recovery;
    }

    Future<(KeyRecovery, _Core, _Hosts, List<String>)> started({
      RecoveryScope scope = const RecoveryScope.project('demo'),
    }) async {
      final core = _Core();
      final hosts = _Hosts();
      final recovery = backupRecovery(core, hosts, scope: scope);
      recovery.reviewFor('bob', backup: true);
      final command = await recovery.startBackup(_backupFile);
      return (recovery, core, hosts, command!);
    }

    // Harm: Core's backup-key answer for another key, list or request carried on to a push or a host sync, which
    // would extend the backup key's authority beyond the one entry it may change; or, as Core ran, its request
    // dropped, so the next attempt makes a second commit.
    for (final (what, answer) in [
      ('another old key', (String id) => _used(id: id, kind: 'registry', name: null, replaced: _admin, pushed: false)),
      ('another new key', (String id) => _used(id: id, kind: 'registry', name: null, by: _admin, pushed: false)),
      ('another list', (String id) => _used(id: id, kind: 'host', name: 'walk1', pushed: false)),
      ('another request', (String id) => _used(id: 'other', kind: 'registry', name: null, pushed: false)),
      ('a push it never makes', (String id) => _used(id: id, kind: 'registry', name: null)),
    ]) {
      test('an answer naming $what is refused before publication and host sync', () async {
        final (recovery, core, hosts, command) = await started(scope: const RecoveryScope.owner());

        await recovery.backupEnded(code: 0, lastLine: answer(_idOf(command)));

        expect(core.calls, ['refusal backup', 'prepare'], reason: 'nothing published');
        expect(hosts.calls, isEmpty, reason: 'nothing delivered');
        expect(recovery.filed, isNull);
        expect(recovery.problem, contains('backup key changes only its own entry'));
        expect(recovery.requestId, _idOf(command), reason: 'Core ran: its commit may exist');
        expect(await kept.written(), contains(_idOf(command)));
      });
    }

    // Harm: a project commit Core pushed for another entry reaching the hosts as if it were the reviewed one.
    test('a project answer for another entry is never delivered to a host', () async {
      final (recovery, core, hosts, command) = await started();

      await recovery.backupEnded(
        code: 0,
        lastLine: _used(id: _idOf(command), replaced: _admin),
      );

      expect(hosts.calls, isEmpty);
      expect(core.calls, ['refusal backup']);
      expect(recovery.problem, contains('Nothing is delivered to a host'));
      expect(recovery.requestId, _idOf(command), reason: 'Core ran: its commit may exist');
      expect(await kept.written(), contains(_idOf(command)));
    });

    // Harm: the backup key used without the person seeing and confirming the replacement, or a stolen key's new
    // card taken without its fingerprint confirmed in person.
    test('the terminal opens only for a reviewed replacement, a stolen one only once confirmed in person', () async {
      final core = _Core();
      final recovery = backupRecovery(core, _Hosts());

      expect(await recovery.startBackup(_backupFile), isNull, reason: 'nothing is reviewed');
      recovery.reviewFor('bob', stolen: true, backup: true);
      expect(await recovery.startBackup(_backupFile), isNull, reason: 'not confirmed in person');
      expect(core.calls, isEmpty);
      expect(await recovery.startBackup(_backupFile, toldInPerson: true), isNotNull);
    });

    // Harm: a terminal that never started Core, or one Core refused, keeping a request, so Cancel stays blocked and
    // Retry is offered.
    for (final (begun, code, out) in [
      (false, null, ''),
      (true, 64, ''),
      (true, 65, '{"reason":"wrong-passphrase","words":"the backup file did not open"}'),
      (true, 66, ''),
    ]) {
      test('a terminal ending with ${begun ? code : 'Core never started'} keeps no request, so Cancel works and no '
          'Retry is offered', () async {
        final (recovery, core, hosts, _) = await started();

        await recovery.backupEnded(code: code, lastLine: out, started: begun);

        expect(recovery.requestId, isNull);
        expect(recovery.filed, isNull);
        expect(recovery.whyNotRetry, isNotNull);
        expect(await kept.written(), isNot(contains('"bob"')), reason: 'no request is kept');
        expect(hosts.calls, isEmpty);
        recovery.cancel();
        expect(recovery.review, isNull);
      });
    }

    // Harm: a Retry after a backup attempt signing with the agent's key, or making a second commit.
    for (final (code, out) in [(69, ''), (70, ''), (0, '{"id":')]) {
      test('Retry after exit $code goes only through the backup key, under the same request', () async {
        final (recovery, core, hosts, command) = await started(scope: const RecoveryScope.owner());

        await recovery.backupEnded(code: code, lastLine: out);
        expect(recovery.retriesInTerminal, isTrue);
        expect(recovery.problem, contains('Core may have made the commit already'));
        await recovery.retry();
        expect(core.calls, isNot(contains(startsWith('replace'))));

        final again = await recovery.startBackup(_backupFile);
        expect(_idOf(again!), _idOf(command));
        expect(core.calls.where((call) => call == 'refusal backup'), hasLength(2));
        expect(core.calls.where((call) => call == 'prepare'), hasLength(1), reason: 'a made commit is not refused');
        expect(core.calls, isNot(contains(startsWith('replace'))));
      });
    }

    // Harm: after an end that may have made the commit, a cancelled, refused or mismatched retry dropping the request,
    // so the next attempt mints a new request and makes a second commit.
    for (final (what, code, out) in [
      ('put away', -1, ''),
      ('wrong passphrase', 65, '{"reason":"wrong-passphrase","words":"no"}'),
      ('unreadable file', 66, ''),
      ('answer for another key', 0, null),
    ]) {
      test('after an uncertain end, a $what retry keeps the request and its base', () async {
        final (recovery, core, hosts, command) = await started(scope: const RecoveryScope.owner());
        await recovery.backupEnded(code: 70, lastLine: '');

        final again = await recovery.startBackup(_backupFile);
        expect(_idOf(again!), _idOf(command));
        final wrong = _used(id: _idOf(command), kind: 'registry', name: null, replaced: _admin, pushed: false);
        await recovery.backupEnded(code: code, lastLine: out ?? wrong);

        expect(recovery.requestId, _idOf(command));
        expect(recovery.retriesInTerminal, isTrue);
        expect(recovery.problem, contains('request is kept'));
        expect(await kept.written(), contains(_idOf(command)));
        final third = await recovery.startBackup(_backupFile);
        expect(_idOf(third!), _idOf(command));
        expect(third.sublist(third.indexOf('--base'), third.indexOf('--base') + 2), ['--base', _base]);
        expect(core.calls.where((call) => call == 'prepare'), hasLength(1), reason: 'a made commit is not refused');
        expect(hosts.calls, isEmpty);
      });
    }

    // Harm: the exact reviewed replacement left unpublished or undelivered.
    test('exactly the reviewed replacement is published and delivered', () async {
      final (recovery, core, hosts, command) = await started(scope: const RecoveryScope.owner());

      await recovery.backupEnded(
        code: 0,
        lastLine: _used(id: _idOf(command), kind: 'registry', name: null, pushed: false),
      );

      expect(core.calls, ['refusal backup', 'prepare', 'publish $_revision $_base']);
      expect(hosts.calls, ['walk1 $_revision bob', 'walk2 $_revision bob', 'walk3 $_revision bob']);
      expect(recovery.allConfirmed, isTrue);
    });

    // Harm: the backup file read here, its place kept anywhere after the command, or more than its path reaching Core.
    test('only the backup file’s path reaches the command, and it is kept nowhere', () async {
      // A real backup file this program cannot read: any read of it here fails the attempt.
      final folder = await Directory.systemTemp.createTemp('backup-');
      addTearDown(() => folder.delete(recursive: true));
      final backupFile = '${folder.path}/porelo-backup';
      await File(backupFile).writeAsString('SECRET-BACKUP-KEY');
      await Process.run('chmod', ['000', backupFile]);
      final core = _Core();
      final hosts = _Hosts();
      final recovery = backupRecovery(core, hosts);
      recovery.reviewFor('bob', backup: true);
      final command = (await recovery.startBackup(backupFile))!;
      expect(recovery.problem, isNull);

      expect(command, [
        'porelo',
        'identity',
        'backup-key',
        '--project',
        'demo',
        '--use',
        backupFile,
        '--card',
        _bobCard,
        '--base',
        _project,
        '--id',
        _idOf(command),
        '--json',
      ]);
      final unread = isNot(anyOf(contains(folder.path), contains('SECRET')));
      expect(await kept.written(), contains(_idOf(command)), reason: 'the request is kept');
      expect(await kept.written(), unread);
      await recovery.backupEnded(code: 69, lastLine: '');
      expect(await kept.written(), unread);
      expect(recovery.problem, unread);
      expect(await recovery.startBackup(''), isNull, reason: 'the retry asks the file again; none is remembered');
      await recovery.startBackup(backupFile);
      await recovery.backupEnded(code: 0, lastLine: _used(id: _idOf(command)));
      expect(recovery.problem, isNull);
      expect(recovery.allConfirmed, isTrue);
      expect(await kept.written(), unread);
    });

    // Harm: an exit-0 answer that fails the checks taken as proof that nothing was made, so a put-away retry drops the
    // request and the next attempt makes a second commit.
    test('after an exit-0 answer that fails the checks, a put-away retry keeps the request', () async {
      final (recovery, core, hosts, command) = await started(scope: const RecoveryScope.owner());
      final unreadable = _used(id: _idOf(command), kind: 'registry', name: null, pushed: false, revision: 'HEAD');

      await recovery.backupEnded(code: 0, lastLine: unreadable);
      expect(recovery.filed, isNull);
      final again = await recovery.startBackup(_backupFile);
      await recovery.backupEnded(code: -1, lastLine: '');

      expect([_idOf(again!), recovery.requestId], [_idOf(command), _idOf(command)]);
      expect(await kept.written(), contains(_idOf(command)));
      expect(hosts.calls, isEmpty);
    });

    // Harm: the program ending while the backup key's terminal runs Core, leaving a request kept as certain, so a
    // put-away retry after the restart drops it and the next attempt makes a second commit.
    test('a request is kept as uncertain while its terminal runs, so a retry after a restart keeps it', () async {
      final (_, _, _, command) = await started(scope: const RecoveryScope.owner());
      final restarted = backupRecovery(
        _Core(),
        _Hosts(),
        scope: const RecoveryScope.owner(),
        receipts: await kept.restarted(),
      );

      final again = await restarted.startBackup(_backupFile);
      await restarted.backupEnded(code: -1, lastLine: '');

      expect([_idOf(again!), restarted.requestId], [_idOf(command), _idOf(command)]);
      expect(await kept.written(), contains(_idOf(command)));
    });

    // Harm: a kept request stuck for good after Core proved no commit exists under it, blocking the list's recovery.
    for (final reason in ['base-moved', 'not-in-this-release']) {
      test('after an uncertain end, Core’s $reason drops the request', () async {
        final (recovery, _, _, command) = await started(scope: const RecoveryScope.owner());
        await recovery.backupEnded(code: 70, lastLine: '');
        await recovery.startBackup(_backupFile);

        await recovery.backupEnded(code: 65, lastLine: '{"reason":"$reason","words":"no"}');

        expect(recovery.requestId, isNull);
        expect(await kept.written(), isNot(contains(_idOf(command))));
        recovery.cancel();
        expect(recovery.review, isNull);
      });
    }

    // Harm: a kept uncertain request no one can ever drop, so the list cannot be recovered at all; or one dropped
    // while its terminal may still be making the commit.
    test('a kept uncertain request is dropped only by Forget, never while its terminal runs', () async {
      final (recovery, core, _, command) = await started(scope: const RecoveryScope.owner());
      expect(recovery.whyNotForget, isNotNull, reason: 'the terminal is open');
      expect(await recovery.startBackup(_backupFile), isNull, reason: 'a second terminal would run Core twice');
      expect(core.calls.where((call) => call == 'refusal backup'), hasLength(1));
      await recovery.forget();
      expect(await kept.written(), contains(_idOf(command)));
      await recovery.backupEnded(code: 70, lastLine: '');
      recovery.cancel();
      expect(recovery.review, isNotNull, reason: 'Cancel drops nothing started');

      await recovery.forget();

      expect([recovery.requestId, recovery.review], [null, null]);
      expect(await kept.written(), isNot(contains(_idOf(command))));
    });

    // Harm: Retry with the backup key offered where its terminal cannot open, a silent no-op that hides why.
    test('a backup Retry its terminal cannot run says why', () async {
      final (recovery, _, _, _) = await started(scope: const RecoveryScope.owner());
      await recovery.backupEnded(code: 70, lastLine: '');
      final elsewhere = KeyRecovery(
        situation: _situation(scope: const RecoveryScope.owner(), sole: 'bob', backup: true, actor: 'alice'),
        core: _Core(),
        hosts: _Hosts(),
        receipts: kept.receipts,
      );
      addTearDown(elsewhere.dispose);

      expect(elsewhere.retriesInTerminal, isTrue);
      expect(elsewhere.whyNotRetry, contains('Only bob uses their backup key'));
    });

    // Harm: the backup key offered to someone who is not the list's single admin, or for another's entry.
    test('the backup key is offered only to the single admin for their own entry', () {
      final core = _Core();
      KeyRecovery make(RecoverySituation situation) {
        final recovery = KeyRecovery(situation: situation, core: core, hosts: _Hosts(), receipts: kept.receipts);
        addTearDown(recovery.dispose);
        return recovery;
      }

      expect(make(_situation(sole: 'alice', backup: true)).whyNotReview('bob', backup: true), isNotNull);
      expect(make(_situation(sole: 'bob', actor: 'bob')).whyNotReview('bob', backup: true), contains('No backup'));
      expect(
        make(_situation(scope: const RecoveryScope.hostAccess('walk1'), sole: 'bob', backup: true, actor: 'bob'))
            .whyNotReview('bob', backup: true),
        isNotNull,
      );
      expect(core.calls, isEmpty);
    });
  });

  group('a new backup key is made once and pushed', () {
    String made({
      String kind = 'registry',
      String? name,
      bool pushed = false,
      String file = '/media/usb/bk',
      String revision = _revision,
    }) => jsonEncode({
      'id': 'ID',
      'scope': {'kind': kind, 'name': name},
      'fingerprint': 'SHA256:${'B' * 43}',
      'file': file,
      'revision': revision,
      'pushed': pushed,
    });

    // Harm: a claimed push Core never makes for a registry list, or another file than asked, read as a backup made.
    test('a push the other way round, or another file, is refused', () {
      BackupKeyMade read(RecoveryScope scope, String answer) => backupMadeFrom(
        scope,
        code: 0,
        lastLine: answer.replaceFirst('"ID"', '"id1"'),
        id: 'id1',
        out: '/media/usb/bk',
      );

      expect(read(const RecoveryScope.owner(), made()).published, isFalse);
      expect(() => read(const RecoveryScope.owner(), made(pushed: true)), throwsA(isA<RecoveryRefused>()));
      expect(
        () => read(const RecoveryScope.project('demo'), made(kind: 'project', name: 'demo')),
        throwsA(isA<RecoveryRefused>()),
      );
      expect(() => read(const RecoveryScope.owner(), made(file: '/elsewhere')), throwsA(isA<RecoveryRefused>()));
    });

    // Harm: a second backup key made on Retry, a registry commit left unpushed, or a refused push forgotten.
    test('a lost answer is made again under the same request and base, and the registry commit is pushed', () async {
      final kept = _Kept();
      final core = _Core();
      BackupKeyMaking making() =>
          BackupKeyMaking(scope: const RecoveryScope.owner(), base: _base, core: core, receipts: kept.receipts);

      final first = await making().start('/media/usb/bk');
      expect(first.sublist(first.indexOf('--base'), first.indexOf('--base') + 2), ['--base', _base]);
      // The file's place is never in the kept request, checked while it is kept.
      expect(await kept.written(), allOf(contains(_idOf(first)), isNot(contains('/media/usb'))));
      await expectLater(making().ended(code: 70, lastLine: '', out: '/media/usb/bk'), throwsA(isA<RecoveryRefused>()));
      expect(await kept.written(), allOf(contains(_idOf(first)), isNot(contains('/media/usb'))));
      final second = await making().start('/media/usb/bk');
      expect(_idOf(second), _idOf(first));
      expect(core.calls, ['prepare'], reason: 'the checkout is readied once');

      core.publishFails = const WorkspaceRefused('push refused');
      final answer = made().replaceFirst('"ID"', '"${_idOf(first)}"');
      await expectLater(
        making().ended(code: 0, lastLine: answer, out: '/media/usb/bk'),
        throwsA(isA<WorkspaceRefused>()),
      );
      expect(making().unpublished, _revision);
      expect(await kept.written(), allOf(contains(_revision), isNot(contains('/media/usb'))));
      core.publishFails = null;
      await making().publish();
      expect(core.calls.where((call) => call == 'publish $_revision $_base'), hasLength(2));
      expect(making().pending, isFalse);
      expect(await kept.written(), isNot(contains('/media/usb')));
    });

    // Harm: a backup key for a project, which this release of Core refuses, kept as a request or shown without
    // Core's words, so the next attempt repeats a request that made nothing.
    test('a project backup key this release refuses keeps nothing and says Core’s words', () async {
      final kept = _Kept();
      final core = _Core();
      final making = BackupKeyMaking(
        scope: const RecoveryScope.project('demo'),
        base: _base,
        core: core,
        receipts: kept.receipts,
      );
      final first = await making.start('/media/usb/bk');
      await expectLater(
        making.ended(
          code: 65,
          lastLine: '{"reason":"not-in-this-release","words":"Project backup keys come in the next release."}',
          out: '/media/usb/bk',
        ),
        throwsA(
          isA<RecoveryRefused>().having(
            (refused) => refused.words,
            'words',
            contains('Project backup keys come in the next release.'),
          ),
        ),
      );
      expect(making.pending, isFalse);
      expect(await kept.written(), isNot(contains(_idOf(first))));
      expect(core.calls, isEmpty);
    });

    // Harm: after an end that may have made the key, a cancelled, refused or mismatched retry dropping the request,
    // so the next attempt makes a second backup key under a new request.
    for (final (what, code, out) in [
      ('put away', -1, ''),
      ('wrong passphrase', 65, '{"reason":"wrong-passphrase","words":"no"}'),
      ('unreadable', 66, ''),
      ('for another list', 0, null),
    ]) {
      test('after an uncertain end, a $what retry keeps the request and its base', () async {
        final kept = _Kept();
        final core = _Core();
        BackupKeyMaking making({String? base = _base}) =>
            BackupKeyMaking(scope: const RecoveryScope.owner(), base: base, core: core, receipts: kept.receipts);

        final first = await making().start('/media/usb/bk1');
        await expectLater(
          making().ended(code: 69, lastLine: '', out: '/media/usb/bk1'),
          throwsA(isA<RecoveryRefused>()),
        );
        expect(making().uncertain, isTrue);
        final second = await making().start('/media/usb/bk2');
        final other = made(
          kind: 'host',
          name: 'walk1',
          file: '/media/usb/bk2',
        ).replaceFirst('"ID"', '"${_idOf(second)}"');
        await expectLater(
          making().ended(code: code, lastLine: out ?? other, out: '/media/usb/bk2'),
          throwsA(isA<RecoveryRefused>()),
        );

        expect(making().pending, isTrue);
        final third = await making(base: _other).start('/media/usb/bk1');
        expect([_idOf(second), _idOf(third)], [_idOf(first), _idOf(first)]);
        expect(third.sublist(third.indexOf('--base'), third.indexOf('--base') + 2), ['--base', _base]);
        expect(core.calls, ['prepare'], reason: 'the checkout is readied once');
      });
    }

    // Harm: an exit-0 answer that fails any of the checks taken as proof that nothing was made, or the program ending
    // while the terminal runs, so a put-away retry drops the request and the next makes a second backup key.
    final asked = path.join('media', 'usb', 'bk1');
    for (final (what, code, out) in [
      ('an exit-0 answer with an unreadable revision', 0, made(revision: 'HEAD', file: asked)),
      ('an exit-0 answer naming another file', 0, made(file: path.join('media', 'usb', 'real', 'bk1'))),
      ('an exit-0 answer with a malformed fingerprint', 0, made(file: asked).replaceFirst('SHA256:', 'MD5:')),
      ('an exit-0 answer for another list', 0, made(kind: 'host', name: 'walk1', file: asked)),
      ('an exit-0 answer with a push never made', 0, made(pushed: true, file: asked)),
      ('a restart while the terminal runs', null, ''),
    ]) {
      test('after $what, a put-away retry keeps the request', () async {
        final kept = _Kept();
        BackupKeyMaking making() =>
            BackupKeyMaking(scope: const RecoveryScope.owner(), base: _base, core: _Core(), receipts: kept.receipts);
        final first = await making().start(asked);
        if (code != null) {
          await expectLater(
            making().ended(code: code, lastLine: out.replaceFirst('"ID"', '"${_idOf(first)}"'), out: asked),
            throwsA(anything),
          );
        }

        final second = await making().start('/media/usb/bk2');
        await expectLater(making().ended(code: -1, lastLine: '', out: '/media/usb/bk2'), throwsA(anything));

        expect(_idOf(second), _idOf(first));
        expect(making().pending, isTrue);
        expect(await kept.written(), contains(_idOf(first)));
      });
    }

    // Harm: a kept request stuck for good after Core proved no key was made under it, locking the backup key action.
    for (final reason in ['base-moved', 'not-in-this-release']) {
      test('after an uncertain end, Core’s $reason drops the request', () async {
        final kept = _Kept();
        BackupKeyMaking making() =>
            BackupKeyMaking(scope: const RecoveryScope.owner(), base: _base, core: _Core(), receipts: kept.receipts);
        await making().start('/media/usb/bk');
        await expectLater(making().ended(code: 70, lastLine: '', out: '/media/usb/bk'), throwsA(anything));
        await making().start('/media/usb/bk');

        await expectLater(
          making().ended(code: 65, lastLine: '{"reason":"$reason","words":"no"}', out: '/media/usb/bk'),
          throwsA(isA<RecoveryRefused>()),
        );

        expect(making().pending, isFalse);
      });
    }

    // Harm: a backup key made under a kept request that can never finish because its first file's place was not kept,
    // or a first attempt's answer for another file taken as the key asked for.
    test('a retry of an uncertain request takes the file the earlier attempt wrote, and says where it is', () async {
      final kept = _Kept();
      final core = _Core();
      BackupKeyMaking making() =>
          BackupKeyMaking(scope: const RecoveryScope.owner(), base: _base, core: core, receipts: kept.receipts);
      final refused = await making().start('/media/usb/bk1');
      final elsewhere = made(file: '/elsewhere').replaceFirst('"ID"', '"${_idOf(refused)}"');
      await expectLater(
        making().ended(code: 0, lastLine: elsewhere, out: '/media/usb/bk1'),
        throwsA(isA<RecoveryRefused>()),
      );
      expect(core.calls, ['prepare'], reason: 'nothing of a first attempt for another file is pushed');

      final first = await making().start('/media/usb/bk1');
      await expectLater(making().ended(code: 70, lastLine: '', out: '/media/usb/bk1'), throwsA(anything));
      final second = await making().start('/media/usb/bk2');
      final answer = made(file: '/media/usb/bk1').replaceFirst('"ID"', '"${_idOf(second)}"');
      final key = await making().ended(code: 0, lastLine: answer, out: '/media/usb/bk2');

      expect(_idOf(second), _idOf(first));
      expect([key.file, key.revision, key.published], ['/media/usb/bk1', _revision, true]);
      expect(core.calls.last, 'publish $_revision $_base');
      expect(making().pending, isFalse);
    });

    // Harm: a kept uncertain backup-key request no one can drop, locking the action for good; or a made commit owed
    // its push dropped, leaving it unpushed in the registry checkout.
    test('Forget drops a kept uncertain request, never a commit owed its push', () async {
      final kept = _Kept();
      final core = _Core()..publishFails = const WorkspaceRefused('push refused');
      BackupKeyMaking making() =>
          BackupKeyMaking(scope: const RecoveryScope.owner(), base: _base, core: core, receipts: kept.receipts);
      final first = await making().start('/media/usb/bk');
      await expectLater(making().ended(code: 70, lastLine: '', out: '/media/usb/bk'), throwsA(anything));

      await making().forget();
      expect(making().pending, isFalse);

      final second = await making().start('/media/usb/bk');
      expect(_idOf(second), isNot(_idOf(first)));
      final answer = made().replaceFirst('"ID"', '"${_idOf(second)}"');
      await expectLater(making().ended(code: 0, lastLine: answer, out: '/media/usb/bk'), throwsA(anything));
      await making().forget();
      await making().forget(made: _other);
      expect(making().unpublished, _revision, reason: 'a made commit is dropped only when its confirmation named it');
      await making().forget(made: _revision);
      expect(making().pending, isFalse);
    });

    // Harm: a kept request dropped, or a second attempt started, while the first may still be making the key: from
    // asking where its file goes until its terminal's program ended.
    test('while an attempt runs, its request is never forgotten and no second one starts', () async {
      final kept = _Kept();
      BackupKeyMaking making() =>
          BackupKeyMaking(scope: const RecoveryScope.owner(), base: _base, core: _Core(), receipts: kept.receipts);
      final first = await making().start('/media/usb/bk');
      await expectLater(making().ended(code: 70, lastLine: '', out: '/media/usb/bk'), throwsA(anything));
      final ending = Completer<void>();
      final running = making().attempt(() => ending.future);

      expect([making().running, BackupKeyMaking.anyRunning(kept.receipts)], [true, true]);
      await making().forget();
      await expectLater(making().attempt(() async {}), throwsA(isA<RegistryRefusal>()));
      expect(making().requestId, _idOf(first));
      ending.complete();
      await running;
      expect(making().running, isFalse);
      await making().forget();
      expect(making().pending, isFalse);
    });

    // Harm: a kept backup-key receipt that does not read offered as Push the backup key again, which then does nothing
    // and locks the action for good.
    test('only a kept backup-key request that reads is offered again', () async {
      final kept = _Kept();
      final registry = Registry(checkout: _Checkout(), core: _RegistryCore());
      addTearDown(registry.dispose);
      final good = {'scope': const RecoveryScope.owner().stored, 'id': 'bk-01', 'base': _base, 'uncertain': true};
      await kept.receipts.keep('backup-make/owner', good);
      await kept.receipts.keep('backup-make/hostAdmin/walk1', {
        ...good,
        'scope': const RecoveryScope.hostAdmin('walk1').stored,
        'id': 'not an id',
      });
      await kept.receipts.keep('backup-make/hostAdmin/walk2', {
        ...good,
        'scope': const RecoveryScope.hostAdmin('walk2').stored,
        'base': 'HEAD',
      });
      await kept.receipts.keep('backup-make/hostAdmin/walk3', {
        ...good,
        'scope': const RecoveryScope.hostAdmin('walk3').stored,
        'uncertain': 'yes',
      });
      final services = KeyRecoveryServices(
        core: _Core(),
        hosts: _Hosts(),
        registry: registry,
        actor: () => null,
        receipts: kept.receipts,
      );

      expect(services.keptBackups, [const RecoveryScope.owner()]);
    });
  });

  group('a host is confirmed only by its own answer', () {
    // Harm: a change reported in force on a host that never confirmed it, or one broken answer stopping the rest.
    test('an unreached, refusing, confused or broken host stays unconfirmed, the others are still asked', () async {
      final hosts = _Hosts()
        ..answers['walk1'] = RangeError('short revision')
        ..answers['walk2'] = const WorkspaceRefused('connection refused')
        ..answers['walk3'] = const HostLockRefused('walk3', 'access refused')
        ..answers['walk4'] = const HostReplaced('walk1');
      final recovery = KeyRecovery(
        situation: _situation(hosts: ['walk1', 'walk2', 'walk3', 'walk4', 'walk5']),
        core: _Core(),
        hosts: hosts,
        receipts: _Kept().receipts,
      );
      addTearDown(recovery.dispose);
      recovery.reviewFor('bob');
      await recovery.confirm();

      expect(recovery.filed?.revision, _revision);
      expect(recovery.locks['walk1'], isA<HostLockPending>());
      expect(recovery.locks['walk2'], isA<HostLockPending>());
      expect(recovery.locks['walk3'], isA<HostLockRefused>());
      expect(recovery.locks['walk4'], isA<HostLockPending>());
      expect(recovery.locks['walk5'], isA<HostReplaced>());
      expect(recovery.allConfirmed, isFalse);
    });

    // Harm: a host that applied another revision, never took the upload, or does not name the person locked,
    // read as having locked a stolen key; a project commit sent into the registry's transport.
    test('the registry hosts confirm only the uploaded revoking commit, and a stolen key only as locked', () async {
      final transport = _Transport();
      final hosts = RegistryRevocationHosts(transport);
      RecoveryReview review({bool stolen = false, RecoveryScope scope = const RecoveryScope.hostAccess('walk1')}) =>
          RecoveryReview(
            scope: scope,
            login: 'bob',
            oldFingerprint: _old,
            newFingerprint: _new,
            newKey: _newKey,
            card: _bobCard,
            base: _base,
            hosts: const ['walk1'],
            stolen: stolen,
          );

      expect(await hosts.deliver(review(), 'walk1', _revision), isA<HostReplaced>());
      expect(transport.calls, ['upload walk1 $_revision', 'sync walk1 $_revision']);
      expect(await hosts.deliver(review(stolen: true), 'walk1', _revision), isA<HostLockPending>());
      transport.people = {'bob': 'locked'};
      expect(await hosts.deliver(review(stolen: true), 'walk1', _revision), isA<HostLocked>());
      transport.applied = _other;
      expect(await hosts.deliver(review(stolen: true), 'walk1', _revision), isA<HostLockPending>());
      transport.applied = 'abc';
      expect(await hosts.deliver(review(), 'walk1', _revision), isA<HostLockPending>());
      transport.applied = _revision;
      transport.answeringFor = 'walk2';
      expect(await hosts.deliver(review(), 'walk1', _revision), isA<HostLockPending>());
      transport.calls.clear();
      expect(
        await hosts.deliver(review(scope: const RecoveryScope.project('demo')), 'walk1', _revision),
        isA<HostLockPending>(),
      );
      expect(transport.calls, isEmpty, reason: 'a project commit never goes to the registry transport');
    });

    // Harm: a second commit on Retry, or a host that confirmed asked again.
    test('Retry signs nothing again and asks only the hosts not confirmed', () async {
      final porelo = _Porelo()
        ..replaceAnswers.add((code: 69, out: '{"reason":"push-failed","words":"push failed"}', err: ''));
      final hosts = _Hosts()..answers['walk2'] = const WorkspaceRefused('not reached');
      final recovery = KeyRecovery(
        situation: _situation(hosts: ['walk1', 'walk2']),
        core: await _cliProject(porelo),
        hosts: hosts,
        receipts: _Kept().receipts,
      );
      addTearDown(recovery.dispose);
      recovery.reviewFor('bob');

      await recovery.confirm();
      expect(recovery.filed, isNull);
      await recovery.retry();
      expect(porelo.replaces, hasLength(2));
      expect(porelo.replaces.first, porelo.replaces.last, reason: 'the same id on the same base');
      expect(recovery.filed?.published, isTrue);
    });

    // Harm: a pushed project replacement offering a Retry that only asks its hosts again, which answer nothing but
    // pending here: a dead end that reads as unfinished work.
    test('a pushed project replacement offers no Retry', () async {
      final hosts = _Hosts()..answers['walk2'] = const WorkspaceRefused('not reached');
      final recovery = KeyRecovery(
        situation: _situation(hosts: ['walk1', 'walk2']),
        core: _Core(),
        hosts: hosts,
        receipts: _Kept().receipts,
      );
      addTearDown(recovery.dispose);
      recovery.reviewFor('bob');

      await recovery.confirm();

      expect(recovery.filed?.published, isTrue);
      expect(recovery.whyNotRetry, isNotNull);
    });

    // Harm: a second commit on a registry Retry, or a host that confirmed asked again.
    test('a registry Retry asks only the hosts not confirmed', () async {
      final core = _Core();
      final hosts = _Hosts()..answers['walk2'] = const WorkspaceRefused('not reached');
      final recovery = KeyRecovery(
        situation: _situation(scope: const RecoveryScope.owner(), hosts: ['walk1', 'walk2']),
        core: core,
        hosts: hosts,
        receipts: _Kept().receipts,
      );
      addTearDown(recovery.dispose);
      recovery.reviewFor('bob');

      await recovery.confirm();
      hosts.answers.remove('walk2');
      await recovery.retry();

      expect(core.calls.where((call) => call.startsWith('replace')), hasLength(1), reason: 'no second commit');
      expect(hosts.calls.map((call) => call.split(' ').first), ['walk1', 'walk2', 'walk2']);
      expect(recovery.allConfirmed, isTrue);
    });
  });

  group('a started replacement is resumed, never started again', () {
    // Harm: a refused retry after a commit that may exist dropping its request, so the next one commits again.
    test('after a lost answer, a refused retry keeps the request for the next', () async {
      final kept = _Kept();
      final porelo = _Porelo()
        ..replaceAnswers.addAll([
          (code: 69, out: '{"reason":"push-failed","words":"push failed"}', err: ''),
          (code: 66, out: '', err: ''),
        ]);
      final recovery = KeyRecovery(
        situation: _situation(hosts: const []),
        core: await _cliProject(porelo),
        hosts: _Hosts(),
        receipts: kept.receipts,
      );
      addTearDown(recovery.dispose);
      recovery.reviewFor('bob');

      await recovery.confirm();
      await recovery.retry();
      expect(recovery.problem, contains('request is kept'));
      expect(recovery.whyNotRetry, isNull);
      await recovery.retry();

      expect(porelo.replaces, hasLength(3));
      expect(
        porelo.replaces.map((call) => call.join(' ')).toSet(),
        hasLength(1),
        reason: 'the same id on the same base each time',
      );
      expect(recovery.allConfirmed, isTrue);
    });

    // Harm: the program ending while Core files, leaving a request kept as certain, so a refused retry after the
    // restart drops it and the next attempt makes a second commit; or a fresh request Core refused kept for good.
    test('a request is kept as uncertain while Core files it; a fresh refused one is dropped', () async {
      final kept = _Kept();
      final first = KeyRecovery(
        situation: _situation(hosts: const []),
        core: _Core()..holdAnswer = Completer(),
        hosts: _Hosts(),
        receipts: kept.receipts,
      );
      addTearDown(first.dispose);
      first.reviewFor('bob');
      unawaited(first.confirm());
      await pumpEventQueue();

      final core = _Core()..answers.add(const RecoveryRefused('no', code: 65, reason: 'card-login'));
      final again = KeyRecovery(
        situation: _situation(hosts: const []),
        core: core,
        hosts: _Hosts(),
        receipts: await kept.restarted(),
      );
      addTearDown(again.dispose);
      final id = again.requestId!;
      await again.retry();
      expect(core.calls, ['refusal', 'replace $id $_base']);
      expect(again.requestId, id);
      expect(await kept.written(), contains(id));

      final fresh = _Kept();
      final refused = KeyRecovery(
        situation: _situation(hosts: const []),
        core: _Core()..answers.add(const RecoveryRefused('no', code: 65, reason: 'card-login')),
        hosts: _Hosts(),
        receipts: fresh.receipts,
      );
      addTearDown(refused.dispose);
      refused.reviewFor('bob');
      await refused.confirm();
      expect(refused.requestId, isNull);
      expect(await fresh.written(), isNot(contains('"bob"')));
    });

    // Harm: a kept request stuck for good after Core proved no commit exists under it, blocking the list's recovery.
    test('after an uncertain end, Core’s base-moved drops the request', () async {
      final kept = _Kept();
      final core = _Core()
        ..answers.addAll([
          const RecoveryRefused('push failed', code: 69),
          const RecoveryRefused('moved', code: 65, reason: 'base-moved'),
        ]);
      final recovery = KeyRecovery(
        situation: _situation(hosts: const []),
        core: core,
        hosts: _Hosts(),
        receipts: kept.receipts,
      );
      addTearDown(recovery.dispose);
      recovery.reviewFor('bob');
      await recovery.confirm();
      expect(recovery.requestId, isNotNull);

      await recovery.retry();

      expect(recovery.requestId, isNull);
      expect(await kept.written(), isNot(contains('"bob"')));
      recovery.cancel();
      expect(recovery.review, isNull);
    });

    // Harm: a kept uncertain request no one can drop, so the list cannot be recovered at all.
    test('a kept uncertain request is dropped by Forget alone', () async {
      final kept = _Kept();
      final core = _Core()..answers.add(const RecoveryRefused('lost', code: 70));
      final recovery = KeyRecovery(
        situation: _situation(hosts: const []),
        core: core,
        hosts: _Hosts(),
        receipts: kept.receipts,
      );
      addTearDown(recovery.dispose);
      recovery.reviewFor('bob');
      expect(recovery.whyNotForget, isNotNull, reason: 'nothing is kept yet');
      await recovery.confirm();
      recovery.cancel();
      expect(recovery.review, isNotNull, reason: 'Cancel drops nothing started');

      await recovery.forget();

      expect([recovery.requestId, recovery.review], [null, null]);
      expect(await kept.written(), isNot(contains('"bob"')));
    });

    // Harm: a registry commit made and never pushable keeping its list's replacements locked for good; or dropped
    // without the confirmation that names it, as if nothing were made.
    test('a made commit owed its push is forgotten only when the confirmation named it', () async {
      final kept = _Kept();
      final core = _Core()
        ..answers.add(const RecoveryFiled(revision: _revision, published: false))
        ..publishFails = const WorkspaceRefused('push refused');
      final recovery = KeyRecovery(
        situation: _situation(scope: const RecoveryScope.owner(), hosts: const []),
        core: core,
        hosts: _Hosts(),
        receipts: kept.receipts,
      );
      addTearDown(recovery.dispose);
      recovery.reviewFor('bob');
      await recovery.confirm();
      expect(recovery.filed?.published, isFalse);
      expect(recovery.whyNotForget, isNull);

      await recovery.forget();
      await recovery.forget(made: _other);
      expect(recovery.filed?.revision, _revision);
      expect(await kept.written(), contains(_revision));

      await recovery.forget(made: _revision);
      expect([recovery.filed, recovery.review, recovery.started], [null, null, false]);
      expect(await kept.written(), isNot(contains(_revision)));
    });

    // Harm: a list known only from a kept request's record taking a new replacement once that request ended, filed
    // under a fresh request without a clean read.
    for (final backup in [false, true]) {
      test('once a kept request ends on a record alone, nothing new is filed, backup=$backup', () async {
        final kept = _Kept();
        final first = KeyRecovery(
          situation: _situation(hosts: const [], sole: 'bob', backup: backup, actor: backup ? 'bob' : 'alice'),
          core: _Core()..answers.add(const RecoveryRefused('lost', code: 70)),
          hosts: _Hosts(),
          receipts: kept.receipts,
        );
        addTearDown(first.dispose);
        first.reviewFor('bob', backup: backup);
        if (backup) {
          await first.startBackup(_backupFile);
          await first.backupEnded(code: 70, lastLine: '');
        } else {
          await first.confirm();
        }
        expect(first.requestId, isNotNull);
        final core = _Core()..answers.add(const RecoveryRefused('moved', code: 65, reason: 'base-moved'));
        final resumed = KeyRecovery(
          situation: _situation(
            hosts: const [],
            sole: 'bob',
            backup: backup,
            actor: backup ? 'bob' : 'alice',
            resumeOnly: true,
          ),
          core: core,
          hosts: _Hosts(),
          receipts: kept.receipts,
        );
        addTearDown(resumed.dispose);

        if (backup) {
          await resumed.startBackup(_backupFile);
          await resumed.backupEnded(code: 65, lastLine: '{"reason":"base-moved","words":"moved"}');
        } else {
          await resumed.retry();
        }
        expect(resumed.requestId, isNull);
        core.calls.clear();
        await resumed.confirm();
        expect(await resumed.startBackup(_backupFile), isNull);

        expect(core.calls, isEmpty, reason: 'nothing new reaches Core');
        expect(resumed.review, isNull, reason: 'the reviewed replacement ended with its request');
        expect(await kept.written(), isNot(contains('"bob"')));
      });
    }

    // Harm: a dialog closed and opened again making a second commit under a fresh request.
    test('reopening after a failed push repeats the same request on the same base', () async {
      final kept = _Kept();
      final porelo = _Porelo()..replaceAnswers.add((code: 69, out: '', err: ''));
      final first = KeyRecovery(
        situation: _situation(hosts: ['walk1']),
        core: await _cliProject(porelo),
        hosts: _Hosts(),
        receipts: kept.receipts,
      );
      first.reviewFor('bob');
      await first.confirm();
      first.dispose();

      final again = KeyRecovery(
        situation: _situation(hosts: ['walk1']),
        core: await _cliProject(porelo),
        hosts: _Hosts(),
        receipts: kept.receipts,
      );
      addTearDown(again.dispose);
      expect(again.review?.login, 'bob');
      expect(again.whyNotReview('bob'), isNotNull, reason: 'no second review over a started one');
      await again.retry();
      expect(porelo.replaces, hasLength(2));
      expect(porelo.replaces.first, porelo.replaces.last);
      expect(again.allConfirmed, isTrue);
      expect(await kept.written(), isNot(contains('"project/demo"')), reason: 'a finished request is forgotten');
    });

    // Harm: a registry Retry after a refused push filing again, or a replacement shown done while unpushed.
    test('a refused registry push is pushed again without a second filing, and is never done before', () async {
      final checkout = _Checkout()..refusePush = const WorkspaceRefused('push refused');
      final registryCore = _RegistryCore();
      final registry = Registry(checkout: checkout, core: registryCore);
      addTearDown(registry.dispose);
      await registry.refresh();
      final recovery = KeyRecovery(
        situation: _situation(scope: const RecoveryScope.owner(), hosts: const []),
        core: CliKeyRecoveryCore(
          actor: () => HostAdminIdentity('alice', _admin),
          registry: registry,
          readFile: (_) async => _owners,
        ),
        hosts: _Hosts(),
        receipts: _Kept().receipts,
      );
      addTearDown(recovery.dispose);
      recovery.reviewFor('bob');

      await recovery.confirm();
      expect(recovery.filed?.published, isFalse);
      expect(recovery.allConfirmed, isFalse);
      expect(recovery.whyNotRetry, isNull);
      checkout.refusePush = null;
      await recovery.retry();
      expect(registryCore.filed, hasLength(1), reason: 'no second filing');
      expect(checkout.calls.where((call) => call == 'push $_revision $_base'), hasLength(2));
      expect(recovery.allConfirmed, isTrue);
    });
  });

  group('a key recovery and the registry’s own reads and filings exclude each other', () {
    late _Checkout checkout;
    late _RegistryCore registryCore;
    late Registry registry;
    late _Kept kept;

    setUp(() async {
      checkout = _Checkout();
      registryCore = _RegistryCore();
      registry = Registry(checkout: checkout, core: registryCore);
      addTearDown(registry.dispose);
      await registry.refresh();
      kept = _Kept();
    });

    CliKeyRecoveryCore core() => CliKeyRecoveryCore(
      actor: () => HostAdminIdentity('alice', _admin),
      registry: registry,
      readFile: (_) async => _owners,
    );

    // Harm: a filing or a refresh of the registry run in the checkout while Core commits a key replacement there, so
    // one meets the other's commit half made, or the refresh moves the card the replacement files.
    test('while a replacement runs in the checkout a filing is refused and a refresh waits', () async {
      final recovery = KeyRecovery(
        situation: _situation(scope: const RecoveryScope.owner(), hosts: const []),
        core: core(),
        hosts: _Hosts(),
        receipts: kept.receipts,
      );
      addTearDown(recovery.dispose);
      recovery.reviewFor('bob');
      final committing = registryCore.filing = Completer<void>();
      final confirming = recovery.confirm();
      await pumpEventQueue();
      expect(registryCore.filed, hasLength(1), reason: 'Core commits now');
      final fetched = checkout.fetches;

      Object? refused;
      final filing = registry
          .file(RegistryFiling(RegistryFilingKind.card, person: 'alice', content: 'a card'))
          .then<void>((_) {}, onError: (Object error) => refused = error);
      final refreshing = registry.refresh();
      await pumpEventQueue();
      expect(refused, isA<RegistryRefusal>().having((refused) => refused.words, 'words', Registry.heldWords));
      expect(registryCore.filed, hasLength(1), reason: 'the refused filing never reached Core');
      expect(checkout.fetches, fetched, reason: 'the refresh waits for the replacement');

      committing.complete();
      await Future.wait([confirming, refreshing, filing]);
      expect(checkout.fetches, greaterThan(fetched + 1), reason: 'read again for the replacement, then the refresh');
      expect(recovery.filed?.published, isTrue);
    });

    // Harm: a retry of a lost answer, or a backup key's making, started in the checkout while a registry read moves it,
    // so Core commits on a state nobody checked.
    test('while a registry read runs a retry and a backup key’s making are refused with words', () async {
      registryCore.fileFailures.add(const RegistryFilingRefused('committed, the answer lost', code: 70));
      final recovery = KeyRecovery(
        situation: _situation(scope: const RecoveryScope.owner(), hosts: const []),
        core: core(),
        hosts: _Hosts(),
        receipts: kept.receipts,
      );
      addTearDown(recovery.dispose);
      recovery.reviewFor('bob');
      await recovery.confirm();
      expect(recovery.uncertain, isTrue);
      checkout.calls.clear();
      final reading = checkout.fetching = Completer<void>();
      final refreshing = registry.refresh();
      await pumpEventQueue();

      final retrying = recovery.retry();
      final making = BackupKeyMaking(
        scope: const RecoveryScope.owner(),
        base: _base,
        core: core(),
        receipts: kept.receipts,
      );
      Object? refused;
      final starting = making
          .attempt(() => making.start(path.join('media', 'usb', 'bk')))
          .then<void>((_) {}, onError: (Object error) => refused = error);
      await pumpEventQueue();
      expect(recovery.problem, contains('still runs'));
      expect(refused, isA<RegistryRefusal>());

      reading.complete();
      await Future.wait([retrying, starting, refreshing]);
      expect(registryCore.filed, hasLength(1), reason: 'nothing was filed again meanwhile');
      expect(checkout.calls, isEmpty, reason: 'nothing readied the checkout meanwhile');
      expect(kept.receipts.keys, isNot(contains(BackupKeyMaking.keyOf(const RecoveryScope.owner()))));
    });
  });

  group('a kept unpushed registry commit is pushed without a clean read', () {
    // Harm: a replacement's own unpushed commit making the registry refuse every read, and the refused read
    // refusing that commit's push: nothing could ever publish it. Nor may anyone else's change pass unread.
    for (final restarted in [false, true]) {
      test('${restarted ? 'after a restart' : 'after a refused refresh'} the kept commit is pushed', () async {
        final kept = _Kept();
        final checkout = _Checkout()..refusePush = const WorkspaceRefused('push refused');
        final first = Registry(checkout: checkout, core: _RegistryCore());
        addTearDown(first.dispose);
        await first.refresh();
        final core = CliKeyRecoveryCore(
          actor: () => HostAdminIdentity('alice', _admin),
          registry: first,
          readFile: (_) async => _owners,
        );
        final recovery = KeyRecovery(
          situation: _situation(scope: const RecoveryScope.owner(), hosts: const []),
          core: core,
          hosts: _Hosts(),
          receipts: kept.receipts,
        );
        recovery.reviewFor('bob');
        await recovery.confirm();
        recovery.dispose();
        expect(recovery.filed?.published, isFalse);

        checkout
          ..refusePush = null
          ..refuseFetch = const WorkspaceRefused('The registry checkout holds a commit the repository does not.');
        final registry = restarted ? Registry(checkout: checkout, core: _RegistryCore()) : first;
        if (restarted) addTearDown(registry.dispose);
        await registry.refresh();
        expect(registry.problem, isNotNull);
        final services = KeyRecoveryServices(
          core: CliKeyRecoveryCore(actor: () => HostAdminIdentity('alice', _admin), registry: registry),
          hosts: _Hosts(),
          registry: registry,
          actor: () => HostAdminIdentity('alice', _admin),
          receipts: kept.receipts,
        );

        expect(services.registryScopes, contains(const RecoveryScope.owner()));
        await expectLater(services.situation(const RecoveryScope.hostAdmin('walk1')), throwsA(isA<RegistryRefusal>()));
        final keptRead = await services.situation(const RecoveryScope.owner());
        final again = KeyRecovery(
          situation: keptRead,
          core: services.core,
          hosts: services.hosts,
          receipts: kept.receipts,
        );
        addTearDown(again.dispose);
        expect(again.whyNotReview('bob'), isNotNull, reason: 'nothing new is reviewed without a clean read');
        await again.retry();

        expect(checkout.calls.where((call) => call == 'push $_revision $_base'), hasLength(2));
        expect(again.allConfirmed, isTrue);
        await kept.receipts.forget(const RecoveryScope.owner().receiptKey);
        await expectLater(services.situation(const RecoveryScope.owner()), throwsA(isA<RegistryRefusal>()));
        // The kept request has ended; its record is still no read to review anything new on.
        final ended = KeyRecovery(
          situation: keptRead,
          core: services.core,
          hosts: services.hosts,
          receipts: kept.receipts,
        );
        addTearDown(ended.dispose);
        expect(ended.started, isFalse);
        expect(ended.whyNotReview('bob'), isNotNull);
        ended.reviewFor('bob');
        expect(ended.review, isNull);
      });
    }
  });

  group('only the person reviewed, in the scope reviewed, by who may', () {
    KeyRecovery make(RecoverySituation situation, KeyRecoveryCore core) {
      final recovery = KeyRecovery(situation: situation, core: core, hosts: _Hosts(), receipts: _Kept().receipts);
      addTearDown(recovery.dispose);
      return recovery;
    }

    // Harm: a replacement signed for a person not in the list, under another login, or with a card Core does not
    // trust: a refused successor or a first-seen one.
    test('an unknown person, a changed login or an untrusted successor is refused without a call', () {
      final core = _Core();
      for (final state in ['refused', 'first-seen', 'revoked']) {
        final recovery = make(
          _situation(
            cards: [_card('bob', _newKey, state: state, why: 'why')],
          ),
          core,
        );
        expect(recovery.situation.newCard('bob'), isNull, reason: 'a $state card is never offered');
        recovery.reviewFor('bob');
        expect(recovery.review, isNull);
      }
      final recovery = make(_situation(), core);
      recovery.reviewFor('mallory');
      expect(recovery.review, isNull);
      recovery.reviewFor('bob', card: _card('mallory', _newKey));
      expect(recovery.review, isNull);
      expect(core.calls, isEmpty);
    });

    // Harm: a project's new card filed although the registry now holds another key for it than the one reviewed.
    test('a project replacement is refused when its new card moved since the review', () async {
      final porelo = _Porelo();
      final registryCore = _RegistryCore();
      final registry = Registry(checkout: _Checkout(), core: registryCore);
      addTearDown(registry.dispose);
      await registry.refresh();
      final recovery = make(_situation(), _cliProjectOver(porelo, registry));
      recovery.reviewFor('bob');
      registryCore.bobKey = _key(5);
      await registry.refresh();

      await recovery.confirm();

      expect(recovery.problem, reviewMoved);
      expect(porelo.replaces, isEmpty);
    });

    // Harm: a project replacement handed the card's place in the registry checkout, which a refresh moves to another
    // key after the check, so Core pins a key nobody reviewed; or a copy others may read or change before Core does.
    test('a project replacement hands Core a private copy of the card as checked', () async {
      final porelo = _Porelo();
      final registry = Registry(checkout: _Checkout(), core: _RegistryCore());
      addTearDown(registry.dispose);
      await registry.refresh();
      var onDisk = _cardOf(_newKey);
      final recovery = make(_situation(), _cliProjectOver(porelo, registry, card: () => onDisk));
      recovery.reviewFor('bob');
      final checked = onDisk;
      porelo.onReplace = () => onDisk = _cardOf(_key(5));

      await recovery.confirm();

      final handed = porelo.handed.single;
      expect(handed.file, isNot(_bobCard), reason: 'the checkout’s file may be another by then');
      expect(handed.text, checked);
      // Windows has no mode bits; there privateDirectory restricts the folder by its ACL, tested with it.
      if (!Platform.isWindows) expect(handed.folderMode & 0x3f, 0, reason: 'only this user reaches the copy');
      expect(File(handed.file).existsSync(), isFalse, reason: 'the copy goes once Core ran');
      expect(recovery.filed?.revision, _revision);
    });

    // Harm: a project replacement filed with a card the checkout holds now for another key than the reviewed one.
    test('a project replacement whose card file holds another key than reviewed runs nothing', () async {
      final porelo = _Porelo();
      final registry = Registry(checkout: _Checkout(), core: _RegistryCore());
      addTearDown(registry.dispose);
      await registry.refresh();
      final recovery = make(_situation(), _cliProjectOver(porelo, registry, card: () => _cardOf(_key(5))));
      recovery.reviewFor('bob');

      await recovery.confirm();

      expect(porelo.replaces, isEmpty);
      expect(recovery.problem, reviewMoved);
      expect(recovery.started, isFalse, reason: 'nothing ran under a request');
    });

    // Harm: a replacement signed by someone Core does not name as project admin here.
    test('a forged project admin is refused before the replacement verb runs', () async {
      final porelo = _Porelo()..admins = [];
      final recovery = make(_situation(), await _cliProject(porelo));
      recovery.reviewFor('bob');

      await recovery.confirm();

      expect(porelo.replaces, isEmpty);
      expect(recovery.filed, isNull);
      expect(recovery.problem, contains('Only an active project admin'));
    });

    // Harm: the replacement filed with another card, base or person than reviewed.
    test('a project admin’s replacement is Core’s replace verb with the reviewed values', () async {
      final porelo = _Porelo();
      final recovery = make(_situation(hosts: ['walk1']), await _cliProject(porelo));
      recovery.reviewFor('bob');

      await recovery.confirm();

      final call = porelo.calls.where((call) => call.skip(1).take(3).join(' ') == 'project access replace').single;
      expect(call.take(9), [
        'porelo',
        'project',
        'access',
        'replace',
        '--project',
        'demo',
        '--person',
        'bob',
        '--card',
      ]);
      expect(porelo.handed.single.text, _cardOf(_newKey), reason: 'the reviewed card, as a private copy');
      expect(call.sublist(10, 12), ['--base', _base]);
      expect([call[12], call.length, call.last], ['--id', 15, '--json']);
      expect(recovery.filed?.revision, _revision);
    });

    // Harm: a cancelled review, or an unconfirmed stolen-key replacement, still signing something.
    test('cancelling or an unconfirmed stolen key makes no call', () async {
      final core = _Core();
      final recovery = make(_situation(), core);
      recovery.reviewFor('bob');
      recovery.cancel();
      await recovery.confirm();
      recovery.reviewFor('bob', stolen: true);
      await recovery.confirm();

      expect(core.calls, isEmpty);
    });
  });

  group('the registry’s lists change by one entry, filed by who may', () {
    late _Checkout checkout;
    late _RegistryCore registryCore;
    late Registry registry;

    setUp(() async {
      checkout = _Checkout();
      registryCore = _RegistryCore();
      registry = Registry(checkout: checkout, core: registryCore);
      addTearDown(registry.dispose);
      await registry.refresh();
    });

    KeyRecovery make(RecoveryScope scope, {String actor = 'alice'}) {
      final recovery = KeyRecovery(
        situation: _situation(scope: scope, hosts: const []),
        core: CliKeyRecoveryCore(
          actor: () => HostAdminIdentity(actor, actor == 'alice' ? _admin : _new),
          registry: registry,
          readFile: (file) async => file == path.join(_checkout, 'owners.yml') ? _owners : '',
        ),
        hosts: _Hosts(),
        receipts: _Kept().receipts,
      );
      addTearDown(recovery.dispose);
      recovery.reviewFor('bob');
      return recovery;
    }

    // Harm: an owner's, a host admin's or an access file's key changed in another entry, without id and base, or
    // without the person whose card the registry must trust.
    for (final (scope, kind, changed) in [
      (const RecoveryScope.owner(), RegistryFilingKind.owners, 4),
      (const RecoveryScope.hostAdmin('walk1'), RegistryFilingKind.owners, 13),
      (const RecoveryScope.hostAccess('walk1'), RegistryFilingKind.hostAccess, -1),
    ]) {
      test('${scope.words} files only bob’s new key, with id, base and person', () async {
        final recovery = make(scope);
        await recovery.confirm();

        final filing = registryCore.filed.single;
        expect([filing.kind, filing.person, filing.base, filing.id?.length], [kind, 'bob', _base, 32]);
        if (changed >= 0) {
          final lines = filing.content!.split('\n');
          final before = _owners.split('\n');
          expect(
            [
              for (var i = 0; i < lines.length; i++)
                if (lines[i] != before[i]) i,
            ],
            [changed],
          );
          expect(lines[changed], endsWith('key: "$_newKey"'));
        } else {
          expect(filing.content, contains('"bob": "$_new"'));
          expect(filing.content, contains('"alice": "$_admin"'));
        }
        expect(checkout.calls, ['prepare', 'push $_revision $_base']);
        expect(recovery.allConfirmed, isTrue);
      });
    }

    // Harm: a key in owners.yml or an access file replaced by someone owners.yml does not name for it.
    test('a forged owner or host admin files nothing', () async {
      for (final scope in [const RecoveryScope.owner(), const RecoveryScope.hostAccess('walk1')]) {
        final recovery = make(scope, actor: 'mallory');
        await recovery.confirm();
        expect(recovery.problem, contains('Only'));
      }
      expect(registryCore.filed, isEmpty);
      expect(checkout.calls, isEmpty);
    });

    // Harm: a key the registry does not trust now written into owners.yml because the dialog read an older state.
    test('a new card the registry does not trust now is refused before filing', () async {
      registryCore.bobState = 'first-seen';
      await registry.refresh();
      final recovery = make(const RecoveryScope.owner());
      await recovery.confirm();

      expect(registryCore.filed, isEmpty);
      expect(checkout.calls, isEmpty);
      expect(recovery.problem, reviewMoved);
    });

    // Harm: an owners.yml filing that adds an entry, changes a role or another field beside the key.
    test('an extra entry, a role change or another field is refused before filing', () {
      final key = _owners.replaceFirst('    key: "$_oldKey"', '    key: "$_newKey"');
      expect(() => checkOneKeyChanged(_owners, key), returnsNormally);
      for (final changed in [
        key.replaceFirst('host_admins:', '  - login: mallory\n    key: "$_newKey"\nhost_admins:'),
        key.replaceFirst('    backup: true', '    backup: false'),
        key.replaceFirst('  - login: alice', '  - login: mallory'),
        _owners.replaceFirst('    backup: true', '    key: "$_newKey"'),
      ]) {
        expect(() => checkOneKeyChanged(_owners, changed), throwsA(isA<RecoveryRefused>()));
      }
    });

    // Harm: a registry filing whose commit was made and whose answer was lost never retried under its request: the
    // retry reads the owners.yml that commit changed, or the checkout refuses on that commit, before Core is asked.
    for (final restarted in [false, true]) {
      test('a lost registry answer is retried under its request with the same file, restarted=$restarted', () async {
        final kept = _Kept();
        var owners = _owners;
        registryCore.fileFailures.add(const RegistryFilingRefused('committed, the answer lost', code: 70));
        CliKeyRecoveryCore core(Registry registry) => CliKeyRecoveryCore(
          actor: () => HostAdminIdentity('alice', _admin),
          registry: registry,
          readFile: (_) async => owners,
        );
        final first = KeyRecovery(
          situation: _situation(scope: const RecoveryScope.owner(), hosts: const []),
          core: core(registry),
          hosts: _Hosts(),
          receipts: kept.receipts,
        );
        addTearDown(first.dispose);
        first.reviewFor('bob');
        await first.confirm();
        final id = first.requestId;
        final filed = registryCore.filed.single.content!;
        // What Core committed and did not answer: owners.yml changed in the checkout, the commit not pushed.
        owners = filed;
        checkout.made = (base: _base, file: 'owners.yml', content: filed);
        var again = first;
        if (restarted) {
          checkout.refuseFetch = _Checkout._unpublished;
          await registry.refresh();
          final services = KeyRecoveryServices(
            core: core(registry),
            hosts: _Hosts(),
            registry: registry,
            actor: () => HostAdminIdentity('alice', _admin),
            receipts: kept.receipts,
          );
          again = KeyRecovery(
            situation: await services.situation(const RecoveryScope.owner()),
            core: services.core,
            hosts: services.hosts,
            receipts: kept.receipts,
          );
          addTearDown(again.dispose);
        }

        await again.retry();

        expect(registryCore.filed.map((filing) => [filing.id, filing.base, filing.content]), [
          [id, _base, filed],
          [id, _base, filed],
        ]);
        expect(checkout.calls, ['prepare', 'prepare again owners.yml', 'push $_revision $_base']);
        expect(again.filed?.revision, _revision);
      });
    }

    // Harm: Core's exit 69 or 70 from a registry filing, which may come after the commit, read as nothing made, so a
    // refused retry drops the request and the next attempt files a second commit.
    test('a registry filing that may have committed keeps its request through a refused retry', () async {
      registryCore.fileFailures.addAll([
        const RegistryFilingRefused('committed, the answer lost', code: 70),
        const RegistryFilingRefused('no', code: 65, reason: 'card-login'),
      ]);
      final recovery = make(const RecoveryScope.owner());
      await recovery.confirm();
      final id = recovery.requestId;
      expect(id, isNotNull);

      await recovery.retry();

      expect(recovery.requestId, id);
      expect(registryCore.filed.map((filing) => filing.id), [id, id]);
    });

    // Harm: a host access file's replacement that committed and lost its answer never retried, as its retry readies
    // the checkout for another file than the one its own commit changed.
    test('a host access file’s retry readies the checkout for that file’s own commit', () async {
      registryCore.fileFailures.add(const RegistryFilingRefused('committed, the answer lost', code: 70));
      final recovery = make(const RecoveryScope.hostAccess('walk1'));
      await recovery.confirm();
      final id = recovery.requestId;
      final file = registryCore.filed.single.content!;
      checkout.made = (base: _base, file: 'hosts/walk1/access.yml', content: file);

      await recovery.retry();

      expect(checkout.calls, contains('prepare again hosts/walk1/access.yml'));
      expect(registryCore.filed.map((filing) => [filing.id, filing.content]), [
        [id, file],
        [id, file],
      ]);
      expect(recovery.filed?.revision, _revision);
    });

    // Harm: a change filed against another registry state than the person reviewed: a list read again in between, or
    // a new card that is no longer the reviewed key.
    for (final moved in ['the list', 'the card']) {
      test('a registry change is refused when $moved moved since the review', () async {
        final kept = _Kept();
        final recovery = KeyRecovery(
          situation: _situation(scope: const RecoveryScope.owner(), hosts: const []),
          core: CliKeyRecoveryCore(
            actor: () => HostAdminIdentity('alice', _admin),
            registry: registry,
            readFile: (file) async => _owners,
          ),
          hosts: _Hosts(),
          receipts: kept.receipts,
        );
        addTearDown(recovery.dispose);
        recovery.reviewFor('bob');
        if (moved == 'the list') {
          registryCore.revision = _other;
        } else {
          registryCore.bobKey = _key(5);
        }
        await registry.refresh();

        await recovery.confirm();

        expect(recovery.problem, reviewMoved);
        expect(registryCore.filed, isEmpty);
        expect(checkout.calls, isEmpty);
        expect(kept.receipts.keys, isEmpty, reason: 'nothing started');
      });
    }
  });

  group('a project read before a commit made here starts no replacement on it', () {
    late _Kept kept;
    late _Core core;
    late KeyRecoveryServices services;
    late String read;
    late String projectRead;
    const demo = RecoveryScope.project('demo');

    setUp(() async {
      kept = _Kept();
      core = _Core();
      read = _base;
      projectRead = _project;
      final registry = Registry(checkout: _Checkout(), core: _RegistryCore());
      addTearDown(registry.dispose);
      await registry.refresh();
      ProjectAccessView view() => ProjectAccessView(
        project: 'demo',
        host: PreparedHost.read(sshCompletion()),
        projectRevision: projectRead,
        accessRevision: read,
        projectYaml: '',
        actor: HostAdminIdentity('alice', _admin),
        admittedFingerprint: _admin,
        canAdmin: true,
        signingAvailable: true,
        adminSigners: [_adminKey],
        access: AccessDevelopers([
          AccessDeveloper(login: 'alice', role: 'admin', fingerprint: _admin),
          AccessDeveloper(login: 'bob', role: 'developer', fingerprint: _old),
        ]),
        eligible: const {},
      );
      services = KeyRecoveryServices(
        core: core,
        // The real hosts' boundary: a project's commit reaches none of them from here.
        hosts: RegistryRevocationHosts(_Transport()),
        registry: registry,
        actor: () => HostAdminIdentity('alice', _admin),
        receipts: kept.receipts,
        projectView: (_) => view(),
      );
    });

    Future<KeyRecovery> open() async {
      final recovery = KeyRecovery(
        situation: await services.situation(demo),
        core: core,
        hosts: services.hosts,
        receipts: kept.receipts,
      );
      addTearDown(recovery.dispose);
      return recovery;
    }

    // Harm: a pushed project replacement whose hosts answer only pending kept for good, locking every later
    // replacement in that project; or a later one reviewed on a base newer than the people and roles it shows, so it
    // revokes another key than the one shown.
    test('a replacement made here holds the next until the project is read again', () async {
      final first = await open();
      first.reviewFor('bob');
      await first.confirm();
      expect(first.filed?.revision, _revision);
      expect(first.locks.values.single, isA<HostLockPending>());
      expect(kept.receipts.keys, isNot(contains(demo.receiptKey)), reason: 'nothing of it can be made twice');

      final later = await open();
      expect(later.started, isFalse);
      expect(later.whyNotReview('bob'), KeyRecovery.refreshProjectBeforeReplacing);
      expect([later.situation.base, later.situation.madeHere], [_base, _revision]);

      read = _revision;
      final caught = await services.situation(demo);
      expect([caught.base, caught.madeHere], [_revision, null]);
      expect(kept.receipts.keys, isNot(contains('in-force/project/demo')));
    });

    String answered(List<String> command, String out, String revision) => jsonEncode({
      'id': _idOf(command),
      'scope': {'kind': 'project', 'name': 'demo'},
      'fingerprint': 'SHA256:${'B' * 43}',
      'file': out,
      'revision': revision,
      'pushed': true,
    });

    // Harm: a project backup key made on the access repository's commit, which Core compares with the project
    // repository's head and refuses as moved for good; or its commit kept against the access commit, so every project
    // replacement stays refused until an unrelated access change.
    test('a project backup key is made on the project’s own commit, which holds no replacement', () async {
      final first = await open();
      first.reviewFor('bob');
      await first.confirm();
      final later = await services.situation(demo);
      expect([later.madeHere, later.backupBase], [_revision, _project]);

      final making = BackupKeyMaking(scope: demo, base: later.backupBase, core: core, receipts: kept.receipts);
      final out = path.join('media', 'usb', 'bk');
      final command = await making.start(out);
      expect(command.sublist(command.indexOf('--base'), command.indexOf('--base') + 2), ['--base', _project]);
      await making.ended(code: 0, lastLine: answered(command, out, _other), out: out);

      read = _revision;
      final after = await services.situation(demo);
      expect([after.madeHere, after.backupBase], [null, _other], reason: 'each repository keeps its own newest');
      expect((await open()).whyNotReview('bob'), isNull, reason: 'the access file shows everything made in it');
      projectRead = _other;
      expect((await services.situation(demo)).backupBase, _other);
      expect(kept.receipts.keys, isEmpty, reason: 'each read shows what was made here');
    });

    // Harm: a commit kept as made here after Core said the project moved past it, handed out as the base for good; or
    // a project backup key's refusal forgetting the access file's record, which lets a replacement be reviewed on a
    // read older than one made here.
    test('Core’s base-moved for a project backup key forgets only the project repository’s commit', () async {
      final first = await open();
      first.reviewFor('bob');
      await first.confirm();
      await keepMadeInForce(kept.receipts, demo, base: _project, revision: _other, projectRepository: true);
      final out = path.join('media', 'usb', 'bk');
      final making = BackupKeyMaking(
        scope: demo,
        base: (await services.situation(demo)).backupBase,
        core: core,
        receipts: kept.receipts,
      );
      final command = await making.start(out);
      expect(command.sublist(command.indexOf('--base'), command.indexOf('--base') + 2), ['--base', _other]);

      await expectLater(
        making.ended(code: 65, lastLine: '{"reason":"base-moved","words":"moved"}', out: out),
        throwsA(isA<RecoveryRefused>()),
      );

      final after = await services.situation(demo);
      expect([after.madeHere, after.backupBase], [_revision, _project]);
      expect(kept.receipts.keys, ['in-force/project/demo']);
    });

    // Harm: the same, after the backup key's use Core refused as moved.
    test('a backup key use Core refuses as moved forgets only the project repository’s commit', () async {
      await keepMadeInForce(kept.receipts, demo, base: _base, revision: _revision);
      await keepMadeInForce(kept.receipts, demo, base: _project, revision: _other, projectRepository: true);
      final recovery = KeyRecovery(
        situation: _situation(hosts: const [], sole: 'bob', backup: true, actor: 'bob'),
        core: core,
        hosts: _Hosts(),
        receipts: kept.receipts,
      );
      addTearDown(recovery.dispose);
      recovery.reviewFor('bob', backup: true);
      final command = (await recovery.startBackup(_backupFile))!;
      expect(command.sublist(command.indexOf('--base'), command.indexOf('--base') + 2), ['--base', _project]);

      await recovery.backupEnded(code: 65, lastLine: '{"reason":"base-moved","words":"moved"}');

      expect(kept.receipts.keys, ['in-force/project/demo']);
    });

    // Harm: the same, after a replacement Core refused as moved.
    test('a replacement Core refuses as moved forgets the commit kept as made here', () async {
      await keepMadeInForce(kept.receipts, demo, base: _base, revision: _revision);
      core.answers.add(const RecoveryRefused('moved', code: 65, reason: 'base-moved'));
      final recovery = KeyRecovery(
        situation: _situation(hosts: const []),
        core: core,
        hosts: _Hosts(),
        receipts: kept.receipts,
      );
      addTearDown(recovery.dispose);
      recovery.reviewFor('bob');

      await recovery.confirm();

      expect(kept.receipts.keys, isEmpty);
    });
  });

  group('a request is kept while Core may have made it, and runs once for every dialog', () {
    late _Kept kept;
    setUp(() => kept = _Kept());

    KeyRecovery backupRecovery({RecoveryScope scope = const RecoveryScope.owner()}) {
      final recovery = KeyRecovery(
        situation: _situation(scope: scope, sole: 'bob', backup: true, actor: 'bob', hosts: const []),
        core: _Core(),
        hosts: _Hosts(),
        receipts: kept.receipts,
      );
      addTearDown(recovery.dispose);
      return recovery;
    }

    // Harm: a backup key's use put away, killed or ended unseen after Core started taken as proof that nothing was
    // made, so its request is dropped and the next attempt makes a second commit.
    for (final code in [null, -1, 129]) {
      test('a backup key’s terminal ended with ${code ?? 'no code'} after Core started keeps its request', () async {
        final recovery = backupRecovery()..reviewFor('bob', backup: true);
        final command = await recovery.startBackup(_backupFile);

        await recovery.backupEnded(code: code, lastLine: '');

        expect(recovery.requestId, _idOf(command!));
        expect(recovery.uncertain, isTrue);
        expect(await kept.written(), contains(_idOf(command)));
      });

      test('a backup key made in a terminal ended with ${code ?? 'no code'} after Core started is kept', () async {
        final making = BackupKeyMaking(
          scope: const RecoveryScope.owner(),
          base: _base,
          core: _Core(),
          receipts: kept.receipts,
        );
        final out = path.join('media', 'usb', 'bk');
        final command = await making.start(out);

        await expectLater(making.ended(code: code, lastLine: '', out: out), throwsA(isA<RecoveryRefused>()));

        expect([making.requestId, making.uncertain], [_idOf(command), true]);
      });
    }

    // Harm: an answer Core gave after it ran that fails a check counted as nothing made, so a retry Core refuses drops
    // the request and the next attempt makes a second commit.
    test('after an answer that fails a check, a refused retry keeps the request', () async {
      final recovery = backupRecovery()..reviewFor('bob', backup: true);
      final command = await recovery.startBackup(_backupFile);
      final another = _used(id: _idOf(command!), kind: 'registry', name: null, replaced: _admin, pushed: false);
      await recovery.backupEnded(code: 0, lastLine: another);
      await recovery.startBackup(_backupFile);

      await recovery.backupEnded(code: 65, lastLine: '{"reason":"wrong-passphrase","words":"no"}');

      expect(recovery.requestId, _idOf(command));
      expect(await kept.written(), contains(_idOf(command)));
    });

    // Harm: a dialog closed and opened again while the backup key's terminal still runs Core offering Forget or a
    // second terminal, which drops or repeats a request Core may still commit under; or never offering them again.
    test('a dialog opened again meets the backup key’s terminal still running, and is told when it ended', () async {
      final first = KeyRecovery(
        situation: _situation(scope: const RecoveryScope.owner(), sole: 'bob', backup: true, actor: 'bob'),
        core: _Core(),
        hosts: _Hosts(),
        receipts: kept.receipts,
      )..reviewFor('bob', backup: true);
      await first.startBackup(_backupFile);
      final program = Completer<int>();
      final outlived = first.backupOutlived(program.future);
      first.dispose();

      final again = backupRecovery();
      var told = 0;
      again.addListener(() => told++);
      expect(again.whyNotForget, isNotNull);
      expect(again.whyNotRetry, isNotNull);
      expect(await again.startBackup(_backupFile), isNull, reason: 'a second terminal would run Core twice');

      program.complete(0);
      await outlived;

      expect(told, greaterThan(0));
      expect(again.whyNotForget, isNull);
      expect(again.whyNotRetry, isNull);
    });

    // Harm: two changes running Core in the registry checkout at once, a backup key and a replacement, each meeting
    // the other's commit.
    test(
      'a backup key is not made in the registry checkout while a replacement runs there, nor the other way',
      () async {
        final replacing = backupRecovery()..reviewFor('bob', backup: true);
        await replacing.startBackup(_backupFile);
        final making = BackupKeyMaking(
          scope: const RecoveryScope.hostAdmin('walk1'),
          base: _base,
          core: _Core(),
          receipts: kept.receipts,
        );
        await expectLater(making.attempt(() async {}), throwsA(isA<RegistryRefusal>()));
        final project = BackupKeyMaking(
          scope: const RecoveryScope.project('demo'),
          base: _base,
          core: _Core(),
          receipts: kept.receipts,
        );
        await project.attempt(() async {});
        await replacing.backupEnded(code: 70, lastLine: '');

        final core = _Core();
        final ending = Completer<void>();
        final attempt = making.attempt(() => ending.future);
        final filing = KeyRecovery(
          situation: _situation(scope: const RecoveryScope.hostAccess('walk1'), hosts: const []),
          core: core,
          hosts: _Hosts(),
          receipts: kept.receipts,
        );
        addTearDown(filing.dispose);
        filing.reviewFor('bob');
        expect(filing.whyNotConfirm(), isNotNull);
        await filing.confirm();
        expect(core.calls, isEmpty);

        ending.complete();
        await attempt;
        expect(filing.whyNotConfirm(), isNull);
      },
    );

    // Harm: a pushed registry replacement whose host is gone for good held for ever, locking key replacement in that
    // list; or dropped without naming the commit the person confirmed.
    test('a pushed registry replacement a host never confirms is forgotten once its commit is named', () async {
      final hosts = _Hosts()..answers['walk2'] = const WorkspaceRefused('not reached');
      final recovery = KeyRecovery(
        situation: _situation(scope: const RecoveryScope.owner(), hosts: ['walk1', 'walk2']),
        core: _Core(),
        hosts: hosts,
        receipts: kept.receipts,
      );
      addTearDown(recovery.dispose);
      recovery.reviewFor('bob');
      await recovery.confirm();
      expect([recovery.filed?.published, recovery.allConfirmed], [true, false]);
      expect(recovery.whyNotForget, isNull);

      await recovery.forget(made: _other);
      expect(kept.receipts.keys, contains('owner'), reason: 'not the commit the person read');
      await recovery.forget(made: _revision);

      expect(kept.receipts.keys, isNot(contains('owner')));
      expect(recovery.started, isFalse);
    });
  });
}
