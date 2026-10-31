import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/host_access.dart';
import 'package:porelo_frontend/src/app/key_recovery.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/registry.dart';
import 'package:porelo_frontend/src/app/registry_checkout.dart';
import 'package:porelo_frontend/src/app/pty.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/ui/key_recovery_dialog.dart';
import 'package:porelo_frontend/src/ui/unlock_terminal.dart';

const _base = '1111111111111111111111111111111111111111';
const _revision = '2222222222222222222222222222222222222222';
const _other = '3333333333333333333333333333333333333333';
const _project = '4444444444444444444444444444444444444444';

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

/// Bob alone administers project demo with a backup key, or Alice administers it beside him; its access read at
/// [base], its own repository at [project].
RecoverySituation _situation({required bool backup, String base = _base, String project = _project}) =>
    RecoverySituation(
      scope: const RecoveryScope.project('demo'),
      people: {'alice': _admin, 'bob': _old},
      cards: [_card('alice', _key(3)), _card('bob', _key(2))],
      base: base,
      actor: backup ? HostAdminIdentity('bob', _new) : HostAdminIdentity('alice', _admin),
      hosts: const {'alice': [], 'bob': []},
      checkout: '/private/registry/checkout',
      soleAdmin: backup ? 'bob' : 'alice',
      backupRegistered: backup,
      backupBase: project,
      cardTexts: {'bob': _bobCard},
    );

/// Bob's new card as the checkout holds it.
final _bobCard = 'login: "bob"\nkey: "${_key(2)}"\n';

/// Core's side as the dialog sees it; it holds the registry checkout as the registry does, one token at a time.
class _Core implements KeyRecoveryCore {
  final calls = <String>[];

  /// The token the registry checkout is held by now.
  Object? holder;

  /// The card copies handed to Core and not removed.
  final copies = <String>{};

  /// Held open while given: Core's checks before a run take that long.
  Completer<void>? holding;

  @override
  Future<RegistryRefusal?> refusal(RecoveryScope scope, {bool backup = false}) async {
    calls.add('refusal');
    await holding?.future;
    return null;
  }

  @override
  Future<String?> fileFor(RecoveryReview review, {Object? holder}) async => _bobCard;

  @override
  Future<void> checkReviewed(RecoveryReview review, {Object? holder}) async {}

  @override
  Future<RecoveryFiled> replace(
    RecoveryReview review,
    String id, {
    String? content,
    bool again = false,
    Object? holder,
  }) async {
    calls.add('replace');
    return const RecoveryFiled(revision: _revision, published: true);
  }

  @override
  Future<void> prepare(RecoveryScope scope, {Object? holder}) async {
    if (scope.inRegistry && !identical(holder, this.holder)) throw StateError('prepared without the hold');
    calls.add('prepare');
    await holding?.future;
  }

  @override
  Future<void> publish(
    RecoveryScope scope,
    String revision, {
    required String base,
    required String id,
    Object? holder,
  }) async {
    if (scope.inRegistry && !identical(holder, this.holder)) throw StateError('pushed without the hold');
    calls.add('publish $revision $base');
  }

  @override
  void hold(Object holder) {
    if (this.holder != null) throw const RegistryRefusal(Registry.heldWords);
    this.holder = holder;
  }

  @override
  void release(Object holder) {
    if (identical(this.holder, holder)) this.holder = null;
  }

  @override
  Future<String> copyCard(String login, String content) async {
    final file = path.join('copies', '${copies.length}', '$login.card');
    copies.add(file);
    return file;
  }

  @override
  Future<void> dropCard(String file) async => copies.remove(file);
}

class _Hosts implements RevocationHosts {
  @override
  Future<HostLock> deliver(RecoveryReview review, String host, String revision) async => HostReplaced(host);
}

/// The dialog's entry: the list as read when it opened, or a refused read.
class _Entry implements KeyRecoveryEntry {
  _Entry(this.receipts, {this.read, this.refused}) {
    _made.add(this);
  }

