import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/start_work.dart';

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
}
