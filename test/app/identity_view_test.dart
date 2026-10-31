import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart' show RegistryFiled, RegistryRead;
import 'package:porelo_frontend/src/app/identity.dart';
import 'package:porelo_frontend/src/app/key_recovery.dart';
import 'package:porelo_frontend/src/app/pty.dart';
import 'package:porelo_frontend/src/app/registry.dart';
import 'package:porelo_frontend/src/app/registry_checkout.dart';
import 'package:porelo_frontend/src/app/run_here.dart';
import 'package:porelo_frontend/src/app/session.dart' show OpenTerminal;
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/ui/identity_view.dart';
import 'package:porelo_frontend/src/ui/key_recovery_dialog.dart' show ChooseNewFile;

import '../features/support/world.dart';

Map<String, Object?> _shown({bool revoked = false}) => {
  'login': 'ms-test-reviewer',
  'name': 'MS Test Reviewer',
  'email': null,
  'fingerprint': 'SHA256:BvxPEqOldOldOldOldOldOldOldOldOldOldOldOld',
  'key': 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOldKey',
  'created': '2026-10-31',
  'expires': '2026-11-30',
  'predecessor': null,
  'card': 'login: "ms-test-reviewer"\n',
  'agent': 'holds',
  'agent_holds_key': true,
  'revoked': revoked,
  'card_refused': null,
  'registry': <Object?>[],
  'forge': null,
  'pending': <Object?>[],
};

Future<void> _open(WidgetTester tester, Ran shown, List<List<String>> calls) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  Future<Ran> run(
    String program,
    List<String> arguments, {
    String? inDirectory,
    Map<String, String> environment = const {},
    String? input,
  }) async {
    calls.add(arguments);
    return arguments[1] == 'show' ? shown : (code: 70, out: '', err: '');
  }

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: IdentityDialog(model: IdentityModel(Identity(run: run))),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

const _base = '1111111111111111111111111111111111111111';
const _revision = '2222222222222222222222222222222222222222';

/// Core's side of a backup key's push, recorded.
class _Core implements KeyRecoveryCore {
  final calls = <String>[];

  @override
  Future<RegistryRefusal?> refusal(RecoveryScope scope, {bool backup = false}) async => null;

  @override
  Future<String?> fileFor(RecoveryReview review) => throw UnimplementedError('nothing is replaced');

  @override
  Future<RecoveryFiled> replace(RecoveryReview review, String id, {String? content, bool again = false}) =>
      throw UnimplementedError('nothing is replaced');

  @override
  Future<void> prepare(RecoveryScope scope) async => calls.add('prepare');

  @override
  Future<void> publish(RecoveryScope scope, String revision, {required String base}) async =>
      calls.add('publish $revision $base');
}

/// The registry as after a restart: nothing read yet.
class _Unread implements RegistryCore {
  @override
  Future<RegistryRead> read(String checkout) => throw UnimplementedError('nothing is read');

  @override
  Future<RegistryFiled> file(String checkout, RegistryFiling filing) => throw UnimplementedError('nothing is filed');
}

/// A backup-key request for the registry's owner kept in real settings, made as [revision] when given.
Future<(Settings, _Core, KeyRecoveryServices)> _keptBackup({String? revision}) async {
  final settings = Settings(MemorySettingsStore());
  final receipts = SettingsReceipts(settings);
  await receipts.keep('backup-make/owner', {
    'scope': const RecoveryScope.owner().stored,
    'id': 'bk-0011',
    'base': _base,
    'revision': revision,
    'uncertain': revision == null,
  });
  final core = _Core();
  final services = KeyRecoveryServices(
    core: core,
    hosts: _NoHosts(),
    registry: Registry(
      checkout: RegistryCheckout(root: '/private/registry', repository: 'git@example.org:team/registry.git'),
      core: _Unread(),
    ),
    actor: () => null,
    receipts: receipts,
  );
  return (settings, core, services);
}

class _NoHosts implements RevocationHosts {
  @override
  Future<HostLock> deliver(RecoveryReview review, String host, String revision) =>
      throw UnimplementedError('no host is asked');
}

