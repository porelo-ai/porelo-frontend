import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/host_access.dart';
import 'package:porelo_frontend/src/app/key_recovery.dart';
import 'package:porelo_frontend/src/app/registry.dart';
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
  Future<RecoveryFiled> replace(RecoveryReview review, String id) async {
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

/// A terminal that runs nothing: it records the command and ends when the test says.
class _Channel implements SessionChannel {
  final _output = StreamController<List<int>>.broadcast();
  final _ended = Completer<int>();

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
    ChooseNewFile? choose,
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
            pickAFile: ({String? initialDirectory, String? title}) async => pick?.call(),
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

  // Harm: the backup file's place held by the dialog after its terminal, shown, or reused by Retry without asking.
  testWidgets('Retry asks for the backup file again, and its place is shown nowhere', (tester) async {
    // Real file work runs outside the test's fake time, which would never complete it.
    final folder = (await tester.runAsync(() => Directory.systemTemp.createTemp('backup-')))!;
    addTearDown(() => folder.deleteSync(recursive: true));
    final file = '${folder.path}/porelo-backup';
    final picked = <String?>[file, null];
    var picks = 0;
    await pump(
      tester,
      _Entry(receipts),
      situation: _situation(backup: true),
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
    expect(opened, hasLength(1), reason: 'no file chosen, nothing runs');
    expect(jsonEncode(settings.keyRecoveryKeys.map(settings.keyRecovery).toList()), isNot(contains(folder.path)));
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
