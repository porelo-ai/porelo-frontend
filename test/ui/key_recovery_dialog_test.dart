import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/host_access.dart';
import 'package:porelo_frontend/src/app/key_recovery.dart';
import 'package:porelo_frontend/src/app/registry.dart';
import 'package:porelo_frontend/src/app/registry_checkout.dart';
import 'package:porelo_frontend/src/app/pty.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/ui/key_recovery_dialog.dart';

const _base = '1111111111111111111111111111111111111111';
const _revision = '2222222222222222222222222222222222222222';

String _key(int byte) =>
    'ssh-ed25519 ${base64.encode([
      ...[0, 0, 0, 11],
      ...utf8.encode('ssh-ed25519'),
      ...[0, 0, 0, 32],
      ...List.filled(32, byte),
    ])}';

final _old = sshFingerprint(_key(1));
final _new = sshFingerprint(_key(2));
final _admin = sshFingerprint(_key(3));

RegistryCard _card(String login, String key) =>
    RegistryCard(login: login, name: login, key: key, fingerprint: sshFingerprint(key), state: 'trusted', why: '');

/// Bob alone administers project demo with a backup key, or Alice administers it beside him.
RecoverySituation _situation({required bool backup}) => RecoverySituation(
  scope: const RecoveryScope.project('demo'),
  people: {'alice': _admin, 'bob': _old},
  cards: [_card('alice', _key(3)), _card('bob', _key(2))],
  base: _base,
  actor: backup ? HostAdminIdentity('bob', _new) : HostAdminIdentity('alice', _admin),
  hosts: const {'alice': [], 'bob': []},
  checkout: '/private/registry/checkout',
  soleAdmin: backup ? 'bob' : 'alice',
  backupRegistered: backup,
);

class _Core implements KeyRecoveryCore {
  final calls = <String>[];

  @override
  Future<RegistryRefusal?> refusal(RecoveryScope scope, {bool backup = false}) async {
    calls.add('refusal');
    return null;
  }

  @override
  Future<String?> fileFor(RecoveryReview review) async => null;

  @override
  Future<RecoveryFiled> replace(RecoveryReview review, String id, {String? content, bool again = false}) async {
    calls.add('replace');
    return const RecoveryFiled(revision: _revision, published: true);
  }

  @override
  Future<void> prepare(RecoveryScope scope) async => calls.add('prepare');

  @override
  Future<void> publish(RecoveryScope scope, String revision, {required String base}) async =>
      calls.add('publish $revision $base');
}

class _Hosts implements RevocationHosts {
  @override
  Future<HostLock> deliver(RecoveryReview review, String host, String revision) async => HostReplaced(host);
}

/// The dialog's entry: the list as read when it opened, or a refused read.
class _Entry implements KeyRecoveryEntry {
  _Entry(this.receipts, {this.read, this.refused});

  final RecoverySituation? read;
  final RegistryRefusal? refused;

  @override
  final _Core core = _Core();

  @override
  final RevocationHosts hosts = _Hosts();

  @override
  final RecoveryReceipts receipts;

  @override
  Future<RecoverySituation> situation(RecoveryScope scope) async => refused == null ? read! : throw refused!;

  @override
  List<RecoveryScope> get registryScopes => const [];

  @override
  List<RecoveryScope> get keptBackups => const [];
}

/// The registry as after a restart: nothing read yet, so only a kept request's own record opens a list.
class _Unread implements RegistryCore {
  @override
  Future<RegistryRead> read(String checkout) => throw UnimplementedError('nothing is read');

  @override
  Future<RegistryFiled> file(String checkout, RegistryFiling filing) => throw UnimplementedError('nothing is filed');
}

/// The real entry over a registry never read, with the stand-in Core and hosts.
KeyRecoveryServices _services(RecoveryReceipts receipts) => KeyRecoveryServices(
  core: _Core(),
  hosts: _Hosts(),
  registry: Registry(
    checkout: RegistryCheckout(root: '/private/registry', repository: 'git@example.org:team/registry.git'),
    core: _Unread(),
  ),
  actor: () => HostAdminIdentity('alice', _admin),
  receipts: receipts,
);

