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
);

/// The interface's settings over a store the test reads back whole.
class _Kept {
  final store = MemorySettingsStore();
  late final settings = Settings(store);
  late final receipts = SettingsReceipts(settings);

  Future<String> written() async => jsonEncode(await store.read());
}

/// Core's side as the controller sees it; every call is recorded.
class _Core implements KeyRecoveryCore {
  final calls = <String>[];
  RegistryRefusal? refuse;
  final answers = <Object>[];
  Exception? publishFails;
  // An answer that never comes: the program ends while Core runs.
  Completer<RecoveryFiled>? hold;

  @override
  Future<RegistryRefusal?> refusal(RecoveryScope scope, {bool backup = false}) async {
    calls.add(backup ? 'refusal backup' : 'refusal');
    return refuse;
  }

  @override
  Future<RecoveryFiled> replace(RecoveryReview review, String id) async {
    calls.add('replace $id ${review.base}');
    if (hold case final held?) return held.future;
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
      if (replaceAnswers.isNotEmpty) return replaceAnswers.removeAt(0);
      return (code: 0, out: jsonEncode({'revision': _revision}), err: '');
    }
    return (code: 64, out: '', err: 'unexpected call');
  }

  List<List<String>> get replaces => [
    for (final call in calls)
      if (call.skip(1).take(3).join(' ') == 'project access replace') call,
  ];
}

CliKeyRecoveryCore _cliProject(_Porelo porelo) => CliKeyRecoveryCore(
  actor: () => HostAdminIdentity('alice', _admin),
  run: porelo.run,
  project: (project) => ProjectAccessCoreAdapter(
    directory: '/workspace/$project',
    run: porelo.run,
    source: ProjectVerifySource(repository: '/workspace/demo.bundle', signedBy: [_adminKey]),
    registryCheckout: _checkout,
    agentKeys: () async => [_adminKey],
  ),
);

/// The registry checkout: records prepare and push; a push can be made to fail.
class _Checkout implements RegistryCheckout {
  final calls = <String>[];
  WorkspaceRefused? refusePush;
  WorkspaceRefused? refuseFetch;

  @override
  String get root => '/private/registry';

  @override
  String get repository => 'git@example.org:team/registry.git';

  @override
  String get folder => _checkout;

  @override
  Future<String> fetch() async {
    if (refuseFetch case final refused?) throw refused;
    return _base;
  }

  @override
  Future<void> prepareFiling() async => calls.add('prepare');

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
  String bobState = 'trusted';