  /// Every entry made in the running test, each checked for a hold or a card copy left behind as it ends.
  static final _made = <_Entry>[];

  RecoverySituation? read;
  final RegistryRefusal? refused;

  @override
  final _Core core = _Core();

  @override
  final RevocationHosts hosts = _Hosts();

  @override
  final RecoveryReceipts receipts;

  @override
  Future<RecoverySituation> situation(RecoveryScope scope) async {
    if (refused case final refusal?) throw refusal;
    final read = this.read!;
    // As the real entry reads it: a commit made here on this read is in force, which the read does not show yet; the
    // project repository's own records block nothing in the access file, and a backup key's use there is done.
    final made = madeInForce(receipts, scope, read.base);
    final own = madeInForce(receipts, scope, read.backupBase, projectRepository: true);
    final used = madeHereIn(receipts, scope, projectRepository: true).map((made) => made.replaced).nonNulls;
    return RecoverySituation(
      scope: read.scope,
      people: read.people,
      cards: read.cards,
      base: read.base,
      actor: read.actor,
      hosts: read.hosts,
      checkout: read.checkout,
      soleAdmin: read.soleAdmin,
      backupRegistered: read.backupRegistered,
      madeHere: made == read.base ? null : made,
      madeHereReplaced: made == read.base ? null : madeInForceReplaced(receipts, scope, read.base),
      backupBase: own,
      backupUsed: used.lastOrNull,
      cardTexts: read.cardTexts,
    );
  }

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

/// Bob's replacement as reviewed in [scope] and kept, made as [revision] when given, [published] or not.
Map<String, Object?> _keptReplacement(
  RecoveryScope scope, {
  String? revision,
  bool published = false,
  List<String> hosts = const [],
}) => {
  'review': RecoveryReview(
    scope: scope,
    login: 'bob',
    oldFingerprint: _old,
    newFingerprint: _new,
    newKey: _key(2),
    card: '/private/registry/checkout/people/bob.card',
    base: _base,
    hosts: hosts,
  ).stored,
  'id': 'abcdef0123456789',
  'revision': revision,
  'published': published,
  'uncertain': revision == null,
  'confirmed': <String, Object?>{},
};

/// A terminal that runs nothing: it records the command and ends when the test says.
///
/// With [outlives], its program does not end when it is closed, but when the test completes that. Otherwise a close
/// ends it with [closingCode], as a program hung up ends, after it printed [closingLine] when one is given.
class _Channel implements SessionChannel {
  final _output = StreamController<List<int>>.broadcast();
  final _ended = Completer<int>();
  Completer<int>? outlives;
  int closingCode = 129;
  String? closingLine;

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
    if (_ended.isCompleted) return;
    if (closingLine case final line?) _output.add(utf8.encode('$line\r\n'));
    _ended.complete(closingCode);
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
  late bool openRefused;

  setUp(() {
    settings = Settings(MemorySettingsStore());
    receipts = SettingsReceipts(settings);
    opened = [];
    openRefused = false;
  });

  // Harm: a dialog that went away, or a run that ended, leaving the registry checkout held for good, or a card copy
  // behind; only a terminal whose program still runs at the test's end holds it rightly.
  tearDown(() {
    final made = [..._Entry._made];
    _Entry._made.clear();
    for (final entry in made) {
      final runs = RecoveryRuns.of(entry.receipts);
      for (final key in runs.keys) {
        expect(runs.outlived(key), isTrue, reason: 'only a terminal whose program still runs keeps $key running');
      }
      if (runs.keys.isNotEmpty) continue;
      expect(entry.core.holder, isNull, reason: 'the registry checkout was let go of');
      expect(entry.core.copies, isEmpty, reason: 'every card copy was removed');
    }
  });

