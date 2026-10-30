import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/project_following.dart';
import 'package:porelo_frontend/src/ui/project_following_view.dart';

import '../features/support/world.dart';

class _Core extends FakeBackend {
  _Core() : super([]);

  Future<CredentialChecked> Function()? checkAnswer;
  Future<Followed> Function()? followAnswer;

  @override
  Future<CredentialChecked> credentialCheck(String url, {String? purpose}) =>
      checkAnswer?.call() ?? super.credentialCheck(url, purpose: purpose);

  @override
  Future<Followed> follow(
    String name,
    String url, {
    String? signedBy,
    List<String>? signers,
    bool? unverified,
    bool? acceptRewrite,
  }) =>
      followAnswer?.call() ??
      super.follow(
        name,
        url,
        signedBy: signedBy,
        signers: signers,
        unverified: unverified,
        acceptRewrite: acceptRewrite,
      );
}

void main() {
  late _Core core;
  late ProjectFollowing following;

  setUp(() {
    core = _Core();
    following = ProjectFollowing()
      ..startOn(core)
      ..name = 'demo'
      ..url = 'https://example.org/demo.git'
      ..checking = Checking.unverified;
  });
  tearDown(() => following.dispose());

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ProjectFollowingPanel(following: following, onFollow: following.follow, onDone: (_) {}),
      ),
    );
  }

  // Harm: a malformed Core answer silently leaves a follow neither confirmed nor refused.
  testWidgets('an empty credential-check answer ends in the existing refusal place', (tester) async {
    core.nextCheck = const CredentialChecked(outcome: '');
    await open(tester);
    await tester.tap(find.byKey(const Key('follow-it')));
    await World.settle(tester);
    expect(
      find.byKey(const Key('follow-problem')),
      findsOneWidget,
      reason: 'an empty Core answer must end with a visible refusal',
    );
    expect(core.follows, isEmpty);
    expect(find.byKey(const Key('follow-done')), findsNothing);
    expect(find.text('Following the project…'), findsNothing);
    expect(find.textContaining('no credential-check outcome'), findsOneWidget);
  });

  // Harm: an offline credential check prevents public HTTPS repositories from ever being followed.
  for (final outcome in ['NO_CREDENTIAL', 'VAULT_LOCKED']) {
    testWidgets('HTTPS is tried without a credential when the check says $outcome', (tester) async {
      core.nextCheck = CredentialChecked(outcome: outcome);
      await open(tester);
      await tester.tap(find.byKey(const Key('follow-it')));
      await World.settle(tester);
      expect(core.follows, hasLength(1), reason: 'the follow decides whether HTTPS needs a credential');
      expect(find.byKey(const Key('follow-done')), findsOneWidget);
    });
  }

  // Harm: an incomplete final answer can imply a follow succeeded without confirmation.
  testWidgets('an empty follow answer ends in the existing refusal place', (tester) async {
    core.nextFollow = const Followed(name: 'demo');
    await open(tester);
    await tester.tap(find.byKey(const Key('follow-it')));
    await World.settle(tester);
    expect(find.byKey(const Key('follow-problem')), findsOneWidget);
    expect(find.byKey(const Key('follow-done')), findsNothing);
    expect(find.text('Following the project…'), findsNothing);
    expect(find.textContaining('no follow outcome'), findsOneWidget);
  });

  // Harm: an exception leaves the stopped follow showing progress and no usable answer.
  for (final phase in ['check', 'follow']) {
    for (final failure in [const FormatException('bad reply'), StateError('bad reply'), TimeoutException('no reply')]) {
      testWidgets('a ${failure.runtimeType} from $phase replaces progress with a refusal', (tester) async {
        core.nextCheck = const CredentialChecked(outcome: 'NOT_NEEDED');
        if (phase == 'check') {
          core.checkAnswer = () async => throw failure;
        } else {
          core.followAnswer = () async => throw failure;
        }
        await open(tester);
        await tester.tap(find.byKey(const Key('follow-it')));
        await World.settle(tester);
        expect(tester.takeException(), isNull, reason: 'the call must end in the answer place');
        expect(following.busy, isFalse);
        expect(find.text('Following the project…'), findsNothing);
        expect(find.byKey(const Key('follow-problem')), findsOneWidget);
        expect(following.problem, contains('could not'));
        expect(find.byKey(const Key('follow-done')), findsNothing);
      });
    }
  }

  // Harm: copying a storage command without its required input stores an empty or unintended value.
  testWidgets('a credential that needs standard input names the entry and explains the pipe', (tester) async {
    core.nextCheck = const CredentialChecked(
      outcome: 'MISSING_VALUE',
      connection: Connection(id: 'git/example.org'),
      storeCommand: ['porelo', 'vault', 'put', 'git/example.org', '--stdin'],
      storeStdin: 'the private key file',
    );
    await open(tester);
    await tester.tap(find.byKey(const Key('follow-it')));
    await World.settle(tester);
    expect(find.textContaining('git/example.org'), findsOneWidget);
    expect(find.textContaining('piped in'), findsOneWidget);
    expect(find.textContaining('the private key file'), findsOneWidget);
    expect(find.textContaining('Add it on that machine with:'), findsNothing);
    expect(find.textContaining('porelo vault put'), findsNothing);
    expect(core.follows, isEmpty);
  });

  // Harm: a required credential cannot be supplied when its entry and storage command are hidden.
  testWidgets('a credential refusal names the entry and remedy supplied by Core', (tester) async {
    following.url = 'git@example.org:demo.git';
    core.nextCheck = const CredentialChecked(
      outcome: 'MISSING_VALUE',
      connection: Connection(id: 'git/example.org'),
      storeCommand: ['porelo', 'vault', 'put', 'git/example.org'],
    );
    await open(tester);
    await tester.tap(find.byKey(const Key('follow-it')));
    await World.settle(tester);
    expect(find.textContaining('git/example.org'), findsOneWidget);
    expect(find.textContaining('porelo vault put git/example.org'), findsOneWidget);
    expect(core.follows, isEmpty);
  });

  // Harm: copying an unquoted remedy changes its arguments or runs shell syntax from an entry name.
  test(
    'the displayed storage command preserves Core’s arguments when copied into a shell',
    () async {
      const entry = 'git/example.org; printf injected';
      following.url = 'git@example.org:demo.git';
      core.nextCheck = const CredentialChecked(
        outcome: 'MISSING_VALUE',
        connection: Connection(id: entry),
        storeCommand: ['/usr/bin/python3', '-I', '-c', 'import json, sys; print(json.dumps(sys.argv[1:]))', entry],
      );
      await following.follow();
      final text = following.checkWords;
      final command = text.substring(text.indexOf('/usr/bin/python3'));
      final result = await Process.run('/bin/bash', [
        '--noprofile',
        '--norc',
        '-c',
        command,
      ], includeParentEnvironment: false);
      expect(result.exitCode, 0, reason: 'the displayed command must preserve the original arguments');
      expect(jsonDecode(result.stdout as String), [entry]);
    },
    // Linux: executes the displayed command with bash and a Python argv observer.
    tags: ['linux'],
  );

  // Harm: a private HTTPS repository's refusal leaves no way to supply its missing credential.
  testWidgets('an HTTPS follow refusal carries Core’s entry and remedy in the existing answer', (tester) async {
    core.nextCheck = const CredentialChecked(outcome: 'NO_CREDENTIAL');
    core.nextFollow = const Followed(
      name: 'demo',
      outcome: 'NO_CREDENTIAL',
      detail: 'The repository requires a credential.',
      storeCommand: 'porelo vault put git/example.org --type token',
    );
    await open(tester);
    await tester.tap(find.byKey(const Key('follow-it')));
    await World.settle(tester);
    expect(find.textContaining('git/example.org'), findsOneWidget);
    expect(find.textContaining(core.nextFollow!.storeCommand), findsOneWidget);
    expect(find.byKey(const Key('follow-done')), findsNothing);
    expect(core.follows, hasLength(1));
  });

  // Harm: retrying anonymously despite a declared credential hides a refusal that needs a person.
  testWidgets('HTTPS keeps a declared credential’s locked-vault refusal', (tester) async {
    core.nextCheck = const CredentialChecked(
      outcome: 'VAULT_LOCKED',
      connection: Connection(id: 'git/example.org', source: 'VAULT'),
    );
    await open(tester);
    await tester.tap(find.byKey(const Key('follow-it')));
    await World.settle(tester);
    expect(find.byKey(const Key('follow-check-says')), findsOneWidget);
    expect(core.follows, isEmpty);
  });

  // Harm: a person cannot tell whether the click started a call and may repeat it.
  testWidgets('a pending follow says it is running in the existing answer place', (tester) async {
    final reply = Completer<CredentialChecked>();
    core.checkAnswer = () => reply.future;
    await open(tester);
    await tester.tap(find.byKey(const Key('follow-it')));
    await tester.pump();
    expect(find.byKey(const Key('follow-problem')), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('follow-it'))).onPressed, isNull);
    reply.complete(const CredentialChecked(outcome: 'NOT_NEEDED'));
    await World.settle(tester);
    expect(find.byKey(const Key('follow-done')), findsOneWidget);
    expect(find.byKey(const Key('follow-problem')), findsNothing);
  });
}
