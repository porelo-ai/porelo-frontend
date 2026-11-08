import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/agent_sign_in.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/session.dart';
import 'package:porelo_frontend/src/app/start_agents.dart';
import 'package:porelo_frontend/src/app/start_work.dart';
import 'package:porelo_frontend/src/app/templates.dart';

import '../features/support/world.dart';

/// A machine older than `CanStart` and older than sign-ins of its own.
class _Older extends FakeBackend {
  _Older() : super(const <Task>[]);

  @override
  Future<Readiness> canStart({
    String? project,
    String? agent,
    String? task,
    String? repository,
    Map<String, String>? credentials,
  }) async => throw const FeatureNotSupported('CanStart');
}

/// A machine that cannot say which agents it has.
class _Unreadable extends FakeBackend {
  _Unreadable() : super(const <Task>[]);

  @override
  Future<AgentsOnTheMachine> agentsOn() async => throw const VarlinkDisconnected('gone');
}

const _credentialMissing = Readiness(
  ready: false,
  outcome: StartOutcome.credentialMissing,
  agent: 'an-agent',
  provider: 'a-provider',
  credential: 'a-provider',
  detail: "the vault holds no credential for 'a-provider'",
  agentSource: 'ONLY_ONE',
);

Future<StartWork> _opened(FakeBackend machine) async {
  final starting = StartWork();
  addTearDown(starting.dispose);
  await starting.open(machine, machine.theProjectsItHas.first);
  starting
    ..mode = Mode.agent
    ..callIt('work');
  return starting;
}