/// Opens the dialog over [recovery]; answers how often Core's `identity show` was asked so far.
Future<int Function()> _openWith(
  WidgetTester tester,
  KeyRecoveryEntry recovery, {
  OpenTerminal? open,
  ChooseNewFile? chooseNewFile,
}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final shown = {..._shown(), 'sole_without_backup': <Object?>[]};
  var shows = 0;
  Future<Ran> run(
    String program,
    List<String> arguments, {
    String? inDirectory,
    Map<String, String> environment = const {},
    String? input,
  }) async {
    if (arguments[1] != 'show') return (code: 70, out: '', err: '');
    shows++;
    return (code: 0, out: jsonEncode(shown), err: '');
  }

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: IdentityDialog(
          model: IdentityModel(Identity(run: run)),
          recovery: recovery,
          open: open,
          chooseNewFile: chooseNewFile ?? ({String? title}) async => null,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return () => shows;
}

/// A terminal whose program does not end when it is closed, but when the test completes [program].
class _Outliving implements SessionChannel {
  final program = Completer<int>();

  @override
  Stream<List<int>> get output => const Stream.empty();

  @override
  void send(String input) {}

  @override
  void resize({required int columns, required int rows}) {}

  @override
  Future<int> get ended => program.future;

  @override
  Future<void> close() => throw TerminalStillRunning(program.future, closeBound);
}

bool _pressable(WidgetTester tester, String id) => tester.widget<TextButton>(find.byKey(Key(id))).onPressed != null;

void main() {
  // Harm: a backup key's commit made here and not pushed, which `identity show` already counts as filed, leaving
  // nothing that pushes it; or, once pushed, the card not read again, so the action stays a push of nothing.
  testWidgets('a kept backup key not pushed keeps its action offered as a push again', (tester) async {
    final (settings, core, services) = await _keptBackup(revision: _revision);
    final shows = await _openWith(tester, services);
    final before = shows();
    expect(find.text('Push the backup key again…'), findsOneWidget);

    await tester.tap(find.byKey(const Key('identity.backupKey')));
    await World.settle(tester);
    expect(core.calls, ['publish $_revision $_base']);
    await tester.tap(find.text('Close').last);
    await World.settle(tester);

    expect(settings.keyRecoveryKeys, isEmpty);
    expect(shows(), greaterThan(before), reason: 'the card is read again after the push');
    expect(find.text('Push the backup key again…'), findsNothing);
  });

  // Harm: a made backup-key commit whose push fails for good locking Make a backup key for every list; or dropped
  // without the person told that the commit stays in the registry checkout.
  testWidgets('a made backup key commit is forgotten only through a confirmation naming it', (tester) async {
    final (settings, core, services) = await _keptBackup(revision: _revision);
    await _openWith(tester, services);

    await tester.tap(find.byKey(const Key('identity.forgetBackup')));
    await World.settle(tester);
    expect(find.textContaining('commit $_revision'), findsOneWidget);
    expect(find.textContaining('leaves that commit in the registry checkout'), findsOneWidget);
    await tester.tap(find.byKey(const Key('forget-attempt-confirm')));
    await World.settle(tester);

    expect(settings.keyRecoveryKeys, isEmpty);
    expect(core.calls, isEmpty, reason: 'nothing is pushed');
  });

  // Harm: a kept backup key's request forgotten while its attempt runs: while the save dialog is open, or after its
  // terminal was put away while Core still ran, so Core's commit lands under a request no longer kept.
  testWidgets('Forget waits while a backup key is being made, until its terminal’s program ended', (tester) async {
    final (settings, _, services) = await _keptBackup();
    final channel = _Outliving();
    final where = Completer<String?>();
    await _openWith(
      tester,
      services,
      open: (executable, arguments, {columns = 80, rows = 24}) => channel,
      chooseNewFile: ({String? title}) => where.future,
    );
    expect(_pressable(tester, 'identity.forgetBackup'), isTrue);

    await tester.tap(find.byKey(const Key('identity.backupKey')));
    await World.settle(tester);
    expect(_pressable(tester, 'identity.forgetBackup'), isFalse, reason: 'its file’s place is being asked');
    expect(_pressable(tester, 'identity.backupKey'), isFalse);
    where.complete('/media/usb/bk');
    await World.settle(tester);
    await tester.tap(find.byKey(const Key('unlock-cancel')));
    await World.settle(tester);
    await tester.tap(find.byKey(const Key('unlock-cancel-yes')));
    await World.settle(tester);
    // Whatever is said meanwhile, put away as a person would.
    if (find.textContaining('its answer was not read').evaluate().isNotEmpty) {
      await tester.tap(find.text('Close').last);
      await World.settle(tester);
    }
    expect(_pressable(tester, 'identity.forgetBackup'), isFalse, reason: 'Core still runs');

    channel.program.complete(0);
    await World.settle(tester);
    expect(find.textContaining('its answer was not read'), findsOneWidget);
    await tester.tap(find.text('Close').last);
    await World.settle(tester);

    expect(_pressable(tester, 'identity.forgetBackup'), isTrue);
    expect(settings.keyRecoveryKeys, ['backup-make/owner'], reason: 'Core may have made it');
  });

  // Harm: a kept backup-key request whose answer was lost locking the action for good, or dropped without the person
  // told what may already be made under it.
  testWidgets('a kept backup key whose answer was lost is forgotten only once confirmed', (tester) async {
    final (settings, core, services) = await _keptBackup();
    await _openWith(tester, services);

    await tester.tap(find.byKey(const Key('identity.forgetBackup')));
    await World.settle(tester);
    expect(find.textContaining('request bk-0011'), findsOneWidget);
    await tester.tap(find.text('Keep it'));
    await World.settle(tester);
    expect(settings.keyRecoveryKeys, ['backup-make/owner']);
    await tester.tap(find.byKey(const Key('identity.forgetBackup')));
    await World.settle(tester);
    await tester.tap(find.byKey(const Key('forget-attempt-confirm')));
    await World.settle(tester);

    expect(settings.keyRecoveryKeys, isEmpty);
    expect(find.byKey(const Key('identity.forgetBackup')), findsNothing);
    expect(core.calls, isEmpty);
  });

  testWidgets('a revoked key offers no change of key, only the lost-key replacement', (tester) async {
    // Harm: a successor card signed by a revoked key is offered from the page.
    final calls = <List<String>>[];
    await _open(tester, (code: 0, out: jsonEncode(_shown(revoked: true)), err: ''), calls);
    final change = tester.widget<TextButton>(find.byKey(const Key('identity.changeKey')));
    expect(change.onPressed, isNull);
    final lost = tester.widget<TextButton>(find.byKey(const Key('identity.lostKey')));
    expect(lost.onPressed, isNotNull);
    expect(tester.widget<TextButton>(find.byKey(const Key('identity.backupKey'))).onPressed, isNull);
  });

  testWidgets('the first card is made only after the review, and never a second time', (tester) async {
    // Harm: a card made from unreviewed answers, or a second key made when the step is entered again.
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final calls = <List<String>>[];
    Future<Ran> run(
      String program,
      List<String> arguments, {
      String? inDirectory,
      Map<String, String> environment = const {},
      String? input,
    }) async {
      calls.add(arguments);
      return switch (arguments[1]) {
        'keys' => (
          code: 0,
          out: jsonEncode({
            'keys': [
              {
                'fingerprint': 'SHA256:NewNewNew',
                'key': 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINew',
                'comment': 'laptop',
                'usable': true,
                'reason': null,
                'key_listed': null,
              },
            ],
          }),
          err: '',
        ),
        'create' => (code: 65, out: '{"reason":"key-not-in-agent","words":"the agent does not serve it"}', err: ''),
        _ => (code: 65, out: '{"reason":"no-identity","words":"no card is kept"}', err: ''),
      };
    }

    final model = IdentityModel(Identity(run: run));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => FirstStartWizard(model: model),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    Future<void> tap(String key) async {
      await tester.tap(find.byKey(Key(key)));
      await World.settle(tester);
    }

    await tester.tap(find.text('Open'));
    await World.settle(tester);

    await tester.enterText(find.byKey(const Key('identity-login')), 'ms-test-reviewer');
    await tester.enterText(find.byKey(const Key('identity-name')), 'MS Test Reviewer');
    await World.settle(tester);
    await tap('wizard-next');
    await tap('identity-use-existing');
    await tap('identity-key SHA256:NewNewNew');
    await tap('wizard-next');
    expect(calls.where((call) => call[1] == 'create'), isEmpty);
    await tap('identity-wizard-make');
    expect(calls.where((call) => call[1] == 'create').single, [
      'identity',
      'create',
      '--login',
      'ms-test-reviewer',
      '--name',
      'MS Test Reviewer',
      '--key',
      'SHA256:NewNewNew',
      '--json',
    ]);
    await tap('wizard-back');
    await tap('identity-wizard-make');
    expect(calls.where((call) => call[1] == 'create'), hasLength(1));
    expect(calls.last, ['identity', 'show', '--json']);
  });

  testWidgets('picking a new key shows what changes and runs nothing before the confirmation', (tester) async {
    // Harm: a key change that rewrites the registry, projects and hosts from a single tap in a list.
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final calls = <List<String>>[];
    Future<Ran> run(
      String program,
      List<String> arguments, {
      String? inDirectory,
      Map<String, String> environment = const {},
      String? input,
    }) async {
      calls.add(arguments);
      return switch (arguments[1]) {
        'show' => (code: 0, out: jsonEncode(_shown()), err: ''),
        'keys' => (code: 0, out: jsonEncode(_keys), err: ''),
        _ => (code: 70, out: '', err: ''),
      };
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IdentityDialog(model: IdentityModel(Identity(run: run))),
        ),
      ),
    );
    await World.settle(tester);
    Future<void> tap(String key) async {
      await tester.ensureVisible(find.byKey(Key(key)));
      await World.settle(tester);
      await tester.tap(find.byKey(Key(key)));
      await World.settle(tester);
    }

    await tap('identity.changeKey');
    await tap('identity-new-in-keepassxc');
    await tester.enterText(find.byKey(const Key('identity-database')), '/home/ms/Passwords.kdbx');
    await World.settle(tester);
    await tap('identity-open-terminal');
    expect(find.byKey(const Key('identity-rotation-review')), findsOneWidget);
    expect(find.byKey(const Key('identity-unfinished')), findsNothing);
    await tap('identity-rotation-cancel');

    await tap('identity.changeKey');
    await tap('identity-key SHA256:NewNewNew');
    expect(calls.where((call) => call[1] == 'rotate'), isEmpty);
    expect(find.byKey(const Key('identity-rotation-review')), findsOneWidget);
    await tap('identity-rotation-confirm');
    expect(calls.where((call) => call[1] == 'rotate'), hasLength(1));
  });

  testWidgets('a card kept before the wizard opened is never taken as the one made', (tester) async {
    // Harm: after a failed create, reading again shows an older card already on disk as the new working one.
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Future<Ran> run(
      String program,
      List<String> arguments, {
      String? inDirectory,
      Map<String, String> environment = const {},
      String? input,
    }) async => switch (arguments[1]) {
      'keys' => (code: 0, out: jsonEncode(_keys), err: ''),
      'create' => (code: 65, out: '{"reason":"key-not-in-agent","words":"the agent does not serve it"}', err: ''),
      _ => (code: 0, out: jsonEncode({..._shown(), 'fingerprint': 'SHA256:NewNewNew'}), err: ''),
    };

    // The wizard opens before anything was read, as on a first start.
    final model = IdentityModel(Identity(run: run));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => FirstStartWizard(model: model),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    Future<void> tap(String key) async {
      await tester.tap(find.byKey(Key(key)));
      await World.settle(tester);
    }

    await tester.tap(find.text('Open'));
    await World.settle(tester);
    await tester.enterText(find.byKey(const Key('identity-login')), 'ms-test-reviewer');
    await tester.enterText(find.byKey(const Key('identity-name')), 'MS Test Reviewer');
    await World.settle(tester);
    await tap('wizard-next');
    await tap('identity-use-existing');
    await tap('identity-key SHA256:NewNewNew');
    await tap('wizard-next');
    await tap('identity-wizard-make');
    await tap('identity-reread');
    expect(find.text('Your card is made.'), findsNothing);
  });

  testWidgets('the first start is done only for the new key, served by the agent', (tester) async {
    // Harm: a card the agent does not serve reads as a working first start.
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var made = false;
    Future<Ran> run(
      String program,
      List<String> arguments, {
      String? inDirectory,
      Map<String, String> environment = const {},
      String? input,
    }) async {
      switch (arguments[1]) {
        case 'keys':
          return (code: 0, out: jsonEncode(_keys), err: '');
        case 'create':
          made = true;
          return (
            code: 0,
            out: jsonEncode({
              'login': 'ms-test-reviewer',
              'fingerprint': 'SHA256:NewNewNew',
              'key': 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINew',
              'card': 'c',
              'agent': 'holds',
              'forge': null,
              'next': ['file-card'],
            }),
            err: '',
          );
        default:
          return made
              ? (
                  code: 0,
                  out: jsonEncode({
                    ..._shown(),
                    'fingerprint': 'SHA256:NewNewNew',
                    'agent': 'not-held',
                    'agent_holds_key': false,
                  }),
                  err: '',
                )
              : (code: 65, out: '{"reason":"no-identity","words":"no card is kept"}', err: '');
      }
    }

    final model = IdentityModel(Identity(run: run));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => FirstStartWizard(model: model),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    Future<void> tap(String key) async {
      await tester.tap(find.byKey(Key(key)));
      await World.settle(tester);
    }

    await tester.tap(find.text('Open'));
    await World.settle(tester);
    await tester.enterText(find.byKey(const Key('identity-login')), 'ms-test-reviewer');
    await tester.enterText(find.byKey(const Key('identity-name')), 'MS Test Reviewer');
    await World.settle(tester);
    await tap('wizard-next');
    await tap('identity-use-existing');
    await tap('identity-key SHA256:NewNewNew');
    await tap('wizard-next');
    await tap('identity-wizard-make');
    expect(made, isTrue);
    expect(model.card?.fingerprint, 'SHA256:NewNewNew');
    expect(tester.widget<FilledButton>(find.byKey(const Key('wizard-next'))).onPressed, isNull);
  });
}

const _keys = {
  'keys': [
    {
      'fingerprint': 'SHA256:NewNewNew',
      'key': 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINew',
      'comment': 'laptop',
      'usable': true,
      'reason': null,
      'key_listed': null,
    },
  ],
};