/// Bob's replacement as reviewed in [scope] and kept, made as [revision] when given, not pushed.
Map<String, Object?> _keptReplacement(RecoveryScope scope, {String? revision}) => {
  'review': RecoveryReview(
    scope: scope,
    login: 'bob',
    oldFingerprint: _old,
    newFingerprint: _new,
    newKey: _key(2),
    card: '/private/registry/checkout/people/bob.card',
    base: _base,
    hosts: const [],
  ).stored,
  'id': 'abcdef0123456789',
  'revision': revision,
  'published': false,
  'uncertain': revision == null,
  'confirmed': <String, Object?>{},
};

/// A terminal that runs nothing: it records the command and ends when the test says.
///
/// With [outlives], its program does not end when it is closed, but when the test completes that.
class _Channel implements SessionChannel {
  final _output = StreamController<List<int>>.broadcast();
  final _ended = Completer<int>();
  Completer<int>? outlives;

  void end(int code, String last) {
    _output.add(utf8.encode('$last\r\n'));
    _ended.complete(code);
  }

  @override
  Stream<List<int>> get output => _output.stream;

  @override
  void send(String input) {}

  @override
  void resize({required int columns, required int rows}) {}

  @override
  Future<int> get ended => _ended.future;

  @override
  Future<void> close() async {
    if (outlives case final program?) throw TerminalStillRunning(program.future, closeBound);
    if (!_ended.isCompleted) _ended.complete(-1);
  }
}

