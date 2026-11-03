import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:porelo_frontend/src/app/identity.dart';
import 'package:porelo_frontend/src/app/pty.dart';
import 'package:porelo_frontend/src/app/run_here.dart';
import 'package:porelo_frontend/src/app/session.dart';
import 'package:porelo_frontend/src/ui/identity_view.dart';

import '../features/support/world.dart';

Map<String, Object?> _shown({bool revoked = false}) => {
  'login': 'rowan-example',
  'name': 'Rowan Example',
  'email': null,
  'fingerprint': 'SHA256:BvxPEqOldOldOldOldOldOldOldOldOldOldOldOld',
  'key': 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOldKey',
  'created': '2026-10-31',
  'expires': '2026-11-30',
  'predecessor': null,
  'card': 'login: "rowan-example"\n',
  'agent': 'holds',
  'agent_holds_key': true,
  'revoked': revoked,
  'card_refused': null,
  'organization': <Object?>[],
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

/// A terminal whose program ends with [code] and prints [last] while the terminal closes, before nothing else.
class _AnswersOnClose implements SessionChannel {
  _AnswersOnClose(this.code, this.last);

  final int code;
  final String last;
  final _output = StreamController<List<int>>.broadcast();
  final _ended = Completer<int>();

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
    _output.add(utf8.encode('$last\r\n'));
    if (!_ended.isCompleted) _ended.complete(code);
  }
}

const _waiting = 'SHA256:WaitingWaitingWaitingWaitingWaitingWaitingWa';
const _other = 'SHA256:OtherOtherOtherOtherOtherOtherOtherOtherOth';
const _rowId = 'rot-20261031-1';

/// Core with one pending rotation, until told it [_Pending.stands].
class _Pending {
  _Pending(this.row);

  final Map<String, Object?> row;
  final calls = <List<String>>[];
  bool stands = false;

  Future<Ran> run(
    String program,
    List<String> arguments, {
    String? inDirectory,
    Map<String, String> environment = const {},
    String? input,
  }) async {
    calls.add(arguments);
    if (stands && arguments[1] == 'rotate') {
      return (code: 65, out: jsonEncode({'reason': 'exists', 'words': 'its first card stands'}), err: '');
    }
    final answer = switch (arguments[1]) {
      'show' => {
        ..._shown(),
        'pending': [row],
      },
      'keys' => {
        'keys': [
          {
            'fingerprint': _other,
            'key': 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOtherKey',
            'comment': 'other',
            'usable': true,
            'reason': null,
            'key_listed': null,
          },
        ],
      },
      _ => {'revision': null, 'id': arguments[arguments.indexOf('--id') + 1], 'again': false},
    };
    return (code: 0, out: jsonEncode(answer), err: '');
  }

  Iterable<List<String>> get rotations => calls.where((call) => call[1] == 'rotate');
}

