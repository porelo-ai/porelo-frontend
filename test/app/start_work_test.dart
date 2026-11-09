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

/// A repository in `default` whose `porelo.yml` sets what the machine has not allowed, as Porelo answers it: only an
/// allowance of the text shown starts it, and a file changed since asks again.
class _SettingsToAllow extends FakeBackend {
  _SettingsToAllow() : super(const <Task>[]);

  /// What the file sets now, and the hash naming it.
  var setting = const SettingToAllow(key: 'egress.domains', value: 'repo.example.org', was: '');
  var hash = 'h1';

  /// The hash the machine holds as allowed.
  String allowedHash = '';

  @override
  Future<Readiness> canStart({
    String? project,
    String? agent,
    String? task,
    String? repository,
    Map<String, String>? credentials,
  }) async => allowedHash == hash
      ? const Readiness(ready: true, outcome: StartOutcome.ready, agent: '', provider: '', credential: '', detail: '')
      : Readiness(
          ready: false,
          outcome: StartOutcome.settingsNotAllowed,
          agent: '',
          provider: '',
          credential: '',
          detail: 'porelo.yml of x sets what is not allowed here',
          settingsToAllow: <SettingToAllow>[
            setting,
            const SettingToAllow(key: 'limits.memory', was: '4g', removed: true),
          ],
          settingsHash: hash,
        );

  @override
  Future<SettingsAllowed> allowSettings(String repository, String hash) async {
    await super.allowSettings(repository, hash);
    if (hash != this.hash) return const SettingsAllowed(outcome: 'CHANGED', detail: 'porelo.yml of x changed');
    allowedHash = hash;
    return const SettingsAllowed(outcome: 'ALLOWED');
  }
}

