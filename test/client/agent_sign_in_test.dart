// Linux only: it stands the mock daemon on a unix socket, and on GitHub's Windows runner a test
// through it hung where no timeout could end it.
@Tags(<String>['linux'])
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/mock/mock_daemon.dart';

/// Whether each agent is signed in on a machine, its own login started there and waited on, as a machine answers
/// them and as one older than them answers.
void main() {
  late MockDaemon daemon;

  setUp(() async {
    daemon = MockDaemon();
    await daemon.start();
  });

  tearDown(() => daemon.stop());

  Future<PoreloClient> connect({Duration answerWithin = VarlinkConnection.answerWithin}) => PoreloClient.connect(
    Backend(socketPath: daemon.socketPath, label: 'mock'),
    answerWithin: answerWithin,
  );

  // Harm: a shut vault, a state the machine cannot say, or one this build does not know reads as signed in.
  test('only SIGNED_IN reads as signed in, and a sign-in that runs is named by its container', () async {
    final asked = <Map<String, dynamic>>[];
    daemon.method('AgentSignIns', (parameters) {
      asked.add(parameters);
      return <String, dynamic>{
        'signIns': <Map<String, dynamic>>[
          <String, dynamic>{'agent': 'claude', 'state': 'SIGNED_IN'},
          <String, dynamic>{'agent': 'codex', 'state': 'VAULT_LOCKED'},
          <String, dynamic>{'agent': 'pi', 'state': 'CANNOT_SAY'},
          <String, dynamic>{'agent': 'omp', 'state': 'HALF_SIGNED_IN', 'running': 'porelo-login-omp'},
          <String, dynamic>{'agent': 'goose', 'running': ''},
        ],
      };
    });

    final all = await (await connect()).agentSignIns();

    expect(asked.single, isEmpty, reason: 'one call for every agent, naming none');
    expect(
      <String, bool>{for (final each in all) each.agent: each.signedIn},
      <String, bool>{'claude': true, 'codex': false, 'pi': false, 'omp': false, 'goose': false},
    );
    expect(all[3].state, 'HALF_SIGNED_IN', reason: 'an unknown state is shown as it comes');
    expect(all[3].running, 'porelo-login-omp');
    expect(all[4].running, '', reason: 'being prepared is not none running');
    expect(all[0].running, isNull);
  });

  // Harm: the machine is not told the person reaches it from elsewhere, or a forced sign-in is asked for unasked,
  // or what to attach with is lost.
  test('a sign-in start sends force and remote only where given, and names what attaches to it', () async {
    final asked = <Map<String, dynamic>>[];
    daemon.method('AgentSignInStart', (parameters) {
      asked.add(parameters);
      return <String, dynamic>{
        'container': 'porelo-login-claude',
        'started': false,
        'attach': <String>['podman', 'attach', 'porelo-login-claude'],
      };
    });
    final client = await connect();

    final started = await client.agentSignInStart('claude');
    await client.agentSignInStart('claude', remote: true, force: true);

    expect(asked.first, <String, dynamic>{'agent': 'claude'});
    expect(asked.last, <String, dynamic>{'agent': 'claude', 'force': true, 'remote': true});
    expect(started.container, 'porelo-login-claude');
    expect(started.started, isFalse);
    expect(started.attach, <String>['podman', 'attach', 'porelo-login-claude']);
  });

  // Harm: a refusal reads as a generic failure, so the person is never told why, or offered the import first.
  test('a refused sign-in is its own error with its reason and words, and an older machine has none', () async {
    daemon.fails('AgentSignInStart', 'org.fuin.porelo.Tasks1.SignInRefused', <String, dynamic>{
      'agent': 'claude',
      'reason': 'ALREADY_SIGNED_IN',
      'detail': 'the agent directory holds a sign-in',
    });
    final client = await connect();
    await expectLater(
      client.agentSignInStart('claude'),
      throwsA(
        isA<SignInRefused>()
            .having((e) => e.reason, 'reason', 'ALREADY_SIGNED_IN')
            .having((e) => e.detail, 'detail', 'the agent directory holds a sign-in'),
      ),
    );

    daemon
      ..remove('AgentSignIns')
      ..remove('AgentSignInStart')
      ..remove('AgentSignInWait');
    await expectLater(client.agentSignIns(), throwsA(isA<FeatureNotSupported>()));
    await expectLater(client.agentSignInStart('claude'), throwsA(isA<FeatureNotSupported>()));
    await expectLater(client.agentSignInWait('claude').toList(), throwsA(isA<FeatureNotSupported>()));
  });

  // Harm: a wait not stored reads as signed in, or a cut one as a quiet end.
  test('a wait answers once, stored or with its reason, and a cut one is an error', () async {
    final asked = <Map<String, dynamic>>[];
    daemon.method('AgentSignInWait', (parameters) {
      asked.add(parameters);
      return <String, dynamic>{'stored': false, 'reason': 'NOTHING_TO_COLLECT'};
    });
    final client = await connect();

    final waited = await client.agentSignInWait('claude').toList();

    expect(asked.single, <String, dynamic>{'agent': 'claude'});
    expect(waited.single.stored, isFalse);
    expect(waited.single.reason, 'NOTHING_TO_COLLECT');

    daemon.hangUpOn.add('AgentSignInWait');
    await expectLater(client.agentSignInWait('claude').toList(), throwsA(isA<VarlinkDisconnected>()));
  });

  // Harm: the single call's deadline cuts a wait the machine answers only once the sign-in ended, minutes later.
  test('a wait is not cut by the deadline of a single call', () async {
    final answer = Completer<Map<String, dynamic>>();
    daemon.method('AgentSignInWait', (_) => answer.future);
    const deadline = Duration(milliseconds: 200);
    final client = await connect(answerWithin: deadline);

    final waited = client.agentSignInWait('claude').toList();
    // Past the deadline of a single call before the machine answers.
    await Future<void>.delayed(deadline * 3);
    answer.complete(<String, dynamic>{'stored': true, 'reason': ''});

    expect((await waited).single.stored, isTrue);
  });

  // Harm: a wait of up to 30 minutes holds the machine's connection, so nothing else is answered meanwhile, or its
  // connection outlives the wait that was left.
  test('a wait has a connection of its own, and leaving it closes that connection', () async {
    final answer = Completer<Map<String, dynamic>>();
    final asked = Completer<void>();
    daemon
      ..method('AgentSignInWait', (_) {
        asked.complete();
        return answer.future;
      })
      ..method('List', (_) => <String, dynamic>{'tasks': <Map<String, dynamic>>[]});
    final client = await connect();
    // The connection that agreed the interface is gone once the mock has seen it close.
    await pumpEventQueue();
    final before = daemon.openConnections;

    final waiting = client.agentSignInWait('claude').listen((_) {}, onError: (Object _) {});
    await asked.future;
    expect(daemon.openConnections, before + 1, reason: 'the wait holds one connection');

    expect(await client.tasks(), isEmpty, reason: 'answered while the wait is out');

    await waiting.cancel();
    await pumpEventQueue();
    expect(daemon.openConnections, before, reason: 'left, the wait closed its connection');
    answer.complete(<String, dynamic>{'stored': true, 'reason': ''});
  });
}
