import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/start_work.dart';
import 'package:porelo_frontend/src/app/templates.dart';

import '../features/support/world.dart';

/// A machine older than `CanStart`, which answers nothing about readiness.
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

/// A machine that never met github.com until a key of it is trusted, as Porelo answers from run 279.
class _NeverMetGitHub extends FakeBackend {
  _NeverMetGitHub() : super(const <Task>[]) {
    hostsOffer['github.com'] = const <HostKey>[
      HostKey(type: 'ssh-ed25519', fingerprint: 'SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU'),
      HostKey(type: 'ssh-rsa', fingerprint: 'SHA256:uNiVztksCsDhcc0u9e8BujQXVUpKZIDTMczCvj3tD2s'),
    ];
  }

  @override
  Future<Readiness> canStart({
    String? project,
    String? agent,
    String? task,
    String? repository,
    Map<String, String>? credentials,
  }) async => trustedHostKeys.containsKey('github.com')
      ? const Readiness(
          ready: true,
          outcome: StartOutcome('READY'),
          agent: '',
          provider: '',
          credential: '',
          detail: '',
        )
      : Readiness(
          ready: false,
          outcome: const StartOutcome('UNKNOWN_HOST_KEY'),
          agent: '',
          provider: '',
          credential: '',
          detail: 'this machine has never met github.com',
          host: 'github.com',
          hostKeys: hostsOffer['github.com']!,
        );
}