  SessionChannel open(String executable, List<String> arguments, {int columns = 80, int rows = 24}) {
    opened.add([executable, ...arguments]);
    if (openRefused) throw const PtyRefused('there is no terminal here');
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

  // Harm: a new backup key offered after the backup key's use, which keeps it: Core refuses a second as existing.
  testWidgets('a backup key used here offers no new backup key beside it', (tester) async {
    await pump(tester, _Entry(receipts), situation: _situation(backup: true), pick: () => '/media/usb/porelo-backup');

    await tap(tester, 'keyRecovery.reviewBackup');
    await tap(tester, 'keyRecovery.replace');
    final command = opened.single;
    channel.end(
      0,
      jsonEncode({
        'id': command[command.indexOf('--id') + 1],
        'scope': {'kind': 'project', 'name': 'demo'},
        'revision': _revision,
        'pushed': true,
        'replaced': _old,
        'by': _new,
      }),
    );
    await settle(tester);
    await tap(tester, 'unlock-done');

    expect(find.textContaining(_revision), findsWidgets, reason: 'the use is pushed');
    expect(find.byKey(const Key('keyRecovery.makeBackup')), findsNothing);
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

  // Harm: a terminal whose window goes away while its program outlives the close raising an error nobody handles,
  // which ends the interface's zone with an uncaught exception; or never telling its caller, which waits for good.
  testWidgets('a terminal whose window goes away while its program runs tells its caller, and nothing else', (
    tester,
  ) async {
    TerminalStillRunning? told;
    await openWith(tester, (context) async {
      try {
        await runInATerminal(
          context,
          title: 'Make a backup key',
          explanation: 'Its program outlives the window.',
          machine: Machine.local(),
          command: const ['porelo', 'identity', 'backup-key'],
          open: open,
          waitsOnItsProgram: true,
        );
      } on TerminalStillRunning catch (still) {
        told = still;
      }
    });
    final program = channel.outlives = Completer<int>();
    expect(opened, hasLength(1));

    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    expect(told, isNotNull, reason: 'its caller counts it as running until it ended');
    program.complete(0);
    await settle(tester);
    expect(await told!.ended, 0);
  });

  // Harm: a registry backup key's terminal whose navigator went away while it was open never returning, so the
  // registry checkout, the running mark and the card copy stay for good and every registry read waits for ever.
  testWidgets('a registry backup key’s terminal whose window goes away lets go of its hold, run and copy', (
    tester,
  ) async {
    final entry = _Entry(receipts);
    await pump(
      tester,
      entry,
      situation: RecoverySituation(
        scope: const RecoveryScope.owner(),
        people: {'bob': _old},
        cards: [_card('bob', _key(2))],
        base: _base,
        actor: HostAdminIdentity('bob', _new),
        hosts: const {'bob': []},
        checkout: '/private/registry/checkout',
        soleAdmin: 'bob',
        backupRegistered: true,
        cardTexts: {'bob': _bobCard},
      ),
      pick: () => '/media/usb/porelo-backup',
    );
    await tap(tester, 'keyRecovery.reviewBackup');
    await tap(tester, 'keyRecovery.replace');
    expect(opened, hasLength(1));
    expect([entry.core.holder, entry.core.copies], [isNotNull, hasLength(1)]);

    await tester.pumpWidget(const SizedBox());
    await settle(tester);

    expect(entry.core.holder, isNull, reason: 'the registry checkout was let go of');
    expect(entry.core.copies, isEmpty, reason: 'the card copy was removed');
    expect(RecoveryRuns.of(receipts).keys, isEmpty, reason: 'nothing counts as running');
  });

  // Harm: the replacement dialog put away by a pop asked from outside it (a back, an ancestor) while the backup key's
  // use is being readied, so the run it marks started is never ended and holds Forget, Retry and every registry
  // recovery until a restart.
  testWidgets('the dialog stays while the backup key’s use is readied, and its run ends with its terminal', (
    tester,
  ) async {
    final entry = _Entry(receipts, read: _situation(backup: true));
    await openWith(
      tester,
      (context) => showKeyRecovery(
        context,
        entry: entry,
        scope: const RecoveryScope.project('demo'),
        login: 'bob',
        open: open,
        pickAFile: ({String? initialDirectory, String? title}) async => path.join('media', 'usb', 'porelo-backup'),
      ),
    );
    final readying = entry.core.holding = Completer<void>();
    await tap(tester, 'keyRecovery.reviewBackup');
    await tap(tester, 'keyRecovery.replace');
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Close')).onPressed, isNull);

    await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
    await settle(tester);
    expect(find.byKey(const Key('key-recovery-dialog')), findsOneWidget, reason: 'a pop is refused meanwhile');
    readying.complete();
    await settle(tester);
    expect(opened, hasLength(1));
    await tap(tester, 'unlock-cancel');
    await tap(tester, 'unlock-cancel-yes');

    expect(RecoveryRuns.of(receipts).keys, isEmpty);
    expect(pressable(tester, 'keyRecovery.retry'), isNotNull);
  });

  // Harm: the replacement dialog taken away from above while the backup key's use is readied, leaving its run started
  // for good, and its request kept as uncertain although no terminal ever opened.
  testWidgets('a backup key’s use whose dialog went away before its terminal opened ends as never started', (
    tester,
  ) async {
    final entry = _Entry(receipts, read: _situation(backup: true));
    await openWith(
      tester,
      (context) => showKeyRecovery(
        context,
        entry: entry,
        scope: const RecoveryScope.project('demo'),
        login: 'bob',
        open: open,
        pickAFile: ({String? initialDirectory, String? title}) async => path.join('media', 'usb', 'porelo-backup'),
      ),
    );
    final readying = entry.core.holding = Completer<void>();
    await tap(tester, 'keyRecovery.reviewBackup');
    await tap(tester, 'keyRecovery.replace');

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await settle(tester);
    readying.complete();
    await settle(tester);

    expect(opened, isEmpty);
    expect(RecoveryRuns.of(receipts).keys, isEmpty);
    expect(settings.keyRecoveryKeys, isEmpty, reason: 'nothing ran under the request');
  });

  // Harm: a new backup key's making whose window went away before its terminal opened, leaving its request kept as
  // uncertain, so Core is said to have perhaps made a key that nothing could have made.
  testWidgets('a backup key’s making whose window went away before its terminal opened restores its request', (
    tester,
  ) async {
    final entry = _Entry(receipts, read: _situation(backup: true));
    final readying = entry.core.holding = Completer<void>();
    await openWith(
      tester,
      (context) => makeBackupKey(
        context,
        entry: entry,
        scope: const RecoveryScope.owner(),
        open: open,
        chooseNewFile: ({String? title}) async => path.join('media', 'usb', 'bk'),
      ),
    );
    expect(entry.core.calls, ['prepare'], reason: 'the making waits on Core’s prepare');
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    readying.complete();
    await settle(tester);

    expect(opened, isEmpty);
    expect(RecoveryRuns.of(receipts).keys, isEmpty);
    expect(settings.keyRecoveryKeys, isEmpty, reason: 'no terminal ran Core under it');
  });

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

  // Harm: the new backup key after a project replacement made on the access repository's commit, which Core compares
  // with the project repository's head and always refuses as moved.
  testWidgets('a new backup key after a project replacement starts from the project’s own commit', (tester) async {
    final entry = _Entry(receipts, read: _situation(backup: false));
    await pump(tester, entry, situation: _situation(backup: false), choose: ({String? title}) async => '/media/usb/bk');

    await tap(tester, 'keyRecovery.review');
    await tap(tester, 'keyRecovery.replace');
    expect(entry.core.calls, ['refusal', 'replace']);
    await tap(tester, 'keyRecovery.makeBackup');

    final command = opened.single;
    expect(command.sublist(command.indexOf('--base'), command.indexOf('--base') + 2), ['--base', _project]);
    channel.end(65, '{"reason":"not-in-this-release","words":"Not yet."}');
    await settle(tester);
    await tap(tester, 'unlock-done');
    expect(find.textContaining('Not yet.'), findsOneWidget, reason: 'Core’s own words');
    expect(settings.keyRecoveryKeys, isNot(contains('backup-make/project/demo')), reason: 'nothing is kept');
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

  // Harm: a new backup key after a project replacement made on that replacement's commit although the project was
  // read again past it, which Core refuses as moved, or makes on a base older than the one in force.
  testWidgets('a new backup key after the project was read again starts from the newer read', (tester) async {
    final entry = _Entry(receipts, read: _situation(backup: false));
    await pump(tester, entry, situation: _situation(backup: false), choose: ({String? title}) async => '/media/usb/bk');
    await tap(tester, 'keyRecovery.review');
    await tap(tester, 'keyRecovery.replace');

    entry.read = _situation(backup: false, base: _other, project: _other);
    await tap(tester, 'keyRecovery.makeBackup');

    final command = opened.single;
    expect(command.sublist(command.indexOf('--base'), command.indexOf('--base') + 2), ['--base', _other]);
  });

  // Harm: the backup key's terminal cancelled after Core started, and Core ending within the bound, taken as proof that
  // nothing was made: the request is dropped though Core may have made the commit, and the next attempt makes another.
  testWidgets('a backup key’s terminal cancelled after Core started keeps its request', (tester) async {
    final recovery = await pump(
      tester,
      _Entry(receipts),
      situation: _situation(backup: true),
      pick: () => '/media/usb/porelo-backup',
    );
    await tap(tester, 'keyRecovery.reviewBackup');
    await tap(tester, 'keyRecovery.replace');
    expect(opened, hasLength(1));

    await tap(tester, 'unlock-cancel');
    await tap(tester, 'unlock-cancel-yes');

    expect(recovery.requestId, isNotNull);
    expect(settings.keyRecoveryKeys, ['project/demo']);
    expect(pressable(tester, 'keyRecovery.retry'), isNotNull);
  });

  // Harm: Core's refusal printed while the backup key's terminal closes lost, so its exit code or its last line is not
  // the program's own: a proven nothing-made end is kept as uncertain, or said in the words of another line.
  testWidgets('a backup key refused while its terminal closes is read from its own last line and code', (tester) async {
    final recovery = await pump(
      tester,
      _Entry(receipts),
      situation: _situation(backup: true),
      pick: () => path.join('media', 'usb', 'porelo-backup'),
    );
    await tap(tester, 'keyRecovery.reviewBackup');
    await tap(tester, 'keyRecovery.replace');
    channel
      ..closingCode = 65
      ..closingLine = '{"reason":"wrong-passphrase","words":"the file did not open"}';

    await tap(tester, 'unlock-cancel');
    await tap(tester, 'unlock-cancel-yes');

    expect(recovery.problem, contains('did not open with that passphrase'));
    expect(recovery.requestId, isNull, reason: 'Core refused it: nothing was made');
    expect(settings.keyRecoveryKeys, isEmpty);
  });

  // Harm: a backup key's terminal that never started counted as one whose end was not seen, so its request is kept as
  // uncertain and locks Forget's words and every later attempt on a commit nothing could have made.
  testWidgets('a backup key whose terminal never started drops its request', (tester) async {
    final recovery = await pump(
      tester,
      _Entry(receipts),
      situation: _situation(backup: true),
      pick: () => path.join('media', 'usb', 'porelo-backup'),
    );
    openRefused = true;
    await tap(tester, 'keyRecovery.reviewBackup');
    await tap(tester, 'keyRecovery.replace');
    await tap(tester, 'unlock-done');

    expect(recovery.problem, contains('did not start Core'));
    expect(recovery.requestId, isNull);
    expect(settings.keyRecoveryKeys, isEmpty);
  });

  // Harm: the replacement dialog closed and opened again while the backup key's terminal still runs Core offering
  // Forget or a second terminal, which drop or repeat a request Core may still commit under.
  testWidgets('a dialog opened again while the backup key’s program still runs holds Forget and Retry', (tester) async {
    final entry = _Entry(receipts, read: _situation(backup: true));
    await openWith(
      tester,
      (context) => showKeyRecovery(
        context,
        entry: entry,
        scope: const RecoveryScope.project('demo'),
        login: 'bob',
        open: open,
        pickAFile: ({String? initialDirectory, String? title}) async => '/media/usb/porelo-backup',
      ),
    );
    final program = channel.outlives = Completer<int>();
    await tap(tester, 'keyRecovery.reviewBackup');
    await tap(tester, 'keyRecovery.replace');
    await tap(tester, 'unlock-cancel');
    await tap(tester, 'unlock-cancel-yes');
    await tester.tap(find.text('Close'));
    await settle(tester);

    await tester.tap(find.text('open'));
    await settle(tester);
    expect(pressable(tester, 'keyRecovery.forget'), isNull);
    expect(pressable(tester, 'keyRecovery.retry'), isNull);
    program.complete(0);
    await settle(tester);

    expect(pressable(tester, 'keyRecovery.forget'), isNotNull);
    expect(pressable(tester, 'keyRecovery.retry'), isNotNull);
    expect(opened, hasLength(1));
  });

  // Harm: a pushed registry replacement whose host never confirms stuck for good, locking key replacement in its list;
  // or dropped without the person told which hosts must be checked by hand.
  testWidgets('a pushed registry replacement is forgotten through a confirmation naming the hosts to check', (
    tester,
  ) async {
    await receipts.keep(
      'owner',
      _keptReplacement(const RecoveryScope.owner(), revision: _revision, published: true, hosts: ['walk1']),
    );
    final services = _services(receipts);
    await openWith(tester, (context) => showRegistryKeyRecovery(context, entry: services));
    await tester.tap(find.byKey(const ValueKey('recovery-scope owner null')));
    await settle(tester);

    await tap(tester, 'keyRecovery.forget');
    expect(find.textContaining('walk1 has not confirmed it'), findsOneWidget);
    await tap(tester, 'forget-attempt-confirm');

    expect(settings.keyRecoveryKeys, isEmpty);
    expect((services.core as _Core).calls, isEmpty);
  });

  // Harm: a project replacement pushed here shown, once the dialog is opened again on the read before it, as if the old
  // key were still in force and unrevoked, without the steps that follow it.
  testWidgets('a dialog opened on a read older than a replacement made here says that replacement', (tester) async {
    await keepMadeInForce(
      receipts,
      const RecoveryScope.project('demo'),
      base: _base,
      revision: _revision,
      replaced: 'bob',
    );
    final entry = _Entry(receipts, read: _situation(backup: false));
    await openWith(
      tester,
      (context) => showKeyRecovery(context, entry: entry, scope: const RecoveryScope.project('demo'), login: 'bob'),
    );

    expect(find.textContaining('Now $_old'), findsNothing);
    expect(find.textContaining(_revision), findsOneWidget);
    expect(pressable(tester, 'keyRecovery.makeBackup'), isNotNull);
    expect(pressable(tester, 'keyRecovery.review'), isNull);
  });

  // Harm: a backup key's use made here, which changes the project file alone, blocking the access file's replacements,
  // offered again on the key it replaced, or offered a new backup key Core refuses beside the one it kept.
  testWidgets('a dialog opened after a backup key’s use made here says it done and blocks nothing else', (
    tester,
  ) async {
    await keepMadeInForce(
      receipts,
      const RecoveryScope.project('demo'),
      base: _project,
      revision: _revision,
      replaced: 'bob',
      old: _old,
      projectRepository: true,
    );
    final entry = _Entry(receipts, read: _situation(backup: true));
    await openWith(
      tester,
      (context) => showKeyRecovery(context, entry: entry, scope: const RecoveryScope.project('demo'), login: 'bob'),
    );

    expect(find.byKey(const Key('recovery-backup-used')), findsOneWidget);
    expect(find.byKey(const Key('recovery-made-here')), findsNothing);
    expect(find.byKey(const Key('keyRecovery.makeBackup')), findsNothing);
    expect(pressable(tester, 'keyRecovery.reviewBackup'), isNull);
    expect(pressable(tester, 'keyRecovery.review'), isNotNull);
  });
}

/// Answers the backup file the test picks, or null for a put-away picker.
typedef PickAFileStandIn = String? Function();
