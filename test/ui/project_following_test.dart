import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/project_following.dart';
import 'package:porelo_frontend/src/ui/project_following_view.dart';

import '../features/support/world.dart';
import '../support/host_admin.dart' show personKey;

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
      ..adminSigners = [personKey];
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

  // Harm: an old rewritten-history answer must not authorize accepting a different repository.
  test('a late follow answer cannot offer rewrite acceptance for edited input', () async {
    final answer = Completer<Followed>();
    core.followAnswer = () => answer.future;
    final draft = ProjectFollowing(resolveAdminSigners: (_, _) async => [personKey])
      ..startOn(core)
      ..name = 'demo'
      ..url = 'https://example.org/demo.git';
    addTearDown(draft.dispose);
    await draft.verifySigners();
    final attempt = draft.follow();
    await pumpEventQueue();
    expect(core.follows, isEmpty);
    draft.answerWith(() => draft.url = 'https://example.org/other.git');
    answer.complete(const Followed(name: 'demo', outcome: 'REWRITTEN'));
    await attempt;
    await draft.verifySigners();
    expect(draft.ready, isTrue);
    expect(draft.rewritten, isFalse, reason: 'the old URL cannot authorize a rewrite on the new URL');
    expect(draft.answer, isNull);
  });

  // Harm: edits during a credential check must never send an unverified follow for another URL.
  testWidgets('editing while credentials are checked cancels the pending follow', (tester) async {
    final checked = Completer<CredentialChecked>();
    core.checkAnswer = () => checked.future;
    await open(tester);
    await tester.tap(find.byKey(const Key('follow-it')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('follow-url')), 'https://example.org/other.git');
    checked.complete(const CredentialChecked(outcome: 'NOT_NEEDED'));
    await World.settle(tester);
    expect(core.follows, isEmpty, reason: 'the old signer set cannot authorize the new repository');
  });

  // Harm: verified following must resume after edits and must reject missing or stale signers.
  testWidgets('Core verifies the edited project and its keys reach the follow', (tester) async {
    following.dispose();
    final requested = <(String, String)>[];
    following = ProjectFollowing(
      resolveAdminSigners: (name, url) async {
        requested.add((name, url));
        return [personKey];
      },
    )..startOn(core);
    await open(tester);
    await tester.enterText(find.byKey(const Key('follow-name')), 'other');
    await tester.enterText(find.byKey(const Key('follow-url')), 'https://example.org/other.git');
    await tester.pump();
    await tester.tap(find.byKey(const Key('follow-verify-signers')));
    await World.settle(tester);
    expect(requested, [('other', 'https://example.org/other.git')]);
    await tester.tap(find.byKey(const Key('follow-it')));
    await World.settle(tester);
    expect(core.follows.single.signers, [personKey]);
    expect(core.follows.single.signedBy, isNull);
    expect(core.follows.single.unverified, isFalse);
  });

  for (final keys in [
    <String>[],
    ['invalid'],
  ]) {
    test('Core missing or malformed signers leave following disabled: $keys', () async {
      final draft = ProjectFollowing(resolveAdminSigners: (_, _) async => keys)
        ..startOn(core)
        ..name = 'demo'
        ..url = 'https://example.org/demo.git';
      addTearDown(draft.dispose);
      await draft.verifySigners();
      await draft.follow();
      expect(draft.ready, isFalse);
      expect(draft.problem, isNotNull);
      expect(core.follows, isEmpty);
    });
  }

  test('a late Core signer answer cannot authorize edited input', () async {
    final keys = Completer<List<String>>();
    final draft = ProjectFollowing(resolveAdminSigners: (_, _) => keys.future)
      ..startOn(core)
      ..name = 'demo'
      ..url = 'https://example.org/demo.git';
    addTearDown(draft.dispose);
    final verifying = draft.verifySigners();
    draft.answerWith(() => draft.url = 'https://example.org/other.git');
    keys.complete([personKey]);
    await verifying;
    expect(draft.ready, isFalse);
    await draft.follow();
    expect(core.follows, isEmpty);
  });

  // Harm: editing a project must offer verified signer resolution instead of stranding following.
  testWidgets('editing the repository offers Core signer verification before following', (tester) async {
    await open(tester);
    await tester.enterText(find.byKey(const Key('follow-url')), 'https://example.org/other.git');
    await World.settle(tester);
    expect(core.follows, isEmpty);
    expect(find.byKey(const Key('follow-verify-signers')), findsOneWidget);
  });

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