void main() {
  test('a host the machine never met is trusted by the key the forge publishes, and asked about again', () async {
    final machine = _NeverMetGitHub();
    final starting = StartWork()
      ..publishedHostKeys = () async => <String>['SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU'];
    addTearDown(starting.dispose);
    await starting.open(machine, machine.theProjectsItHas.first);
    expect(starting.readiness?.outcome.name, 'UNKNOWN_HOST_KEY');
    expect(starting.readiness?.whatToDo, contains('never met github.com'));
    expect(starting.publishedOffer?.fingerprint, 'SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU');

    await starting.trustThePublishedKey();

    expect(machine.trustedHostKeys, <String, List<String>>{
      'github.com': <String>['SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU'],
    });
    expect(starting.readiness?.ready, isTrue);
  });

  test('a host whose keys the forge does not publish offers nothing to trust from here', () async {
    final machine = _NeverMetGitHub();
    final starting = StartWork()..publishedHostKeys = () async => <String>['SHA256:somethingelse'];
    addTearDown(starting.dispose);
    await starting.open(machine, machine.theProjectsItHas.first);
    expect(starting.publishedOffer, isNull);
  });

  test("opening on another project never keeps the last project's answer", () async {
    // An older machine answers nothing; the answer left from before disabled Start for the wrong project.
    final first = FakeBackend(const <Task>[])
      ..nextReadiness = const Readiness(
        ready: false,
        outcome: StartOutcome.unknownProvider,
        agent: '',
        provider: '',
        credential: '',
        detail: 'the first project names a provider this machine lacks',
      );
    final second = _Older();
    final starting = StartWork();
    addTearDown(starting.dispose);

    await starting.open(first, first.theProjectsItHas.first);
    expect(starting.readiness, isNotNull);
    await starting.open(second, second.theProjectsItHas.first);

    expect(starting.readiness, isNull);
  });

  test('a shell is not started either while the agent has nothing to sign in with', () async {
    // Wherever the form is shown, a shell is the one start Porelo lets through without a credential.
    final machine = FakeBackend(const <Task>[])
      ..nextReadiness = const Readiness(
        ready: false,
        outcome: StartOutcome.credentialMissing,
        agent: 'an-agent',
        provider: 'a-provider',
        credential: 'a-provider',
        detail: "the vault holds no credential for 'a-provider'",
      );
    machine.theAgentsItHas = <Agent>[
      Agent.from(const <String, dynamic>{'name': 'an-agent', 'label': 'An Agent', 'canLogIn': true}),
    ];
    expect(machine.theAgentsItHas.single.canLogIn, isTrue, reason: 'the fixture declares a login');
    final starting = StartWork();
    addTearDown(starting.dispose);

    await starting.open(machine, machine.theProjectsItHas.first);
    starting
      ..chooseAgent('an-agent')
      ..chooseMode(Mode.shell);
    await starting.askAgain();

    expect(starting.needsASignIn, isTrue);
    expect(starting.ready, isFalse);
  });

  test("a suggested name never reuses one of the project's tasks, and is one a task can have", () async {
    final machine = FakeBackend(<Task>[
      // As a machine lists them: the container's name, and the name a person gave it as `task`.
      Task.from(const <String, dynamic>{
        'name': 'porelo-checkout-payments-api',
        'task': 'payments-api',
        'project': 'checkout',
      }),
      Task.from(const <String, dynamic>{
        'name': 'porelo-checkout-payments-api-2',
        'task': 'payments-api-2',
        'project': 'checkout',
      }),
      Task.from(const <String, dynamic>{'name': 'porelo-another-github', 'task': 'github', 'project': 'another'}),
    ]);
    final project = Project.from(const <String, dynamic>{
      'name': 'checkout',
      'file': '/home/me/checkout/project.yml',
      'repositories': <String>['.github', 'payments-api'],
    });
    machine.theProjectsItHas = <Project>[project];
    final starting = StartWork();
    addTearDown(starting.dispose);
    await starting.open(machine, project);

    starting.chooseRepository('.github');
    expect(starting.name, 'github', reason: "another project's task does not count");
    expect(starting.nameProblem, isNull);

    starting.chooseRepository('payments-api');
    expect(starting.name, 'payments-api-3');
  });

  group('the agent the machine found', () {
    Future<StartWork> opened(FakeBackend machine) async {
      final starting = StartWork();
      addTearDown(starting.dispose);
      await starting.open(machine, machine.theProjectsItHas.first);
      return starting;
    }

    const found = Readiness(
      ready: true,
      outcome: StartOutcome.ready,
      agent: 'codex',
      provider: 'openai',
      credential: 'openai',
      detail: '',
      agentSource: 'SIGNED_IN',
      agentFoundIn: '/home/person/.codex/auth.json',
    );

    _Asked machineWith(Readiness answer, {List<Map<String, dynamic>> agents = const <Map<String, dynamic>>[]}) =>
        _Asked(
          agents.isEmpty
              ? <Map<String, dynamic>>[
                  <String, dynamic>{'name': 'claude'},
                  <String, dynamic>{'name': 'codex'},
                ]
              : agents,
        )..nextReadiness = answer;

    test('nothing is filled in, and the form asks and starts with no agent', () async {
      // Harm: a person signed in to one agent gets Claude Code anyway, because the form named it first.
      final machine = machineWith(found);
      final starting = await opened(machine);
      starting
        ..mode = Mode.agent
        ..callIt('work');
      await starting.askAgain();

      expect(starting.agent, isNull);
      expect(machine.askedFor.toSet(), <String?>{null});
      expect(starting.ready, isTrue, reason: 'the machine chose');
      expect(starting.agentToRun, 'codex');
      unawaited(starting.begin(machine).listen((_) {}).asFuture<void>());
      await pumpEventQueue();
      expect(machine.starts.single.agent, isNull, reason: 'the start chooses as the question did');
    });

    test('an older machine names an agent with no source, and the person must pick one', () async {
      // Harm: a guess at an agent the machine never said it chose, started as if it had.
      final starting = await opened(
        machineWith(
          const Readiness(
            ready: true,
            outcome: StartOutcome.ready,
            agent: 'codex',
            provider: '',
            credential: '',
            detail: '',
          ),
        ),
      );
      starting
        ..mode = Mode.agent
        ..callIt('work');

      expect(starting.ready, isFalse);
      starting.chooseAgent('codex');
      expect(starting.ready, isFalse, reason: 'nothing starts before the machine has answered about the pick');
      await starting.askAgain();
      expect(starting.ready, isTrue);
    });

    test('several agents leave the choice to the person, the ones signed in first', () async {
      // Harm: starting with no agent where the machine asked which, or burying the one that works.
      final starting = await opened(
        machineWith(
          const Readiness(
            ready: false,
            outcome: StartOutcome.severalAgents,
            agent: '',
            provider: '',
            credential: '',
            detail: '',
            signedIn: <String>['codex'],
          ),
        ),
      );
      starting
        ..mode = Mode.agent
        ..callIt('work');

      expect(starting.ready, isFalse);
      expect(starting.agentsInOrder.map((each) => each.name), <String>['codex', 'claude']);
    });

    test('the sign-in the form asks for is that of the agent the machine chose', () async {
      // Harm: a start that fails signed out, because no agent was picked to sign in to.
      final starting = await opened(
        machineWith(
          const Readiness(
            ready: false,
            outcome: StartOutcome.credentialMissing,
            agent: 'codex',
            provider: 'openai',
            credential: 'openai',
            detail: '',
            agentSource: 'ONLY_ONE',
          ),
          agents: <Map<String, dynamic>>[
            <String, dynamic>{'name': 'codex', 'canLogIn': true},
          ],
        ),
      );

      expect(starting.chosenAgent?.name, 'codex');
      expect(starting.needsASignIn, isTrue);
    });

    test('an agent carried over that is gone is not swapped for the one the machine would choose', () async {
      // Harm: a job kept for one agent runs with another, because that one is gone and nobody was asked.
      final machine = machineWith(found);
      final starting = StartWork();
      addTearDown(starting.dispose);
      await starting.openFrom(
        machine,
        machine.theProjectsItHas.first,
        const Template(name: 'job', project: 'p', agent: 'removed', mode: Mode.agent, prompt: '', repository: ''),
      );
      starting.callIt('work');
      await starting.askAgain();

      expect(starting.agent, isNull);
      expect(starting.agentToRun, isNull);
      expect(starting.ready, isFalse);
    });

    test('an answer overtaken while the forge is asked for its keys does not land', () async {
      // Harm: the agent, sign-in and commands of a question nobody is asking any more.
      final keys = Completer<List<String>>();
      final machine = machineWith(
        const Readiness(
          ready: false,
          outcome: StartOutcome('UNKNOWN_HOST_KEY'),
          agent: 'old',
          provider: '',
          credential: '',
          detail: '',
          agentSource: 'ONLY_ONE',
        ),
      );
      final starting = StartWork()..publishedHostKeys = () => keys.future;
      addTearDown(starting.dispose);
      final opening = starting.open(machine, machine.theProjectsItHas.first);
      await pumpEventQueue();
      machine.nextReadiness = found;
      await starting.askAgain();
      keys.complete(const <String>[]);
      await opening;

      expect(starting.readiness?.agent, 'codex');
    });

    test('a template keeps the agent the machine chose, by name', () async {
      // Harm: nothing to keep, or a job kept that later starts another agent than the one seen here.
      final starting = await opened(machineWith(found));
      starting
        ..mode = Mode.agent
        ..templateName = 'job';

      expect(starting.asTemplate?.agent, 'codex');
    });
  });
}

/// A machine that lists the agents given and remembers which agent each question named.
class _Asked extends FakeBackend {
  _Asked(List<Map<String, dynamic>> listed) : super(const <Task>[]) {
    theAgentsItHas = listed.map(Agent.from).toList();
  }

  final askedFor = <String?>[];

  @override
  Future<Readiness> canStart({
    String? project,
    String? agent,
    String? task,
    String? repository,
    Map<String, String>? credentials,
  }) {
    askedFor.add(agent);
    return super.canStart(project: project, agent: agent, task: task, repository: repository, credentials: credentials);
  }
}