Future<_Pending> _openPending(WidgetTester tester, Map<String, Object?> row) async {
  tester.view.physicalSize = const Size(1280, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final core = _Pending(row);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: IdentityDialog(model: IdentityModel(Identity(run: core.run))),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return core;
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

void main() {
  // Harm: discovery signs a card before review, or a second tap signs again while the first answer is lost.
  testWidgets('a proposed card is signed once only after confirmation', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final calls = <List<String>>[];
    final signing = Completer<Ran>();
    final shown = _shown();
    final fingerprint = shown['fingerprint']! as String;
    Future<Ran> run(
      String program,
      List<String> arguments, {
      String? inDirectory,
      Map<String, String> environment = const {},
      String? input,
    }) async {
      calls.add(arguments);
      expect(input, isNull);
      expect(environment, isEmpty);
      return switch (arguments[1]) {
        'show' => (code: 65, out: '{"reason":"no-identity"}', err: ''),
        'propose' => (
          code: 0,
          out: jsonEncode({
            'forge': 'https://github.com',
            'login': {'value': shown['login'], 'source': 'forge'},
            'name': {'value': shown['name'], 'source': 'git config'},
            'email': null,
            'key': {'fingerprint': fingerprint, 'key': shown['key'], 'source': 'git config', 'in_agent': true},
            'missing': <String>[],
            'ambiguous': <Object?>[],
            'notes': <String>[],
            'ssh_add': null,
            'ready': true,
          }),
          err: '',
        ),
        'create' => await signing.future,
        _ => (code: 70, out: '', err: ''),
      };
    }

    final model = IdentityModel(Identity(run: run));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: IdentityDialog(model: model)),
      ),
    );
    await World.settle(tester);
    await tester.tap(find.byKey(const Key('identity-make-card')));
    await World.settle(tester);
    expect(find.byKey(const Key('identity-proposal')), findsOneWidget);
    expect(calls.where((call) => call[1] == 'create'), isEmpty);
    await tester.tap(find.byKey(const Key('identity-proposal-sign')));
    await tester.pump();
    expect(calls.where((call) => call[1] == 'create'), hasLength(1));
    expect(tester.widget<FilledButton>(find.byKey(const Key('identity-proposal-sign'))).onPressed, isNull);
    signing.complete((code: 0, out: '{', err: ''));
    await World.settle(tester);
    expect(tester.widget<FilledButton>(find.byKey(const Key('identity-proposal-sign'))).onPressed, isNull);
    expect(calls.where((call) => call[1] == 'create').single, [
      'identity',
      'create',
      '--login',
      'rowan-example',
      '--name',
      'Rowan Example',
      '--key',
      fingerprint,
      '--json',
    ]);
  });

  // Harm: a missing card value is silently supplied or an SSH command executes without review.
  testWidgets('missing proposal values must be entered before signing', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final calls = <List<String>>[];
    final shown = _shown();
    Future<Ran> run(
      String program,
      List<String> arguments, {
      String? inDirectory,
      Map<String, String> environment = const {},
      String? input,
    }) async {
      expect(program, 'porelo');
      calls.add(arguments);
      return arguments[1] == 'propose'
          ? (
              code: 0,
              out: jsonEncode({
                'forge': 'https://github.com',
                'login': {'value': shown['login'], 'source': 'forge'},
                'name': null,
                'email': null,
                'key': {'fingerprint': shown['fingerprint'], 'key': shown['key'], 'source': 'git', 'in_agent': false},
                'missing': ['name'],
                'ambiguous': <Object?>[],
                'notes': <String>[],
                'ssh_add': 'ssh-add ~/.ssh/example-key',
                'ready': false,
              }),
              err: '',
            )
          : (code: 65, out: '{"reason":"no-identity"}', err: '');
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IdentityDialog(model: IdentityModel(Identity(run: run))),
        ),
      ),
    );
    await World.settle(tester);
    await tester.tap(find.byKey(const Key('identity-make-card')));
    await World.settle(tester);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('identity-proposal-sign'))).onPressed, isNull);
    expect(find.byKey(const Key('identity-proposal-ssh-add')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('identity-proposal-name')), 'Rowan Example');
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byKey(const Key('identity-proposal-sign'))).onPressed, isNotNull);
    expect(calls.map((call) => call[1]), ['show', 'propose']);
  });
  // Harm: a dialog with no way out, since it does not show the lost-key plan whose Cancel would be the one.
  testWidgets('My key and card can be closed while a lost-key plan is held', (tester) async {
    final model = IdentityModel(
      Identity(run: (_, _, {inDirectory, environment = const {}, input}) async => (code: 70, out: '', err: '')),
    );
    model.lostKeyPlan = (
      plan: const LostKeyPlan(whoMay: [], hosts: [], signIns: []),
      fingerprint: 'SHA256:held',
      database: null,
      entry: null,
      id: 'lost-1',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: IdentityDialog(model: model)),
      ),
    );
    await tester.pump();
    expect(find.text('Close'), findsOneWidget);
  });

  group('a pending change on the page', () {
    const row = {'id': _rowId, 'action': 'rotate', 'fingerprint': _waiting};

    testWidgets('Try again sends the row\'s ID and key', (tester) async {
      final core = await _openPending(tester, row);
      await _tapKey(tester, 'identity.tryAgain $_rowId');
      final call = core.rotations.single;
      expect(call[call.indexOf('--id') + 1], _rowId);
      expect(call[call.indexOf('--key') + 1], _waiting);
    });

    testWidgets('Use another key picks from the agent, confirms and sends a new ID', (tester) async {
      final core = await _openPending(tester, row);
      await _tapKey(tester, 'identity.useAnotherKey $_rowId');
      expect(core.rotations, isEmpty);
      await _tapKey(tester, 'identity-key $_other');
      expect(core.rotations, isEmpty);
      await _tapKey(tester, 'identity-rotation-confirm');
      final call = core.rotations.single;
      expect(call[call.indexOf('--key') + 1], _other);
      expect(call[call.indexOf('--id') + 1], isNot(_rowId));
    });

    testWidgets('an exists refusal leaves its words and neither offer', (tester) async {
      final core = await _openPending(tester, row);
      core.stands = true;
      await _tapKey(tester, 'identity.tryAgain $_rowId');
      expect(find.textContaining('its first card stands'), findsWidgets);
      expect(find.byKey(const Key('identity.tryAgain $_rowId')), findsNothing);
      expect(find.byKey(const Key('identity.useAnotherKey $_rowId')), findsNothing);
    });

    testWidgets('a row with no key offers no Try again and says why; Use another key stays', (tester) async {
      final core = await _openPending(tester, const {'id': _rowId, 'action': 'rotate', 'fingerprint': null});
      final button = tester.widget<TextButton>(find.byKey(const Key('identity.tryAgain $_rowId')));
      expect(button.onPressed, isNull);
      expect(find.textContaining('Core names no key'), findsOneWidget);
      expect(tester.widget<TextButton>(find.byKey(const Key('identity.useAnotherKey $_rowId'))).onPressed, isNotNull);
      expect(core.rotations, isEmpty);
    });
  });

  // Harm: a successor card signed by a revoked key is offered from the page.
  testWidgets('a revoked key offers no change of key', (tester) async {
    final calls = <List<String>>[];
    await _open(tester, (code: 0, out: jsonEncode(_shown(revoked: true)), err: ''), calls);
    final change = tester.widget<TextButton>(find.byKey(const Key('identity.changeKey')));
    expect(change.onPressed, isNull);
  });

  // Harm: a lost key or a backup key reachable beside its new place, or a verb Core has dropped still run.
  testWidgets('my key and card offers neither a lost key, a backup key nor a filing', (tester) async {
    final calls = <List<String>>[];
    await _open(tester, (code: 0, out: jsonEncode(_shown()), err: ''), calls);
    expect(find.byKey(const Key('identity.lostKey')), findsNothing);
    expect(find.byKey(const Key('identity.backupKey')), findsNothing);
    expect(find.text('File my card'), findsNothing);
    expect(calls, [
      ['identity', 'show', '--json'],
    ]);
  });

  // Harm: a person is shown a working card from an answer that names no organization.
  testWidgets('an answer without organization is refused in words', (tester) async {
    final calls = <List<String>>[];
    await _open(tester, (code: 0, out: jsonEncode(_shown()..remove('organization')), err: ''), calls);
    expect(find.textContaining('no organization'), findsOneWidget);
    expect(find.byKey(const Key('identity-fingerprint')), findsNothing);
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

    await tester.enterText(find.byKey(const Key('identity-login')), 'rowan-example');
    await tester.enterText(find.byKey(const Key('identity-name')), 'Rowan Example');
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
      'rowan-example',
      '--name',
      'Rowan Example',
      '--key',
      'SHA256:NewNewNew',
      '--json',
    ]);
    await tap('wizard-back');
    await tap('identity-wizard-make');
    expect(calls.where((call) => call[1] == 'create'), hasLength(1));
    expect(calls.last, ['identity', 'show', '--json']);
  });

  // Harm: a card made in KeePassXC while its terminal was put away said to have failed with exit -1, so the person
  // makes another key over a card that is there.
  testWidgets('a key made while its terminal closes is taken with its own exit code', (tester) async {
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
    }) async => switch (arguments[1]) {
      'show' when made => (code: 0, out: jsonEncode(_shown()), err: ''),
      _ => (code: 65, out: '{"reason":"no-identity","words":"no card is kept"}', err: ''),
    };
    final channel = _AnswersOnClose(0, jsonEncode({'login': 'rowan-example'}));
    final model = IdentityModel(Identity(run: run));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => FirstStartWizard(
                  model: model,
                  open: (executable, arguments, {columns = 80, rows = 24}) {
                    made = true;
                    return channel;
                  },
                ),
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
    await tester.enterText(find.byKey(const Key('identity-login')), 'rowan-example');
    await tester.enterText(find.byKey(const Key('identity-name')), 'Rowan Example');
    await World.settle(tester);
    await tap('wizard-next');
    await tap('identity-make-new');
    await tester.enterText(find.byKey(const Key('identity-database')), path.join('home', 'rowan', 'Passwords.kdbx'));
    await World.settle(tester);
    await tap('wizard-next');
    await tap('identity-wizard-make');
    await tap('unlock-cancel');
    await tap('unlock-cancel-yes');

    expect(model.problem, isNull, reason: 'the program ended with 0 while its terminal closed');
    expect(model.card?.login, 'rowan-example');
  });

  group('a first card and the forge', () {
    Future<void> openWizard(
      WidgetTester tester, {
      required Map<String, Object?> keys,
      required List<List<String>> calls,
      OpenTerminal? terminal,
    }) async {
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
        return switch (arguments[1]) {
          'keys' => (code: 0, out: jsonEncode(keys), err: ''),
          _ => (code: 65, out: '{"reason":"no-identity","words":"no card is kept"}', err: ''),
        };
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FirstStartWizard(
              model: IdentityModel(Identity(run: run)),
              open: terminal,
            ),
          ),
        ),
      );
      await World.settle(tester);
      await tester.enterText(find.byKey(const Key('identity-login')), 'rowan-example');
      await tester.enterText(find.byKey(const Key('identity-name')), 'Rowan Example');
      await World.settle(tester);
      await tester.tap(find.byKey(const Key('wizard-next')));
      await World.settle(tester);
    }

    Future<void> tap(WidgetTester tester, String key) async {
      await tester.tap(find.byKey(Key(key)));
      await World.settle(tester);
    }

    testWidgets('a new key is told before it is made that the first run makes no card', (tester) async {
      // Harm: a person types a master password for a card, and only the refusal tells them no first card can come of it.
      await openWizard(tester, keys: _keys, calls: []);
      expect(find.byKey(const Key('identity-new-key-first')), findsNothing);
      await tap(tester, 'identity-make-new');
      expect(find.byKey(const Key('identity-new-key-first')), findsOneWidget);
    });

    testWidgets('the refusal of a new key says the key is made and what comes next', (tester) async {
      // Harm: an expected refusal reads as a failure, the person makes a second key, and the first is left behind.
      await openWizard(
        tester,
        keys: _keys,
        calls: [],
        terminal: (executable, arguments, {columns = 80, rows = 24}) =>
            _AnswersOnClose(65, jsonEncode({'reason': 'not-allowed', 'words': 'the forge does not list this key'})),
      );
      await tap(tester, 'identity-make-new');
      await tester.enterText(find.byKey(const Key('identity-database')), path.join('home', 'rowan', 'Passwords.kdbx'));
      await World.settle(tester);
      await tap(tester, 'wizard-next');
      await tap(tester, 'identity-wizard-make');
      await tap(tester, 'unlock-cancel');
      await tap(tester, 'unlock-cancel-yes');
      expect(find.byKey(const Key('identity-new-key-next')), findsOneWidget);
    });

    testWidgets('an existing key the forge does not list stops before anything runs', (tester) async {
      // Harm: a card asked for with a key the forge will refuse, from a list that called it usable.
      final calls = <List<String>>[];
      await openWizard(
        tester,
        keys: {
          'keys': [
            {
              'fingerprint': 'SHA256:NewNewNew',
              'key': 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINew',
              'comment': 'laptop',
              'usable': true,
              'reason': null,
              'key_listed': false,
            },
          ],
        },
        calls: calls,
      );
      await tap(tester, 'identity-use-existing');
      await tap(tester, 'identity-key SHA256:NewNewNew');
      await tap(tester, 'wizard-next');
      expect(find.byKey(const Key('identity-wizard-make')), findsNothing);
      expect(calls.where((call) => call[1] == 'create'), isEmpty);
    });
  });

  testWidgets('picking a new key shows what changes and runs nothing before the confirmation', (tester) async {
    // Harm: a key change that rewrites the organization, projects and hosts from a single tap in a list.
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
    await tester.enterText(find.byKey(const Key('identity-database')), '/home/person/Passwords.kdbx');
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
    await tester.enterText(find.byKey(const Key('identity-login')), 'rowan-example');
    await tester.enterText(find.byKey(const Key('identity-name')), 'Rowan Example');
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
              'login': 'rowan-example',
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
    await tester.enterText(find.byKey(const Key('identity-login')), 'rowan-example');
    await tester.enterText(find.byKey(const Key('identity-name')), 'Rowan Example');
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