void main() {
  // Harm: a task reaching hosts or credentials the person never allowed, or an allowance of a text nobody was shown.
  test("a repository's settings are allowed by the hash that was shown, and asked about again", () async {
    final machine = _SettingsToAllow();
    final starting = StartWork();
    addTearDown(starting.dispose);
    await starting.open(machine, machine.theProjectsItHas.first, repository: 'x');
    starting
      ..mode = Mode.agent
      ..callIt('work')
      ..chooseAgent(machine.theAgentsItHas.first.name);
    await starting.askAgain();
    expect(starting.readiness?.outcome, StartOutcome.settingsNotAllowed);
    expect(starting.readiness?.settingsToAllow.map((each) => each.key), <String>['egress.domains', 'limits.memory']);
    expect(starting.ready, isFalse, reason: 'nothing starts before the settings are allowed');

    await starting.allowTheSettings();

    expect(machine.settingsAllowedAsked, <(String, String)>[('x', 'h1')]);
    expect(starting.ready, isTrue, reason: 'the machine answered READY after the allowance');
  });

  group('the proposal before the first task on a repository in default', () {
    const asks = FirstStart(
      outcome: FirstStart.askNew,
      hosts: <String>['repo.example.org'],
      file: 'egress:\n  domains: [repo.example.org]\n',
      fileName: '.porelo.yml (this machine)',
      project: defaultProject,
      hash: 'h1',
    );

    // Harm: settings written and allowed with nobody having said yes to the text shown.
    test('a yes is sent for exactly the text shown, and the start goes on', () async {
      final machine = FakeBackend(const <Task>[])..theFirstStartOfSays['shop'] = asks;
      FirstStart? shown;
      final after = await askBeforeTheFirstTask(machine, 'shop', (first) async {
        shown = first;
        return true;
      });
      expect(shown?.hash, 'h1');
      expect(machine.firstStartsOfConfirmed, <(String, String)>[('shop', 'h1')]);
      expect(after, AfterTheProposal.start);
    });

    // Harm: work started though the person closed the question, or settings written on a no.
    test('a no writes nothing and starts; closing it writes nothing and starts nothing', () async {
      final machine = FakeBackend(const <Task>[])..theFirstStartOfSays['shop'] = asks;
      expect(await askBeforeTheFirstTask(machine, 'shop', (_) async => false), AfterTheProposal.start);
      expect(await askBeforeTheFirstTask(machine, 'shop', (_) async => null), AfterTheProposal.startNothing);
      expect(machine.firstStartsOfConfirmed, isEmpty);
    });

    test('a repository with its settings, and a machine without the question, start without asking', () async {
      final machine = FakeBackend(const <Task>[])
        ..theFirstStartOfSays['known'] = const FirstStart(outcome: FirstStart.known, project: defaultProject);
      var asked = 0;
      Future<bool?> ask(FirstStart _) async {
        asked++;
        return true;
      }

      expect(await askBeforeTheFirstTask(machine, 'known', ask), AfterTheProposal.start);
      expect(await askBeforeTheFirstTask(machine, 'older', ask), AfterTheProposal.start);
      expect(asked, 0);
      expect(machine.firstStartsOfAsked, <String>['known', 'older']);
    });
  });

  // Harm: work started on a porelo.yml nobody who may sign it signed.
  test('a start refused for an unsigned porelo.yml is offered in no mode', () async {
    final machine = FakeBackend(const <Task>[])
      ..nextReadiness = const Readiness(
        ready: false,
        outcome: StartOutcome.settingsUnsigned,
        agent: '',
        provider: '',
        credential: '',
        detail: 'porelo.yml of x changed in abc123 without a signature',
        file: 'porelo.yml',
        commit: 'abc123',
      );
    final starting = StartWork();
    addTearDown(starting.dispose);
    await starting.open(machine, machine.theProjectsItHas.first);
    for (final mode in <Mode>[Mode.agent, Mode.shell]) {
      starting
        ..mode = mode
        ..callIt('work')
        ..chooseAgent(machine.theAgentsItHas.first.name);
      await starting.askAgain();
      expect(starting.ready, isFalse, reason: '$mode');
      expect(starting.whatItWouldCost, isNull, reason: 'no start is offered in spite of it in $mode');
    }
  });

  // Harm: an allowance taken for a file that changed after it was shown.
  test('settings that changed after they were shown are not allowed, and the new ones are shown', () async {
    final machine = _SettingsToAllow();
    final starting = StartWork();
    addTearDown(starting.dispose);
    await starting.open(machine, machine.theProjectsItHas.first, repository: 'x');
    starting
      ..mode = Mode.agent
      ..callIt('work')
      ..chooseAgent(machine.theAgentsItHas.first.name);
    await starting.askAgain();
    machine
      ..setting = const SettingToAllow(key: 'egress.domains', value: 'elsewhere.example.org')
      ..hash = 'h2';

    await starting.allowTheSettings();

    expect(machine.settingsAllowedAsked, <(String, String)>[('x', 'h1')]);
    expect(machine.allowedHash, isEmpty);
    expect(starting.ready, isFalse);
    expect(starting.readiness?.settingsHash, 'h2');
    expect(starting.readiness?.settingsToAllow.first.value, 'elsewhere.example.org');
    expect(starting.problem, contains('changed'));
  });

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

  // Harm: a form closed while its machine still answered takes that answer into the form opened next on another
  // machine, or asks the first machine about the second form.
  test(
    'an answer for a form closed since lands nowhere, and the machine it was opened on is asked nothing more',
    () async {
      final first = _Slow();
      final second = FakeBackend(const <Task>[])
        ..theAgentsItHas = <Agent>[
          Agent.from(const <String, dynamic>{'name': 'only-here', 'label': 'Only Here'}),
        ];
      final starting = StartWork();
      addTearDown(starting.dispose);
      final reading = starting.open(first, first.theProjectsItHas.first);
      starting.close();
      expect(starting.openedOn, isNull, reason: 'a closed form is on no machine');
      await starting.open(second, second.theProjectsItHas.first);
      final askedBefore = first.canStartAsked;
      first.answer.complete();
      await reading;
      await pumpEventQueue();
      expect(starting.agents.map((each) => each.name), <String>[
        'only-here',
      ], reason: 'the agents of the form open now');
      expect(first.canStartAsked, askedBefore, reason: 'nothing more is asked of the machine of a closed form');
      expect(starting.openedOn, same(second));
    },
  );

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

  // Harm: a task started in a repository the organization's machine does not have, with nothing to work in.
  test('on a machine that said what it has taken, only those repositories are offered, and why not the rest', () async {
    final machine = FakeBackend(const <Task>[]);
    final project = Project.from(const <String, dynamic>{
      'name': 'porelo',
      'file': '/home/me/porelo/project.yml',
      'repositories': <String>['porelo-project', 'core', 'sluice', 'frontend', 'matrix'],
    });
    machine.theProjectsItHas = <Project>[project];
    final starting = StartWork();
    addTearDown(starting.dispose);
    await starting.open(machine, project);
    starting.chooseRepository('frontend');

    starting.offerOnly({'core', 'sluice'}, '2 repositories name no central address.');

    expect(starting.offeredRepositories, ['core', 'sluice']);
    expect(starting.repository, isNull, reason: 'the one chosen is not on the machine');
    expect(starting.notOfferedWords, '2 repositories name no central address.');
  });

  test('a start opened on a repository the machine has not taken is opened afresh, and one left is chosen', () async {
    final machine = FakeBackend(const <Task>[]);
    final project = Project.from(const <String, dynamic>{
      'name': 'porelo',
      'file': '/home/me/porelo/project.yml',
      'repositories': <String>['porelo-project', 'core', 'frontend'],
    });
    machine.theProjectsItHas = <Project>[project];
    final starting = StartWork();
    addTearDown(starting.dispose);
    await starting.open(machine, project, repository: 'frontend');

    starting.offerOnly({'core'}, '1 repository names no central address.');

    // Opened for frontend, the form showed it fixed; gone from the offer, it showed nothing and failed.
    expect(starting.openedForRepository, isNull);
    expect(starting.repository, 'core', reason: 'the only one offered needs no choosing');
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

  // Harm: the machine cannot see a checkout here, and work on it would start from a branch the person is not on.
  group('a checkout on this computer', () {
    final project = Project.from(const <String, dynamic>{
      'name': 'checkout',
      'file': '/home/me/checkout/project.yml',
      'repositories': <Map<String, dynamic>>[
        <String, dynamic>{'name': 'checkout', 'own': true, 'upstream': 'git@forge.example:me/checkout.git'},
        <String, dynamic>{'name': 'payments-api', 'upstream': 'git@forge.example:me/payments-api.git'},
        <String, dynamic>{'name': 'web', 'upstream': 'https://forge.example/me/web'},
      ],
    });

    Future<(FakeBackend, StartWork)> opened(CheckoutHere? checkout) async {
      final machine = FakeBackend(const <Task>[])..theProjectsItHas = <Project>[project];
      final starting = StartWork();
      addTearDown(starting.dispose);
      await starting.open(machine, project, checkout: checkout);
      return (machine, starting);
    }

    Future<String?> startedFrom(FakeBackend machine, StartWork starting) async {
      starting
        ..mode = Mode.shell
        ..callIt('work');
      await starting.askAgain();
      unawaited(starting.begin(machine).listen((_) {}).asFuture<void>());
      await pumpEventQueue();
      return machine.startedFrom.single;
    }

    test('names its branch for the repository it is a checkout of', () async {
      final (machine, starting) = await opened(
        const CheckoutHere(branch: 'feature/x', origin: 'git@forge.example:me/payments-api.git'),
      );
      starting.chooseRepository('payments-api');
      expect(starting.checkoutBranch, 'feature/x');
      expect(await startedFrom(machine, starting), 'feature/x');
    });

    test('knows its repository written another way', () async {
      final (_, starting) = await opened(
        const CheckoutHere(branch: 'feature/x', origin: 'git@forge.example:me/web.git'),
      );
      starting.chooseRepository('web');
      expect(starting.checkoutBranch, 'feature/x');
    });

    test('names no branch for another repository of the project', () async {
      final (machine, starting) = await opened(
        const CheckoutHere(branch: 'feature/x', origin: 'git@forge.example:me/payments-api.git'),
      );
      starting.chooseRepository('web');
      expect(starting.checkoutBranch, isNull);
      expect(await startedFrom(machine, starting), isNull);
    });

    test('names its branch for the repository it was put in as, whatever the machine lists', () async {
      final (_, starting) = await opened(
        const CheckoutHere(branch: 'feature/x', origin: 'git@elsewhere.example:me/x.git', repository: 'web'),
      );
      starting.chooseRepository('web');
      expect(starting.checkoutBranch, 'feature/x');
    });

    // Harm: a checkout with no origin, whose project's file names its folder, starts from the machine's choice.
    test('knows its repository by its folder where the file names that', () async {
      final local = Project.from(const <String, dynamic>{
        'name': 'mine',
        'repositories': <Map<String, dynamic>>[
          <String, dynamic>{'name': 'mine', 'upstream': '/home/me/mine'},
        ],
      });
      final starting = StartWork();
      addTearDown(starting.dispose);
      await starting.open(
        FakeBackend(const <Task>[])..theProjectsItHas = <Project>[local],
        local,
        checkout: const CheckoutHere(branch: 'feature/x', origin: '', path: '/home/me/mine/'),
      );
      starting.chooseRepository('mine');
      expect(starting.checkoutBranch, 'feature/x');
    });

    // Harm: a project the checkout named, whose file names no upstream, starts from the machine's choice.
    test('knows the one repository of a project it named, whose file names no upstream', () async {
      final guarded = Project.from(const <String, dynamic>{
        'name': 'guarded',
        'repositories': <Map<String, dynamic>>[
          <String, dynamic>{'name': 'guarded', 'upstream': ''},
        ],
      });
      Future<String?> branchFor(CheckoutHere checkout) async {
        final starting = StartWork();
        addTearDown(starting.dispose);
        await starting.open(
          FakeBackend(const <Task>[])..theProjectsItHas = <Project>[guarded],
          guarded,
          checkout: checkout,
        );
        starting.chooseRepository('guarded');
        return starting.checkoutBranch;
      }

      const here = CheckoutHere(branch: 'feature/x', origin: 'git@fork.example:me/guarded.git');
      expect(await branchFor(here.naming), 'feature/x');
      expect(await branchFor(here), isNull, reason: 'a checkout that named another project is not this one');
    });

    test('a detached checkout names none', () async {
      final (_, starting) = await opened(const CheckoutHere(branch: null, origin: 'git@forge.example:me/web.git'));
      starting.chooseRepository('web');
      expect(starting.checkoutBranch, isNull);
    });

    test('work opened another way names none', () async {
      final (machine, starting) = await opened(null);
      starting.chooseRepository('web');
      expect(await startedFrom(machine, starting), isNull);
    });
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

  group('the model', () {
    /// A task that ran `big-model` through `a-provider`, the provider the machine names for `an-agent`.
    final ran = Task.from(const <String, dynamic>{
      'name': 'porelo-checkout-nightly',
      'task': 'nightly',
      'project': 'checkout',
      'securityClass': 'guarded',
      'state': 'Exited (0) 2 minutes ago',
      'running': false,
      'helpers': 0,
      'agent': 'an-agent',
      'provider': 'a-provider',
      'mode': 'UNATTENDED',
      'prompt': 'Run the tests',
      'model': 'big-model',
    });

    Future<String?> modelSent(FakeBackend machine, StartWork starting) async {
      starting.callIt(starting.name.isEmpty ? 'more-work' : starting.name);
      await starting.askAgain();
      expect(starting.ready, isTrue, reason: '${starting.problem ?? starting.readiness?.detail}');
      unawaited(starting.begin(machine).listen((_) {}).asFuture<void>());
      await pumpEventQueue();
      return machine.startedModels.single;
    }

    // Harm: going on with work quietly changes the model it ran to another one.
    test('continuing a task sends the model it ran', () async {
      final machine = FakeBackend(const <Task>[]);
      final starting = StartWork();
      addTearDown(starting.dispose);
      await starting.continueFrom(machine, machine.theProjectsItHas.first, ran);

      expect(await modelSent(machine, starting), 'big-model');
    });

    test('restarting a task sends the model it ran', () async {
      final machine = FakeBackend(const <Task>[]);
      final starting = StartWork();
      addTearDown(starting.dispose);
      await starting.restartFrom(machine, machine.theProjectsItHas.first, ran);

      expect(await modelSent(machine, starting), 'big-model');
    });

    // Harm: a model meant for one provider is sent where another one runs, and means nothing there.
    test('a model typed for one provider is not sent after the agent changed to another', () async {
      final machine = FakeBackend(const <Task>[])
        ..readinessOf['other-agent'] = const Readiness(
          ready: true,
          outcome: StartOutcome.ready,
          agent: 'other-agent',
          provider: 'b-provider',
          credential: 'b-provider',
          detail: '',
        );
      final starting = StartWork();
      addTearDown(starting.dispose);
      await starting.open(machine, machine.theProjectsItHas.first);
      starting
        ..callIt('work')
        ..chooseAgent('an-agent');
      await starting.askAgain();
      starting
        ..chooseModel('big-model')
        ..chooseAgent('other-agent');
      await starting.askAgain();

      expect(await modelSent(machine, starting), isNull);
    });

    // Harm: the model the machine says a start runs on for the provider that runs is not filled in, and the
    // machine's own default is taken in its place, unseen.
    test('the model the machine names for the provider that runs is filled in and sent', () async {
      final machine = FakeBackend(const <Task>[])
        ..modelsOf = <String, List<ProviderModel>>{
          'checkout/checkout': const <ProviderModel>[
            ProviderModel(provider: 'a-provider', model: 'repo-model', from: 'repository'),
          ],
        };
      final starting = StartWork();
      addTearDown(starting.dispose);
      await starting.open(machine, machine.theProjectsItHas.first, repository: 'checkout');
      starting.chooseAgent('an-agent');
      await starting.askAgain();

      expect(machine.modelsAsked.last, (project: 'checkout', repository: 'checkout'));
      expect(starting.model, 'repo-model');
      expect(await modelSent(machine, starting), 'repo-model');
    });

    // Harm: the model the machine names for one provider is filled in and sent where another provider runs.
    test("the model of another provider is not taken, and the agent's own default is sent as none", () async {
      final machine = FakeBackend(const <Task>[])
        ..readinessOf['other-agent'] = const Readiness(
          ready: true,
          outcome: StartOutcome.ready,
          agent: 'other-agent',
          provider: 'b-provider',
          credential: 'b-provider',
          detail: '',
        )
        ..modelsOf = <String, List<ProviderModel>>{
          'checkout': const <ProviderModel>[
            ProviderModel(provider: 'a-provider', model: 'a-model', from: 'project'),
            ProviderModel(provider: 'b-provider', model: '', from: 'agent'),
          ],
        };
      final starting = StartWork();
      addTearDown(starting.dispose);
      await starting.open(machine, machine.theProjectsItHas.first);
      starting.chooseAgent('an-agent');
      await starting.askAgain();
      expect(starting.model, 'a-model');

      starting.chooseAgent('other-agent');
      await starting.askAgain();

      expect(starting.model, isEmpty, reason: 'b-provider runs on the agent default');
      expect(await modelSent(machine, starting), isNull);
    });

    // Harm: a machine older than the models a start runs on leaves the form unable to start, or fills in a model.
    test('a machine that does not say which model a start runs on leaves the field empty and starts', () async {
      final machine = FakeBackend(const <Task>[]);
      final starting = StartWork();
      addTearDown(starting.dispose);
      await starting.open(machine, machine.theProjectsItHas.first, repository: 'checkout');
      starting.chooseAgent('an-agent');
      await starting.askAgain();

      expect(starting.model, isEmpty);
      expect(await modelSent(machine, starting), isNull);
    });

    // Harm: a model typed while the new agent's answer is out is tagged with the old agent's provider and cleared,
    // or adopted by a provider it was not typed for.
    test('a model typed after the agent changed, before the machine answered, is kept for that agent', () async {
      final machine = FakeBackend(const <Task>[])
        ..readinessOf['other-agent'] = const Readiness(
          ready: true,
          outcome: StartOutcome.ready,
          agent: 'other-agent',
          provider: 'b-provider',
          credential: 'b-provider',
          detail: '',
        );
      final starting = StartWork();
      addTearDown(starting.dispose);
      await starting.open(machine, machine.theProjectsItHas.first);
      starting
        ..callIt('work')
        ..chooseAgent('an-agent');
      await starting.askAgain();
      starting.chooseAgent('other-agent');
      starting.chooseModel('b-model');
      await pumpEventQueue();

      expect(starting.model, 'b-model', reason: 'typed for the agent chosen, it is kept for its provider');
      expect(await modelSent(machine, starting), 'b-model');
    });

    // Harm: the model of the repository before is sent for another, while the machine has not said that one's.
    test("another repository's model waits for the machine's answer for it, and is never the one before", () async {
      final project = Project.from(const <String, dynamic>{
        'name': 'checkout',
        'securityClass': 'guarded',
        'file': '/srv/checkout/project.yml',
        'repositories': <Map<String, dynamic>>[
          <String, dynamic>{'name': 'checkout', 'own': true},
          <String, dynamic>{'name': 'api'},
          <String, dynamic>{'name': 'docs'},
        ],
      });
      final machine = FakeBackend(const <Task>[])
        ..theProjectsItHas = <Project>[project]
        ..modelsOf = <String, List<ProviderModel>>{
          'checkout/api': const <ProviderModel>[
            ProviderModel(provider: 'a-provider', model: 'api-model', from: 'repository'),
          ],
          'checkout/docs': const <ProviderModel>[
            ProviderModel(provider: 'a-provider', model: 'docs-model', from: 'repository'),
          ],
        };
      final starting = StartWork();
      addTearDown(starting.dispose);
      await starting.open(machine, project, repository: 'api');
      starting
        ..callIt('work')
        ..chooseAgent('an-agent');
      await starting.askAgain();
      expect(starting.model, 'api-model');

      final held = machine.modelsHeld = Completer<void>();
      starting.chooseRepository('docs');
      await pumpEventQueue();

      expect(starting.model, isEmpty, reason: 'the model of api is not docs');
      expect(starting.ready, isFalse, reason: 'the model of docs is not said yet');
      held.complete();
      await pumpEventQueue();
      expect(starting.model, 'docs-model');
      expect(await modelSent(machine, starting), 'docs-model');
    });

    // Harm: a model typed for one agent is sent for another whose provider the machine does not name.
    test('a model typed for one agent is not sent for another whose provider is not named', () async {
      final machine = FakeBackend(const <Task>[])
        ..readinessOf['other-agent'] = const Readiness(
          ready: true,
          outcome: StartOutcome.ready,
          agent: 'other-agent',
          provider: '',
          credential: '',
          detail: '',
        );
      final starting = StartWork();
      addTearDown(starting.dispose);
      await starting.open(machine, machine.theProjectsItHas.first);
      starting
        ..callIt('work')
        ..chooseAgent('an-agent');
      await starting.askAgain();
      starting.chooseModel('big-model');
      starting.chooseAgent('other-agent');
      await starting.askAgain();

      expect(starting.model, isEmpty);
      expect(await modelSent(machine, starting), isNull);
    });

    test('a model typed for one agent is not kept for another when the machine could not say', () async {
      final machine = FakeBackend(const <Task>[]);
      final starting = StartWork();
      addTearDown(starting.dispose);
      await starting.open(machine, machine.theProjectsItHas.first);
      starting
        ..callIt('work')
        ..chooseAgent('an-agent');
      await starting.askAgain();
      starting.chooseModel('big-model');
      machine.canStartFails = 'the vault could not be read';
      starting.chooseAgent('other-agent');
      await starting.askAgain();

      expect(starting.model, isEmpty);
    });

    // Harm: the default of the agent before stays in the field, and is sent for an agent whose provider was not said.
    test('an unchosen default goes with its agent when another is chosen and the machine cannot say more', () async {
      final machine = FakeBackend(const <Task>[])
        ..modelsOf = <String, List<ProviderModel>>{
          'checkout': const <ProviderModel>[ProviderModel(provider: 'a-provider', model: 'a-model', from: 'project')],
        };
      final starting = StartWork();
      addTearDown(starting.dispose);
      await starting.open(machine, machine.theProjectsItHas.first, repository: 'checkout');
      starting.chooseAgent('an-agent');
      await starting.askAgain();
      expect(starting.model, 'a-model');
      machine.canStartFails = 'the vault could not be read';
      starting.chooseAgent('other-agent');
      await starting.askAgain();

      expect(starting.model, isEmpty, reason: 'the default was for the agent before');
    });
  });

  // Harm: a branch sent to another repository, or none to the right one, where the machine's own match differs.
  group('two addresses of one repository', () {
    for (final same in <(String, String)>[
      ('git@gitlab.example:group/sub/repo.git', 'https://gitlab.example/group/sub/repo'),
      ('https://gitlab.example/group/sub/repo.git', 'https://GitLab.example/group/sub/repo/'),
      ('/path/to/repo.git', '/path/to/repo/'),
      ('ssh://git@forge.example:22/me/x.git', 'git@forge.example:me/x'),
      ('https://forge.example:443/me/x', 'https://forge.example/me/x.git'),
    ]) {
      test('are one: ${same.$1} and ${same.$2}', () => expect(sameAddress(same.$1, same.$2), isTrue));
    }
    for (final other in <(String, String)>[
      ('http://127.0.0.1:3001/acme/api.git', 'http://127.0.0.1:3002/acme/api.git'),
      ('git@forge.example:me/x.git', 'git@forge.example:you/x.git'),
      ('/path/to/repo', 'git@forge.example:path/to/repo'),
      ('', ''),
    ]) {
      test('are two: ${other.$1} and ${other.$2}', () => expect(sameAddress(other.$1, other.$2), isFalse));
    }
  });
}

/// A machine whose list of agents waits until the test lets it answer, and that counts what it was asked.
class _Slow extends FakeBackend {
  _Slow() : super(const <Task>[]);

  final answer = Completer<void>();

  @override
  Future<AgentsOnTheMachine> agentsOn() async {
    await answer.future;
    return super.agentsOn();
  }
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
