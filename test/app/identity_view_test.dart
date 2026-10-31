import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/identity.dart';
import 'package:porelo_frontend/src/app/run_here.dart';
import 'package:porelo_frontend/src/ui/identity_view.dart';

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

void main() {
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
