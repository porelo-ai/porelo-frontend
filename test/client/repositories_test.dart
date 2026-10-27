// Linux only: it stands the mock daemon on a unix socket, and on GitHub's Windows runner a test
// through it hung where no timeout could end it.
@Tags(<String>['linux'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/mock/mock_daemon.dart';

/// A project names its repositories, and a start names the one it is in — sent only
/// when named, so a daemon older than repositories per project never meets a parameter it does not know.
void main() {
  late MockDaemon daemon;

  setUp(() async {
    daemon = MockDaemon();
    await daemon.start();
  });

  tearDown(() => daemon.stop());

  Future<PoreloClient> connect() => PoreloClient.connect(Backend(socketPath: daemon.socketPath, label: 'mock'));

  Future<Map<String, dynamic>> started({String? repository}) async {
    Map<String, dynamic>? asked;
    daemon.stream('Start', (parameters) {
      asked = parameters;
      return Stream.fromIterable(<Map<String, dynamic>>[
        <String, dynamic>{'container': 'porelo-demo-shell-1', 'exitCode': 0},
      ]);
    });
    await (await connect()).start(project: 'project.yml', repository: repository).toList();
    return asked!;
  }

  test('a start in a repository names it', () async {
    expect((await started(repository: 'payments-api'))['repository'], 'payments-api');
  });

  test('a start with no repository sends none at all', () async {
    expect((await started()).containsKey('repository'), isFalse);
  });

  test("a project's repositories are read in the order given, its own first", () async {
    daemon.method(
      'Projects',
      (_) => <String, dynamic>{
        'projects': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'checkout',
            'repositories': <String>['checkout', 'payments-api'],
          },
          <String, dynamic>{'name': 'older'},
        ],
      },
    );

    final projects = await (await connect()).projects();

    expect(projects.first.repositories, <String>['checkout', 'payments-api']);
    expect(projects.last.repositories, isEmpty, reason: 'a daemon older than repositories per project says none');
  });

  test('repositories answered as objects are read, the own one first', () async {
    daemon.method(
      'Projects',
      (_) => <String, dynamic>{
        'projects': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'checkout',
            'pending': 3,
            'repositories': <Map<String, dynamic>>[
              <String, dynamic>{
                'name': 'payments-api',
                'own': false,
                'upstream': 'git@example.org:payments-api.git',
                'mirror': '/srv/checkout/.porelo/repositories/payments-api',
                'pending': 2,
                'behind': 4,
                'behindMeasured': '2026-09-18T22:00:00Z',
                'behindReason': 'MEASURED',
              },
              <String, dynamic>{'name': 'checkout', 'own': true, 'pending': 1},
            ],
          },
        ],
      },
    );

    final project = (await (await connect()).projects()).single;

    expect(project.repositories, <String>['checkout', 'payments-api']);
    final other = project.repositoryStates.last;
    expect(other.own, isFalse);
    expect(other.pending, 2);
    expect(other.behind, 4);
    expect(other.behindReason, 'MEASURED');
    expect(other.upstream, 'git@example.org:payments-api.git');
  });

  // An agent started for the wrong repository, or a one-click start offered from a daemon that never said.
  test("a repository's agent is read as named, as none, and as not said by an older daemon", () async {
    daemon.method(
      'Projects',
      (_) => <String, dynamic>{
        'projects': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'checkout',
            'repositories': <Map<String, dynamic>>[
              <String, dynamic>{'name': 'checkout', 'own': true},
              <String, dynamic>{
                'name': 'payments-api',
                'agent': 'pi',
                'nickname': 'Payments',
                'goesBy': 'Agent Payments',
              },
              <String, dynamic>{'name': 'docs', 'agent': '', 'goesBy': 'Agent docs'},
            ],
          },
          <String, dynamic>{
            'name': 'older',
            'repositories': <Map<String, dynamic>>[
              <String, dynamic>{'name': 'older', 'own': true},
              <String, dynamic>{'name': 'api'},
            ],
          },
        ],
      },
    );

    final projects = await (await connect()).projects();

    final named = projects.first.repositoryStates.firstWhere((each) => each.name == 'payments-api');
    expect(named.agent, 'pi', reason: 'the agent its project file names');
    expect(named.nickname, 'Payments');
    expect(named.goesBy, 'Agent Payments', reason: 'the name the machine composes, shown verbatim');
    expect(projects.first.repositoryStates.firstWhere((each) => each.name == 'docs').agent, '', reason: 'none named');
    expect(
      projects.last.repositoryStates.map((each) => each.agent),
      everyElement(isNull),
      reason: 'a daemon older than the field says nothing, which is not "none named"',
    );
  });

  group('each repository has a gate of its own', () {
    Future<Map<String, String?>> asked({String? repository}) async {
      final names = <String, String?>{};
      Map<String, dynamic> answer(String method, Map<String, dynamic> parameters) {
        names[method] = parameters['repository'] as String?;
        if (!parameters.containsKey('repository')) names[method] = 'none sent';
        return <String, dynamic>{};
      }

      for (final method in <String>['Pending', 'Review', 'Approve', 'Reject']) {
        daemon.method(method, (parameters) => answer(method, parameters));
      }
      final client = await connect();
      await client.gate('project.yml', repository: repository);
      await client.review('project.yml', 'migrate', repository: repository);
      await client.approve('project.yml', 'migrate', 'fix', repository: repository);
      await client.reject('project.yml', 'migrate', repository: repository);
      return names;
    }

    test('asking about one names it, in every gate call', () async {
      expect((await asked(repository: 'payments-api')).values, everyElement('payments-api'));
    });

    test('asking about none sends none, which an older Porelo can take', () async {
      expect((await asked()).values, everyElement('none sent'));
    });
  });

  test('a follow state is read whole, and neither absent nor empty is a follow', () async {
    daemon.method(
      'Projects',
      (_) => <String, dynamic>{
        'projects': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'checkout',
            'following': <String, dynamic>{
              'name': 'checkout',
              'url': 'git@example.org:checkout.git',
              'commit': '4f2a9c1e0b77',
              'at': '2026-09-19T03:50:00Z',
              'outcome': 'UNKNOWN_KEY',
              'refused': 'b71d03aa9e2c',
              'signer': 'SHA256:9xQeTbL1',
              'detail': 'not pinned here',
              'needsAPerson': true,
              'unverified': true,
            },
          },
          <String, dynamic>{'name': 'nobody-follows'},
          <String, dynamic>{'name': 'empty-object', 'following': <String, dynamic>{}},
        ],
      },
    );

    final projects = await (await connect()).projects();

    final followed = projects.first.following!;
    expect(followed.commit, '4f2a9c1e0b77');
    expect(followed.refused, 'b71d03aa9e2c', reason: 'what was turned away is not what runs');
    expect(followed.signer, 'SHA256:9xQeTbL1');
    expect(followed.needsAPerson, isTrue);
    expect(followed.unverified, isTrue);
    expect(projects[1].following, isNull);
    expect(projects[2].following, isNull, reason: 'an empty object is not a follow');
  });

  group("a repository's egress is asked and written with its name", () {
    Future<Map<String, String?>> asked({String? repository}) async {
      final names = <String, String?>{};
      for (final method in <String>['Egress', 'SetEgress']) {
        daemon.method(method, (parameters) {
          names[method] = parameters.containsKey('repository') ? parameters['repository'] as String? : 'none sent';
          return <String, dynamic>{};
        });
      }
      final client = await connect();
      await client.egress('checkout', repository: repository);
      await client.setEgress('checkout', addSets: <String>['containers'], dryRun: true, repository: repository);
      return names;
    }

    test('named where one is chosen', () async {
      expect((await asked(repository: 'payments-api')).values, everyElement('payments-api'));
    });

    test('none sent for the project itself, which an older Porelo can take', () async {
      expect((await asked()).values, everyElement('none sent'));
    });
  });

  test("a repository's limits are read with where each key came from", () async {
    daemon.method(
      'Projects',
      (_) => <String, dynamic>{
        'projects': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'checkout',
            'repositories': <Map<String, dynamic>>[
              <String, dynamic>{
                'name': 'payments-api',
                'limits': <String, dynamic>{
                  'memory': '4g',
                  'cpus': '',
                  'pids': 512,
                  'memoryFrom': 'repository',
                  'cpusFrom': 'project',
                  'pidsFrom': 'project',
                },
              },
              <String, dynamic>{'name': 'older'},
            ],
          },
        ],
      },
    );

    final repositories = (await (await connect()).projects()).single.repositoryStates;

    final limits = repositories.first.limits!;
    expect(limits.words, 'memory 4g (its own) · cpus no limit · processes 512');
    expect(repositories.last.limits, isNull, reason: 'a Porelo that does not say says nothing');
  });

  test('what this account follows is read, one entry per project', () async {
    daemon.method(
      'Following',
      (_) => <String, dynamic>{
        'projects': <Map<String, dynamic>>[
          <String, dynamic>{'name': 'e2e-follow', 'outcome': 'APPLIED', 'unverified': true},
        ],
      },
    );

    final followed = await (await connect()).following();

    expect(followed.single.name, 'e2e-follow');
    expect(followed.single.inForce, isTrue);
    expect(followed.single.unverified, isTrue);
  });

  test('a project left from before following carries a file and is still not acted on', () async {
    daemon.method(
      'Projects',
      (_) => <String, dynamic>{
        'projects': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'objects4j',
            'file': '/home/alice/git/objects4j/project.yml',
            'following': <String, dynamic>{},
          },
          <String, dynamic>{'name': 'older', 'file': '/srv/older/project.yml'},
        ],
      },
    );

    final projects = await (await connect()).projects();

    expect(projects.first.canBeActedOn, isFalse, reason: 'the machine follows nothing called that');
    expect(projects.last.canBeActedOn, isTrue, reason: 'a Porelo that says nothing about following');
  });
}