/// A few frames, never waiting for an open terminal to stop drawing.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  late SettingsReceipts receipts;
  late Settings settings;
  late List<List<String>> opened;
  late _Channel channel;

  setUp(() {
    settings = Settings(MemorySettingsStore());
    receipts = SettingsReceipts(settings);
    opened = [];
  });

  SessionChannel open(String executable, List<String> arguments, {int columns = 80, int rows = 24}) {
    opened.add([executable, ...arguments]);
    return channel;
  }

  Future<KeyRecovery> pump(
    WidgetTester tester,
    _Entry entry, {
    required RecoverySituation situation,
    PickAFileStandIn? pick,
    Completer<String?>? picking,
    ChooseNewFile? choose,
    List<String?>? folders,
  }) async {
    // Made inside the test's fake time, or its end would never reach the session.
    channel = _Channel();
    tester.view.physicalSize = const Size(1280, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final recovery = KeyRecovery(situation: situation, core: entry.core, hosts: entry.hosts, receipts: receipts);
    addTearDown(recovery.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KeyRecoveryDialog(
            recovery: recovery,
            entry: entry,
            login: 'bob',
            open: open,
            pickAFile: ({String? initialDirectory, String? title}) async {
              folders?.add(initialDirectory);
              final answer = pick?.call();
              return picking == null ? answer : await picking.future;
            },
            chooseNewFile: choose ?? ({String? title}) async => null,
          ),
        ),
      ),
    );
    return recovery;
  }

  VoidCallback? pressable(WidgetTester tester, String id) => tester.widget<TextButton>(find.byKey(Key(id))).onPressed;

  Future<void> tap(WidgetTester tester, String id) async {
    await tester.tap(find.byKey(Key(id)));
    await settle(tester);
  }

  // Harm: the backup key's file asked for, and its terminal opened, before the person saw the replacement, or for a
  // stolen key before they confirmed its new fingerprint in person.
  testWidgets('the backup file is asked only after review, a stolen key’s only once confirmed in person', (
    tester,
  ) async {
    var picks = 0;
    final entry = _Entry(receipts);
    await pump(
      tester,
      entry,
      situation: _situation(backup: true),
      pick: () {
        picks++;
        return null;
      },
    );

    await tap(tester, 'keyRecovery.reviewBackup');
    expect(picks, 0, reason: 'review asks for nothing');
    await tap(tester, 'keyRecovery.cancel');
    await tester.tap(find.text('Stolen'));
    await settle(tester);
    await tap(tester, 'keyRecovery.reviewBackup');
    expect(picks, 0, reason: 'review asks for nothing');
    expect(find.text('Person: bob (the login stays)'), findsOneWidget);
    expect(pressable(tester, 'keyRecovery.replace'), isNull, reason: 'not confirmed in person');

    await tester.tap(find.byKey(const Key('recovery-told-in-person')));
    await settle(tester);
    await tap(tester, 'keyRecovery.replace');
    expect(picks, 1);
    expect(entry.core.calls, isEmpty);
  });

  // Harm: a stolen key's backup replacement refused in the dialog although its new fingerprint was confirmed in person.
  testWidgets('a stolen key confirmed in person opens the backup key’s terminal with the chosen file', (tester) async {
    await pump(tester, _Entry(receipts), situation: _situation(backup: true), pick: () => '/media/usb/porelo-backup');

    await tester.tap(find.text('Stolen'));
    await settle(tester);
    await tap(tester, 'keyRecovery.reviewBackup');
    await tester.tap(find.byKey(const Key('recovery-told-in-person')));
    await settle(tester);
    await tap(tester, 'keyRecovery.replace');

    expect(opened, hasLength(1));
    expect(opened.single, containsAllInOrder(['--use', '/media/usb/porelo-backup']));
  });

  // Harm: the backup file's place held by the dialog after its terminal, shown, or reused by Retry without asking.
  testWidgets('Retry asks for the backup file again, and its place is shown nowhere', (tester) async {
    // Real file work runs outside the test's fake time, which would never complete it.
    final folder = (await tester.runAsync(() => Directory.systemTemp.createTemp('backup-')))!;
    addTearDown(() => folder.deleteSync(recursive: true));
    final file = path.join(folder.path, 'porelo-backup');
    // A real backup file this program cannot read: any read of it here fails the attempt.
    await tester.runAsync(() async {
      await File(file).writeAsString('SECRET-BACKUP-KEY');
      await Process.run('chmod', ['000', file]);
    });
    final picked = <String?>[file, null];
    final folders = <String?>[];
    var picks = 0;
    await pump(
      tester,
      _Entry(receipts),
      situation: _situation(backup: true),
      folders: folders,
      pick: () {
        picks++;
        return picked.removeAt(0);
      },
    );

    await tap(tester, 'keyRecovery.reviewBackup');
    await tap(tester, 'keyRecovery.replace');
    expect(opened.single, contains(file));
    channel.end(69, '');
    await settle(tester);
    await tap(tester, 'unlock-done');

    expect(find.textContaining(folder.path), findsNothing);
    await tap(tester, 'keyRecovery.retry');
    expect(picks, 2, reason: 'the file is asked again');
    expect(folders, [null, null], reason: 'neither the file nor its folder is offered again');
    expect(opened, hasLength(1), reason: 'no file chosen, nothing runs');
    expect(find.textContaining('SECRET'), findsNothing);
    expect(jsonEncode(settings.keyRecoveryKeys.map(settings.keyRecovery).toList()), isNot(contains(folder.path)));
  });

  Future<void> openWith(WidgetTester tester, Future<void> Function(BuildContext context) show) async {
    channel = _Channel();
    tester.view.physicalSize = const Size(1280, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(onPressed: () => show(context), child: const Text('open')),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
  }

  // Harm: a registry replacement's own unpushed commit unreachable after a restart, so nothing ever pushes it.
  testWidgets('the registry’s list choice resumes a kept unpushed replacement after a restart', (tester) async {
    await receipts.keep('owner', _keptReplacement(const RecoveryScope.owner(), revision: _revision));
    final services = _services(receipts);
    await openWith(tester, (context) => showRegistryKeyRecovery(context, entry: services));

    await tester.tap(find.byKey(const ValueKey('recovery-scope owner null')));
    await settle(tester);
    await tap(tester, 'keyRecovery.retry');

    expect((services.core as _Core).calls, ['publish $_revision $_base']);
    expect(find.textContaining('Commit $_revision, pushed'), findsOneWidget);
  });

  // Harm: a registry replacement's commit whose push fails for good locking its list for good; or dropped without the
  // person told which commit stays in the registry checkout.
  testWidgets('a made registry replacement is forgotten only through a confirmation naming its commit', (tester) async {
    await receipts.keep('owner', _keptReplacement(const RecoveryScope.owner(), revision: _revision));
    final services = _services(receipts);
    await openWith(tester, (context) => showRegistryKeyRecovery(context, entry: services));
    await tester.tap(find.byKey(const ValueKey('recovery-scope owner null')));
    await settle(tester);

    await tap(tester, 'keyRecovery.forget');
    expect(find.textContaining('commit $_revision'), findsWidgets);
    expect(find.textContaining('leaves that commit in the registry checkout'), findsOneWidget);
    await tap(tester, 'forget-attempt-confirm');

    expect(settings.keyRecoveryKeys, isEmpty);
    expect((services.core as _Core).calls, isEmpty, reason: 'nothing is pushed');
  });

  // Harm: a kept request whose answer was lost unreachable from the project's dialog, or stuck there for good with
  // no way to drop it; or dropped without the person told what may be committed under it.
  testWidgets('a kept uncertain project replacement is resumed, and Forget drops it once confirmed', (tester) async {
    await receipts.keep('project/demo', _keptReplacement(const RecoveryScope.project('demo')));
    final services = _services(receipts);
    await openWith(
      tester,
      (context) => showKeyRecovery(context, entry: services, scope: const RecoveryScope.project('demo'), login: 'bob'),
    );

    expect(find.text('Person: bob (the login stays)'), findsOneWidget);
    expect(pressable(tester, 'keyRecovery.retry'), isNotNull);
    await tap(tester, 'keyRecovery.forget');
    expect(find.textContaining('request abcdef0123456789'), findsOneWidget);
    await tester.tap(find.text('Keep it'));
    await settle(tester);
    expect(settings.keyRecoveryKeys, ['project/demo']);

    await tap(tester, 'keyRecovery.forget');
    await tap(tester, 'forget-attempt-confirm');

    expect(settings.keyRecoveryKeys, isEmpty);
    expect(find.text('Person: bob (the login stays)'), findsNothing);
    expect((services.core as _Core).calls, isEmpty);
  });

  // Harm: a new backup key made on a list known only from a kept replacement's record, without a clean read.
  testWidgets('a new backup key is never made on a list known only from a kept request', (tester) async {
    await receipts.keep('project/demo', _keptReplacement(const RecoveryScope.project('demo')));
    final services = _services(receipts);
    await openWith(
      tester,
      (context) => makeBackupKey(
        context,
        entry: services,
        scope: const RecoveryScope.project('demo'),
        open: open,
        chooseNewFile: ({String? title}) async => '/media/usb/bk',
      ),
    );

    expect(opened, isEmpty);
    expect(find.text('Refresh the registry before making a backup key.'), findsOneWidget);
    expect(settings.keyRecoveryKeys, ['project/demo']);
  });

  // Harm: the new backup key after a project replacement made on the access commit read before it, which Core
  // refuses as moved.
  testWidgets('a new backup key after a project replacement starts from the replacing commit', (tester) async {
    final entry = _Entry(receipts, read: _situation(backup: false));
    await pump(tester, entry, situation: _situation(backup: false), choose: ({String? title}) async => '/media/usb/bk');

    await tap(tester, 'keyRecovery.review');
    await tap(tester, 'keyRecovery.replace');
    expect(entry.core.calls, ['refusal', 'replace']);
    await tap(tester, 'keyRecovery.makeBackup');

    final command = opened.single;
    expect(command.sublist(command.indexOf('--base'), command.indexOf('--base') + 2), ['--base', _revision]);
    channel.end(65, '{"reason":"not-in-this-release","words":"Not yet."}');
    await settle(tester);
    await tap(tester, 'unlock-done');
    expect(find.textContaining('Not yet.'), findsOneWidget, reason: 'Core’s own words');
    expect(settings.keyRecoveryKeys, isNot(contains('backup-make/project/demo')), reason: 'nothing is kept');
  });

  // Harm: a new backup key made on a list known only from a kept request's record because a base was handed in, as
  // after a project replacement, without a clean read.
  testWidgets('a new backup key is never made on a list known only from a kept request, base or not', (tester) async {
    await receipts.keep('project/demo', _keptReplacement(const RecoveryScope.project('demo'), revision: _revision));
    final services = _services(receipts);
    await openWith(
      tester,
      (context) => makeBackupKey(
        context,
        entry: services,
        scope: const RecoveryScope.project('demo'),
        base: _revision,
        open: open,
        chooseNewFile: ({String? title}) async => '/media/usb/bk',
      ),
    );

    expect(opened, isEmpty);
    expect(find.text('Refresh the registry before making a backup key.'), findsOneWidget);
    expect(settings.keyRecoveryKeys, ['project/demo']);
  });

  // Harm: a retry that took the file an earlier attempt wrote telling the person the key is in the file they chose,
  // so they keep the wrong one and lose the backup key.
  testWidgets('a backup key made by an earlier attempt says the file it is in', (tester) async {
    final written = path.join('media', 'usb', 'bk1');
    final chosen = path.join('media', 'usb', 'bk2');
    await receipts.keep('backup-make/owner', {
      'scope': const RecoveryScope.owner().stored,
      'id': 'bk-0011',
      'base': _base,
      'uncertain': true,
    });
    final entry = _Entry(receipts, refused: const RegistryRefusal('Refresh the registry before replacing a key.'));
    await openWith(
      tester,
      (context) => makeBackupKey(
        context,
        entry: entry,
        scope: const RecoveryScope.owner(),
        open: open,
        chooseNewFile: ({String? title}) async => chosen,
      ),
    );

    expect(opened.single, containsAllInOrder(['--out', chosen, '--id', 'bk-0011']));
    channel.end(
      0,
      jsonEncode({
        'id': 'bk-0011',
        'scope': {'kind': 'registry', 'name': null},
        'fingerprint': 'SHA256:B',
        'file': written,
        'revision': _revision,
        'pushed': false,
      }),
    );
    await settle(tester);
    await tap(tester, 'unlock-done');

    expect(entry.core.calls, ['publish $_revision $_base']);
    expect(find.textContaining('Its file is $written'), findsOneWidget);
  });

  // Harm: two pickers for the backup file opening two terminals that run Core at once under one request.
  testWidgets('a second Use the backup key while its file is asked opens nothing more', (tester) async {
    final picked = Completer<String?>();
    var picks = 0;
    await pump(
      tester,
      _Entry(receipts),
      situation: _situation(backup: true),
      picking: picked,
      pick: () {
        picks++;
        return null;
      },
    );
    await tap(tester, 'keyRecovery.reviewBackup');

    await tap(tester, 'keyRecovery.replace');
    await tap(tester, 'keyRecovery.replace');
    expect(picks, 1);
    picked.complete(null);
    await settle(tester);
    expect(opened, isEmpty);
  });

  // Harm: the backup key's terminal put away while Core still runs in it, and Forget or Retry going ahead meanwhile,
  // dropping or repeating a request Core may still commit under.
  testWidgets('a terminal whose program outlives its close holds Forget and Retry until it ended', (tester) async {
    final recovery = await pump(
      tester,
      _Entry(receipts),
      situation: _situation(backup: true),
      pick: () => '/media/usb/porelo-backup',
    );
    final program = channel.outlives = Completer<int>();
    await tap(tester, 'keyRecovery.reviewBackup');
    await tap(tester, 'keyRecovery.replace');
    expect(opened, hasLength(1));
    await tap(tester, 'unlock-cancel');
    await tap(tester, 'unlock-cancel-yes');

    expect(pressable(tester, 'keyRecovery.forget'), isNull);
    expect(pressable(tester, 'keyRecovery.retry'), isNull);
    program.complete(0);
    await settle(tester);

    expect(pressable(tester, 'keyRecovery.forget'), isNotNull);
    expect(pressable(tester, 'keyRecovery.retry'), isNotNull);
    expect(recovery.requestId, isNotNull, reason: 'its answer was never read');
    expect(settings.keyRecoveryKeys, ['project/demo']);
  });

  // Harm: a backup key's commit made and not pushed that no one can push, because the list's read refuses on it.
  testWidgets('a kept backup key commit is pushed though the list cannot be read', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await receipts.keep('backup-make/owner', {
      'scope': const RecoveryScope.owner().stored,
      'id': 'bk-0011',
      'base': _base,
      'revision': _revision,
      'uncertain': false,
    });
    final entry = _Entry(receipts, refused: const RegistryRefusal('Refresh the registry before replacing a key.'));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => makeBackupKey(context, entry: entry, scope: const RecoveryScope.owner()),
              child: const Text('make'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('make'));
    await settle(tester);

    expect(entry.core.calls, ['publish $_revision $_base']);
    expect(find.text('The backup key’s commit is pushed now.'), findsOneWidget);
    expect(settings.keyRecoveryKeys, isEmpty);
  });
}

/// Answers the backup file the test picks, or null for a put-away picker.
typedef PickAFileStandIn = String? Function();