void main() {
  group('a single start', () {
    test('an agent listed signed in starts nothing while the machine says its credential is missing', () async {
      // Harm: Start is offered and sent where the machine's own answer for a start says the sign-in is missing.
      final machine = FakeBackend(const <Task>[])
        ..signsIn = true
        ..signInOf['an-agent'] = const AgentSignIn(agent: 'an-agent', provider: 'a-provider', state: 'VAULT_SHUT')
        ..nextReadiness = _credentialMissing;
      final starting = await _opened(machine);
      await pumpEventQueue();
      expect(starting.ready, isFalse);

      // The vault opened: asked again, the sign-in reads signed in and the machine still says the credential is missing.
      machine.signInOf.remove('an-agent');
      await starting.askAgain();
      await pumpEventQueue();

      expect(starting.agentToRun, 'an-agent');
      expect(starting.signIn.state, 'SIGNED_IN');
      expect(starting.ready, isFalse);
    });

    test('a machine that fails to say whether work can start starts nothing, signed in or not', () async {
      // Harm: a start sent where the machine could not say it can start, only because the sign-in reads fine.
      final machine = FakeBackend(const <Task>[])
        ..signsIn = true
        ..canStartFails = 'the vault could not be read';
      final starting = await _opened(machine);
      starting.chooseAgent('an-agent');
      await pumpEventQueue();

      expect(starting.signIn.state, 'SIGNED_IN');
      expect(starting.ready, isFalse);
    });

    test('an answer that work can start is not kept once asking again failed', () async {
      // Harm: an earlier ready answer starts work the machine has since failed to say can start.
      final machine = FakeBackend(const <Task>[])..signsIn = true;
      final starting = await _opened(machine);
      starting.chooseAgent('an-agent');
      await pumpEventQueue();
      expect(starting.ready, isTrue);

      machine.canStartFails = 'the vault could not be read';
      await starting.askAgain();

      expect(starting.ready, isFalse);
    });

    test('a job opened on a machine older than CanStart and its sign-ins can still start', () async {
      // Harm: on an older machine the form waits forever on a sign-in it never asked about.
      final machine = _Older();
      final starting = StartWork();
      addTearDown(starting.dispose);
      await starting.openFrom(
        machine,
        machine.theProjectsItHas.first,
        const Template(
          name: 'job',
          project: 'checkout',
          agent: 'an-agent',
          mode: Mode.agent,
          prompt: '',
          repository: '',
        ),
      );
      starting.callIt('work');
      await pumpEventQueue();

      expect(starting.signIn.served, isFalse);
      expect(starting.ready, isTrue);
    });

    test('a sign-in that ends signed in offers no start before the machine was asked again', () async {
      // Harm: for a moment Start is offered on the sign-in alone, before the machine said work can start.
      final machine = FakeBackend(const <Task>[])
        ..signsIn = true
        ..signInOf['an-agent'] = const AgentSignIn(agent: 'an-agent', provider: 'a-provider', state: 'NOT_SIGNED_IN');
      final starting = await _opened(machine);
      starting.chooseAgent('an-agent');
      await pumpEventQueue();
      await starting.signIn.signIn();
      final askedBefore = machine.canStartAsked;
      final offeredWhenAsked = <int>[];
      starting.addListener(() {
        if (starting.ready) offeredWhenAsked.add(machine.canStartAsked);
      });

      machine.signInWait!.add(const SignInWaited(state: 'SIGNED_IN'));
      unawaited(machine.signInWait!.close());
      await pumpEventQueue();

      expect(starting.ready, isTrue);
      expect(offeredWhenAsked, everyElement(greaterThan(askedBefore)));
    });
  });

  group('a sign-in on its own', () {
    test('a wait that ends with no final reply is not taken for a sign-in that runs', () async {
      // Harm: Sign in only reopens a login task that is gone, and no sign-in is ever started again.
      final machine = FakeBackend(const <Task>[])..signsIn = true;
      final signingIn = SigningIn();
      addTearDown(signingIn.dispose);
      signingIn.take(
        machine,
        const AgentSignIn(
          agent: 'an-agent',
          provider: 'a-provider',
          state: 'SIGNING_IN',
          loginTask: 'porelo-login-an-agent',
        ),
      );
      machine.signInWait!.add(const SignInWaited(state: 'SIGNING_IN'));
      unawaited(machine.signInWait!.close());
      await pumpEventQueue();

      expect(signingIn.running, isFalse);
      await signingIn.signIn();
      expect(machine.signInStarts, <String>['an-agent']);
    });
  });

  group('the start of the agents', () {
    test('closing for good drops the wait on a sign-in that runs', () async {
      // Harm: a wizard gone keeps a wait open on the machine and is told of its end after it is gone.
      final machine = FakeBackend(const <Task>[])..signsIn = true;
      final starting = StartAgents();
      starting.signing.take(
        machine,
        const AgentSignIn(
          agent: 'an-agent',
          provider: 'a-provider',
          state: 'SIGNING_IN',
          loginTask: 'porelo-login-an-agent',
        ),
      );
      expect(machine.signInWait!.hasListener, isTrue);

      starting.dispose();
      await pumpEventQueue();

      expect(machine.signInWait!.hasListener, isFalse);
    });

    test('opened again, it holds nothing of the sign-ins of the opening before', () async {
      // Harm: a wizard opened on another machine offers and waits on a sign-in of the machine it was opened on before.
      final before = FakeBackend(const <Task>[])..signsIn = true;
      final starting = StartAgents();
      addTearDown(starting.dispose);
      starting
        ..signsIn = true
        ..signing.take(
          before,
          const AgentSignIn(
            agent: 'an-agent',
            provider: 'a-provider',
            state: 'SIGNING_IN',
            loginTask: 'porelo-login-an-agent',
          ),
        );

      final now = _Unreadable();
      await starting.open(now, now.theProjectsItHas.first);

      expect(starting.signsIn, isNull);
      expect(starting.signing.agent, isNull);
      expect(before.signInWait!.hasListener, isFalse);
    });
  });

  group('the terminal of a login task', () {
    test('a window shut while it is open closes it too', () async {
      // Harm: the terminal of a login task keeps its program and its handles after the window is gone.
      FakeTerminal? far;
      final sessions = Sessions(
        openTerminal: (executable, arguments, {columns = 80, rows = 24}) =>
            far = FakeTerminal(<String>[executable, ...arguments]),
      );
      addTearDown(sessions.dispose);
      sessions.openBeside('porelo-login-an-agent', const Machine(name: 'local', socketPath: '/run/porelo.sock'));
      expect(far, isNotNull);

      await sessions.leaveAll();

      expect(far!.closed, isTrue);
      expect(sessions.beside, isEmpty);
    });
  });
}
