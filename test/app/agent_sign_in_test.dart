import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/agent_sign_in.dart';
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

/// `checkout`, whose `payments-api` the machine says it does not carry, and whose `ledger` it does.
Project _withOneNotCarried() => Project.from(const <String, dynamic>{
  'name': 'checkout',
  'securityClass': 'guarded',
  'file': '/srv/checkout/project.yml',
  'repositories': <Map<String, dynamic>>[
    <String, dynamic>{'name': 'checkout', 'own': true},
    <String, dynamic>{'name': 'payments-api', 'agent': 'an-agent', 'carriedHere': false},
    <String, dynamic>{'name': 'ledger', 'agent': 'other-agent', 'carriedHere': true},
  ],
});

/// A machine whose sign-in start, once held, answers when the test says.
FakeBackend _holdingTheStart() => FakeBackend(const <Task>[])
  ..signsIn = true
  ..signInStartHeld = Completer<void>();

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
        ..signInOf['an-agent'] = const AgentSignIn(agent: 'an-agent', state: 'VAULT_LOCKED')
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
        ..signInOf['an-agent'] = const AgentSignIn(agent: 'an-agent', state: 'NOT_SIGNED_IN');
      final starting = await _opened(machine);
      starting.chooseAgent('an-agent');
      await pumpEventQueue();
      await starting.signIn.signIn();
      final askedBefore = machine.canStartAsked;
      final offeredWhenAsked = <int>[];
      starting.addListener(() {
        if (starting.ready) offeredWhenAsked.add(machine.canStartAsked);
      });

      machine.signInWait!.add(const SignInWaited(stored: true));
      unawaited(machine.signInWait!.close());
      await pumpEventQueue();

      expect(starting.ready, isTrue);
      expect(offeredWhenAsked, everyElement(greaterThan(askedBefore)));
    });
  });

  group('a sign-in on its own', () {
    test('a wait that ends with no answer is not taken for a sign-in that runs, nor for signed in', () async {
      // Harm: Sign in only reopens a sign-in that is gone, and no sign-in is ever started again.
      final machine = FakeBackend(const <Task>[])..signsIn = true;
      final signingIn = SigningIn();
      addTearDown(signingIn.dispose);
      signingIn.take(
        machine,
        const AgentSignIn(agent: 'an-agent', state: 'NOT_SIGNED_IN', running: 'porelo-login-an-agent'),
      );
      unawaited(machine.signInWait!.close());
      await pumpEventQueue();

      expect(signingIn.running, isFalse);
      expect(signingIn.holdsTheStart, isTrue);
      await signingIn.signIn();
      expect(machine.signInStarts.map((each) => each.agent), <String>['an-agent']);
    });

    test('a refusal that the machine holds a sign-in forces nothing until the second press', () async {
      // Harm: a sign-in is forced past the sign-in the machine holds, without the person deciding it.
      final machine = FakeBackend(const <Task>[])
        ..signsIn = true
        ..signInRefusedAs = 'ALREADY_SIGNED_IN';
      final signingIn = SigningIn();
      addTearDown(signingIn.dispose);
      signingIn.take(machine, const AgentSignIn(agent: 'an-agent', state: 'NOT_SIGNED_IN'));

      await signingIn.signIn();
      // Sign in pressed again is not the second decision: it is not offered while the machine holds one.
      await signingIn.signIn();

      expect(signingIn.alreadySignedIn, isTrue);
      expect(signingIn.whySignInCannot, isNotNull);
      expect(machine.signInStarts.map((each) => each.force), <bool?>[null]);
      await signingIn.signIn(force: true);
      expect(machine.signInStarts.last.force, isTrue);
    });

    test('a machine reached from elsewhere is told so at every sign-in start', () async {
      // Harm: the machine starts a sign-in whose reply comes back to itself, which no browser elsewhere reaches.
      final machine = FakeBackend(const <Task>[])..signsIn = true;
      final signingIn = SigningIn()..remote = true;
      addTearDown(signingIn.dispose);
      signingIn.take(machine, const AgentSignIn(agent: 'an-agent', state: 'NOT_SIGNED_IN'));

      await signingIn.signIn();

      expect(machine.signInStarts.single.remote, isTrue);
    });
  });

  group('the start of the agents', () {
    test('closing for good drops the wait on a sign-in that runs', () async {
      // Harm: a wizard gone keeps a wait open on the machine and is told of its end after it is gone.
      final machine = FakeBackend(const <Task>[])..signsIn = true;
      final starting = StartAgents();
      starting.signing.take(
        machine,
        const AgentSignIn(agent: 'an-agent', state: 'NOT_SIGNED_IN', running: 'porelo-login-an-agent'),
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
          const AgentSignIn(agent: 'an-agent', state: 'NOT_SIGNED_IN', running: 'porelo-login-an-agent'),
        );

      final now = _Unreadable();
      await starting.open(now, now.theProjectsItHas.first);

      expect(starting.signsIn, isNull);
      expect(starting.signing.agent, isNull);
      expect(before.signInWait!.hasListener, isFalse);
    });
  });

  group('an agent the machine cannot say of', () {
    // Harm: an agent whose own provider the machine cannot use is held for ever, though the start settles another
    // credential and the machine says work can start.
    test('starts where the machine says work can start, and offers no sign-in', () async {
      final machine = FakeBackend(const <Task>[])
        ..signsIn = true
        ..signInOf['an-agent'] = const AgentSignIn(agent: 'an-agent', state: 'CANNOT_SAY');
      final starting = await _opened(machine);
      starting.chooseAgent('an-agent');
      await pumpEventQueue();

      expect(starting.ready, isTrue);
      expect(starting.signIn.whySignInCannot, isNotNull);
    });

    test('starts nothing while the machine does not say work can start', () async {
      // Harm: the machine's silence on the start is read as leave to start.
      final machine = FakeBackend(const <Task>[])
        ..signsIn = true
        ..signInOf['an-agent'] = const AgentSignIn(agent: 'an-agent', state: 'CANNOT_SAY')
        ..canStartFails = 'the vault could not be read';
      final starting = await _opened(machine);
      starting.chooseAgent('an-agent');
      await pumpEventQueue();

      expect(starting.ready, isFalse);
    });

    test('is not put up for a sign-in by the start of the agents where the machine says each can start', () async {
      // Harm: the wizard holds every start on a sign-in the machine cannot make, though each row can start.
      final project = _withOneNotCarried();
      final machine = FakeBackend(const <Task>[])
        ..theProjectsItHas = <Project>[project]
        ..signsIn = true
        ..signInOf['other-agent'] = const AgentSignIn(agent: 'other-agent', state: 'CANNOT_SAY');
      final starting = StartAgents();
      addTearDown(starting.dispose);
      await starting.open(machine, project);
      await pumpEventQueue();

      expect(starting.agentsToSignIn, isEmpty);
      expect(starting.signInsHold, isFalse);
    });
  });

  group('a repository the machine does not carry', () {
    // Harm: work is started, or asked about, in a repository the machine says it does not carry.
    test('is never put up in the start of the agents, nor asked about', () async {
      final project = _withOneNotCarried();
      final machine = FakeBackend(const <Task>[])..theProjectsItHas = <Project>[project];
      final starting = StartAgents();
      addTearDown(starting.dispose);
      await starting.open(machine, project);
      await pumpEventQueue();

      final row = starting.rows.firstWhere((each) => each.repository == 'payments-api');
      expect(row.cannot, isNotNull);
      expect(row.toStart, isFalse);
      expect(machine.askedAboutRepositories, isNot(contains('payments-api')));
    });

    test('leaves nothing to start at one click where it is the only one naming an agent', () {
      final project = Project.from(const <String, dynamic>{
        'name': 'checkout',
        'securityClass': 'guarded',
        'file': '/srv/checkout/project.yml',
        'repositories': <Map<String, dynamic>>[
          <String, dynamic>{'name': 'checkout', 'own': true},
          <String, dynamic>{'name': 'payments-api', 'agent': 'an-agent', 'carriedHere': false},
          <String, dynamic>{'name': 'ledger', 'agent': '', 'carriedHere': true},
        ],
      });

      expect(StartAgents.whyNot(project), isNotNull);
    });

    test('is not offered by the start form', () async {
      final project = _withOneNotCarried();
      final machine = FakeBackend(const <Task>[])..theProjectsItHas = <Project>[project];
      final starting = StartWork();
      addTearDown(starting.dispose);
      await starting.open(machine, project);

      expect(starting.offeredRepositories, <String>['ledger']);
    });

    test('is not started in from a job that names it', () async {
      final project = _withOneNotCarried();
      final machine = FakeBackend(const <Task>[])..theProjectsItHas = <Project>[project];
      final starting = StartWork();
      addTearDown(starting.dispose);
      await starting.openFrom(
        machine,
        project,
        const Template(
          name: 'job',
          project: 'checkout',
          agent: 'an-agent',
          mode: Mode.agent,
          prompt: '',
          repository: 'payments-api',
        ),
      );
      starting.callIt('work');
      await pumpEventQueue();

      expect(starting.repository, isNot('payments-api'));
      expect(starting.ready, isFalse);
      expect(machine.askedAboutRepositories, isNot(contains('payments-api')));
    });

    test('is not started in by going on with a task there', () async {
      final project = _withOneNotCarried();
      final task = World.anAgentsTask('an-agent', 'payments-api', 'checkout', 'pay', running: false);
      final machine = FakeBackend(<Task>[task])..theProjectsItHas = <Project>[project];
      final starting = StartWork();
      addTearDown(starting.dispose);
      await starting.continueFrom(machine, project, task);
      starting.prompt = 'more';
      await pumpEventQueue();

      expect(starting.repository, isNot('payments-api'));
      expect(starting.ready, isFalse);
    });
  });

  group('a sign-in left while it is out', () {
    // Harm: a late answer opens a 31-minute wait on the machine and a terminal for a view nobody has open.
    test('left while its start is out, it opens no wait and no terminal', () async {
      final machine = _holdingTheStart();
      var attached = 0;
      final signingIn = SigningIn()..attachHere = (_) async => attached++;
      addTearDown(signingIn.dispose);
      signingIn.take(machine, const AgentSignIn(agent: 'an-agent', state: 'NOT_SIGNED_IN'));

      final started = signingIn.signIn();
      await pumpEventQueue();
      signingIn.leave();
      machine.signInStartHeld!.complete();
      await started;
      await pumpEventQueue();

      expect(machine.signInWaits, isEmpty);
      expect(attached, 0);
      expect(signingIn.starting, isFalse);
    });
  });

  group('a sign-in pressed again', () {
    // Harm: a second terminal is stacked on the one still open, attached to the same login.
    test('while its terminal is open opens no second one', () async {
      final machine = FakeBackend(const <Task>[])..signsIn = true;
      final open = Completer<void>();
      var attached = 0;
      final signingIn = SigningIn()
        ..attachHere = (_) {
          attached++;
          return open.future;
        };
      addTearDown(signingIn.dispose);
      signingIn.take(machine, const AgentSignIn(agent: 'an-agent', state: 'NOT_SIGNED_IN'));

      await signingIn.signIn();
      await signingIn.signIn();

      expect(attached, 1);
      open.complete();
    });

    // Harm: the wait stays on a login that is gone, and the one the machine named now is never waited on.
    test('waits on the login the machine names, not on one before', () async {
      final machine = FakeBackend(const <Task>[])..signsIn = true;
      final signingIn = SigningIn();
      addTearDown(signingIn.dispose);
      signingIn.take(machine, const AgentSignIn(agent: 'an-agent', state: 'NOT_SIGNED_IN', running: ''));
      final before = machine.signInWait;
      expect(machine.signInWaits, hasLength(1));

      await signingIn.signIn();

      expect(signingIn.container, 'porelo-login-an-agent');
      expect(machine.signInWaits, hasLength(2), reason: 'the login named now is waited on');
      expect(before!.hasListener, isFalse);
    });
  });

  group('asked again', () {
    // Harm: an agent once read signed in stays signed in here after the machine's vault was shut.
    test('asks again whether the agent is signed in, also after it read signed in', () async {
      final machine = FakeBackend(const <Task>[])
        ..signsIn = true
        ..signInOf['an-agent'] = const AgentSignIn(agent: 'an-agent', state: 'SIGNED_IN');
      final starting = await _opened(machine);
      starting.chooseAgent('an-agent');
      await pumpEventQueue();
      expect(starting.signIn.state, 'SIGNED_IN');

      machine.signInOf['an-agent'] = const AgentSignIn(agent: 'an-agent', state: 'VAULT_LOCKED');
      await starting.askAgain();
      await pumpEventQueue();

      expect(starting.signIn.state, 'VAULT_LOCKED');
      expect(starting.ready, isFalse);
    });
  });
}
