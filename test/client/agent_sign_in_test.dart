// Linux only: it stands the mock daemon on a unix socket, and on GitHub's Windows runner a test
// through it hung where no timeout could end it.
@Tags(<String>['linux'])
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/mock/mock_daemon.dart';

/// Whether an agent is signed in on a machine, its sign-in started as the machine's own login task, and waited on,
/// as a machine answers them and as one older than them answers.
void main() {
  late MockDaemon daemon;

  setUp(() async {
    daemon = MockDaemon();
    await daemon.start();
  });

  tearDown(() => daemon.stop());

  Future<PoreloClient> connect() => PoreloClient.connect(Backend(socketPath: daemon.socketPath, label: 'mock'));

  // Harm: a state this build does not know, or one missing, reads as signed in, and a start goes on without one.
  test('an unknown or missing state never reads as signed in', () async {
    final asked = <Map<String, dynamic>>[];
    daemon.method('AgentSignIns', (parameters) {
      asked.add(parameters);
      return <String, dynamic>{
        'signIns': <Map<String, dynamic>>[
          <String, dynamic>{'agent': 'claude', 'provider': 'anthropic', 'state': 'SIGNED_IN', 'since': '2026-11-08'},
          <String, dynamic>{'agent': 'codex', 'provider': 'openai', 'state': 'HALF_SIGNED_IN'},
          <String, dynamic>{'agent': 'pi', 'provider': 'anthropic'},
          <String, dynamic>{
            'agent': 'omp',
            'provider': 'anthropic',
            'state': 'SIGNING_IN',
            'signingInSince': '2026-11-08T20:00:00Z',
            'loginTask': 'porelo-login-omp',
          },
        ],
      };
    });

    final client = await connect();
    final all = await client.agentSignIns();
    final some = await client.agentSignIns(agents: <String>['claude']);

    expect(asked.first.containsKey('agents'), isFalse, reason: 'absent asks for every installed agent');
    expect(asked.last['agents'], <String>['claude']);
    expect(some, hasLength(4));
    expect(
      <String, bool>{for (final each in all) each.agent: each.signedIn},
      <String, bool>{'claude': true, 'codex': false, 'pi': false, 'omp': false},
    );
    expect(all[1].state, 'HALF_SIGNED_IN', reason: 'an unknown state is shown as it comes');
    expect(all[2].state, '', reason: 'a missing state is no state');
    expect(all[3].loginTask, 'porelo-login-omp');
    expect(all[3].signingInSince, '2026-11-08T20:00:00Z');
    expect(all[0].loginTask, isNull);
  });

  // Harm: a second login is opened beside a running one, or the running login's task is lost, so its terminal
  // cannot be opened.
  test('a sign-in start names its login task, and says whether it started one', () async {
    final asked = <Map<String, dynamic>>[];
    daemon.method('AgentSignInStart', (parameters) {
      asked.add(parameters);
      return <String, dynamic>{'task': 'porelo-login-claude', 'started': false};
    });

    final started = await (await connect()).agentSignInStart('claude');

    expect(asked.single, <String, dynamic>{'agent': 'claude'});
    expect(started.task, 'porelo-login-claude');
    expect(started.started, isFalse);
  });

  // Harm: a refusal reads as a generic failure, so the person is never told the vault is shut or the agent missing.
  test('each sign-in refusal is its own error, and an older machine has none of the methods', () async {
    daemon.fails('AgentSignInStart', 'org.fuin.porelo.Tasks1.CannotSignIn', <String, dynamic>{
      'agent': 'claude',
      'reason': 'the definition names no login',
    });
    final client = await connect();
    await expectLater(
      client.agentSignInStart('claude'),
      throwsA(isA<CannotSignIn>().having((e) => e.reason, 'reason', 'the definition names no login')),
    );
    daemon.fails('AgentSignInStart', 'org.fuin.porelo.Tasks1.NoSuchAgent', <String, dynamic>{'agent': 'claude'});
    await expectLater(
      client.agentSignInStart('claude'),
      throwsA(isA<NoSuchAgent>().having((e) => e.agent, 'agent', 'claude')),
    );
    daemon.fails('AgentSignIns', 'org.fuin.porelo.Tasks1.VaultShut');
    await expectLater(client.agentSignIns(), throwsA(isA<VaultShut>()));
    daemon.fails('AgentSignInWait', 'org.fuin.porelo.Tasks1.VaultShut');
    await expectLater(client.agentSignInWait('claude').toList(), throwsA(isA<VaultShut>()));

    daemon
      ..remove('AgentSignIns')
      ..remove('AgentSignInStart')
      ..remove('AgentSignInWait');
    await expectLater(client.agentSignIns(), throwsA(isA<FeatureNotSupported>()));
    await expectLater(client.agentSignInStart('claude'), throwsA(isA<FeatureNotSupported>()));
    await expectLater(client.agentSignInWait('claude').toList(), throwsA(isA<FeatureNotSupported>()));
  });

  // Harm: a wait that ends before its final reply reads as signed in.
  test('a wait ends only on its final reply, and a cut one is an error', () async {
    final replies = StreamController<Map<String, dynamic>>();
    final asked = <Map<String, dynamic>>[];
    daemon.stream('AgentSignInWait', (parameters) {
      asked.add(parameters);
      return replies.stream;
    });
    final client = await connect();
    final seen = <SignInWaited>[];
    final waited = Completer<Object?>();
    client.agentSignInWait('claude').listen(seen.add, onError: waited.complete, onDone: () => waited.complete(null));
    replies.add(<String, dynamic>{'state': 'SIGNING_IN'});
    replies.add(<String, dynamic>{'state': 'NOT_SIGNED_IN', 'detail': 'the sign-in was left'});
    await replies.close();
    expect(await waited.future, isNull);
    expect(asked.single, <String, dynamic>{'agent': 'claude'});
    expect(seen.last.state, 'NOT_SIGNED_IN');
    expect(seen.last.detail, 'the sign-in was left');
    expect(seen.last.signedIn, isFalse);

    daemon.hangUpOn.add('AgentSignInWait');
    await expectLater(client.agentSignInWait('claude').toList(), throwsA(isA<VarlinkDisconnected>()));
  });

  // Harm: a login task reads as ordinary work, or a task from an older machine fails to read.
  test('a login task says it is one, and a task from an older machine says no kind', () async {
    daemon.method(
      'List',
      (_) => <String, dynamic>{
        'tasks': <Map<String, dynamic>>[
          <String, dynamic>{'name': 'porelo-login-claude', 'agent': 'claude', 'kind': 'LOGIN', 'running': true},
          <String, dynamic>{'name': 'porelo-checkout-pi', 'agent': 'pi', 'running': true},
        ],
      },
    );

    final tasks = await (await connect()).tasks();

    expect(tasks.first.kind, 'LOGIN');
    expect(tasks.first.isASignIn, isTrue);
    expect(tasks.first.agent, 'claude');
    expect(tasks.last.kind, isNull);
    expect(tasks.last.isASignIn, isFalse);
  });
}