  @override
  Future<RegistryRead> read(String checkout) async => RegistryRead.from({
    'revision': _base,
    'people': [
      {'login': 'alice', 'name': 'Alice', 'key': _adminKey, 'fingerprint': _admin, 'state': 'trusted'},
      {'login': 'bob', 'name': 'Bob', 'key': _newKey, 'fingerprint': _new, 'state': bobState},
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

    KeyRecovery backupRecovery(_Core core, _Hosts hosts, {RecoveryScope scope = const RecoveryScope.project('demo')}) {
      final recovery = KeyRecovery(
        situation: _situation(scope: scope, sole: 'bob', backup: true, actor: 'bob'),
        core: core,
        hosts: hosts,
        receipts: kept.receipts,
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
    // would extend the backup key's authority beyond the one entry it may change.
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

    // Harm: a put-away or refused terminal keeping a request, so Cancel stays blocked and Retry is offered.
    for (final (code, out) in [
      (-1, ''),
      (64, ''),
      (65, '{"reason":"wrong-passphrase","words":"the backup file did not open"}'),
      (66, ''),
    ]) {
      test('a terminal ending with $code keeps no request, so Cancel works and no Retry is offered', () async {
        final (recovery, core, hosts, _) = await started();

        await recovery.backupEnded(code: code, lastLine: out);

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
        _base,
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
      final restarted = backupRecovery(_Core(), _Hosts(), scope: const RecoveryScope.owner());

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
      final (recovery, _, _, command) = await started(scope: const RecoveryScope.owner());
      expect(recovery.whyNotForget, isNotNull, reason: 'the terminal is open');
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

    // Harm: an exit-0 answer that fails the checks taken as proof that nothing was made, or the program ending while
    // the terminal runs, so a put-away retry drops the request and the next makes a second backup key.
    for (final (what, code, out) in [
      ('an exit-0 answer that fails the checks', 0, made(revision: 'HEAD', file: '/media/usb/bk1')),
      ('a restart while the terminal runs', null, ''),
    ]) {
      test('after $what, a put-away retry keeps the request', () async {
        final kept = _Kept();
        BackupKeyMaking making() =>
            BackupKeyMaking(scope: const RecoveryScope.owner(), base: _base, core: _Core(), receipts: kept.receipts);
        final first = await making().start('/media/usb/bk1');
        if (code != null) {
          await expectLater(
            making().ended(code: code, lastLine: out.replaceFirst('"ID"', '"${_idOf(first)}"'), out: '/media/usb/bk1'),
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
      expect(making().unpublished, _revision);
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
        core: _cliProject(porelo),
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
      expect(hosts.calls.map((call) => call.split(' ').first), ['walk1', 'walk2']);

      hosts.answers.remove('walk2');
      await recovery.retry();
      expect(porelo.replaces, hasLength(2), reason: 'no second commit');
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
        core: _cliProject(porelo),
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
        core: _Core()..hold = Completer(),
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
        receipts: kept.receipts,
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

    // Harm: a dialog closed and opened again making a second commit under a fresh request.
    test('reopening after a failed push repeats the same request on the same base', () async {
      final kept = _Kept();
      final porelo = _Porelo()..replaceAnswers.add((code: 69, out: '', err: ''));
      final first = KeyRecovery(
        situation: _situation(hosts: ['walk1']),
        core: _cliProject(porelo),
        hosts: _Hosts(),
        receipts: kept.receipts,
      );
      first.reviewFor('bob');
      await first.confirm();
      first.dispose();

      final again = KeyRecovery(
        situation: _situation(hosts: ['walk1']),
        core: _cliProject(porelo),
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
      expect(await kept.written(), isNot(contains('"bob"')), reason: 'a finished request is forgotten');
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
      expect(recovery.whyNotForget, isNotNull, reason: 'a made commit is pushed, never forgotten');
      checkout.refusePush = null;
      await recovery.retry();
      expect(registryCore.filed, hasLength(1), reason: 'no second filing');
      expect(checkout.calls.where((call) => call == 'push $_revision $_base'), hasLength(2));
      expect(recovery.allConfirmed, isTrue);
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

    // Harm: a replacement signed by someone Core does not name as project admin here.
    test('a forged project admin is refused before the replacement verb runs', () async {
      final porelo = _Porelo()..admins = [];
      final recovery = make(_situation(), _cliProject(porelo));
      recovery.reviewFor('bob');

      await recovery.confirm();

      expect(porelo.replaces, isEmpty);
      expect(recovery.filed, isNull);
      expect(recovery.problem, contains('Only an active project admin'));
    });

    // Harm: the replacement filed with another card, base or person than reviewed.
    test('a project admin’s replacement is Core’s replace verb with the reviewed values', () async {
      final porelo = _Porelo();
      final recovery = make(_situation(hosts: ['walk1']), _cliProject(porelo));
      recovery.reviewFor('bob');

      await recovery.confirm();

      final call = porelo.replaces.single;
      expect(call.take(12), [
        'porelo',
        'project',
        'access',
        'replace',
        '--project',
        'demo',
        '--person',
        'bob',
        '--card',
        _bobCard,
        '--base',
        _base,
      ]);
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
      expect(recovery.problem, contains('not been checked'));
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
  });

  group('a project read before a commit made here starts from that commit', () {
    // Harm: a later replacement or backup key in a project built on the access commit read before one made here,
    // which Core refuses as moved.
    test('the newest commit made here on the project read is the base', () async {
      final kept = _Kept();
      final registry = Registry(checkout: _Checkout(), core: _RegistryCore());
      addTearDown(registry.dispose);
      await registry.refresh();
      var read = _base;
      ProjectAccessView view() => ProjectAccessView(
        project: 'demo',
        host: PreparedHost.read(sshCompletion()),
        projectRevision: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
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
      final core = _Core()
        ..answers.addAll([
          const RecoveryFiled(revision: _revision, published: true),
          const RecoveryFiled(revision: _other, published: true),
        ]);
      final services = KeyRecoveryServices(
        core: core,
        hosts: _Hosts(),
        registry: registry,
        actor: () => HostAdminIdentity('alice', _admin),
        receipts: kept.receipts,
        projectView: (_) => view(),
      );
      Future<void> replaceBob() async {
        final recovery = KeyRecovery(
          situation: await services.situation(const RecoveryScope.project('demo')),
          core: core,
          hosts: _Hosts(),
          receipts: kept.receipts,
        );
        addTearDown(recovery.dispose);
        recovery.reviewFor('bob');
        await recovery.confirm();
        await kept.receipts.forget(const RecoveryScope.project('demo').receiptKey);
      }

      await replaceBob();
      expect((await services.situation(const RecoveryScope.project('demo'))).base, _revision);
      await replaceBob();
      expect(core.calls.where((call) => call.startsWith('replace')).map((call) => call.split(' ').last), [
        _base,
        _revision,
      ]);
      expect((await services.situation(const RecoveryScope.project('demo'))).base, _other);
      read = _other;
      expect((await services.situation(const RecoveryScope.project('demo'))).base, _other);
    });
  });
}
