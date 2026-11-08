// Linux only: it stands the mock daemon on a unix socket, and on GitHub's Windows runner a test
// through it hung where no timeout could end it.
@Tags(<String>['linux'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/mock/mock_daemon.dart';

/// A task's names and model, and the default models of a project and its repositories, as a machine answers them
/// and as one older than them answers.
void main() {
  late MockDaemon daemon;

  setUp(() async {
    daemon = MockDaemon();
    await daemon.start();
  });

  tearDown(() => daemon.stop());

  Future<PoreloClient> connect() => PoreloClient.connect(Backend(socketPath: daemon.socketPath, label: 'mock'));

  const older = <String, dynamic>{
    'name': 'porelo-checkout-pi',
    'project': 'checkout',
    'securityClass': 'guarded',
    'state': 'running',
    'running': true,
    'helpers': 0,
    'agent': 'omp',
    'provider': 'anthropic',
  };

  // Harm: a task from a machine that does not say which model it runs reads as running the agent's own default,
  // or the list does not read at all.
  test('a task from an older machine reads, with no model and no names said', () async {
    daemon.method(
      'List',
      (_) => <String, dynamic>{
        'tasks': <Map<String, dynamic>>[older],
      },
    );

    final task = (await (await connect()).tasks()).single;

    expect(task.name, 'porelo-checkout-pi');
    expect(task.model, isNull, reason: 'not said is not the agent default');
    expect(task.modelLabel, isNull);
    expect(task.display, isNull);
    expect(task.short, isNull);
    expect(task.named, isNull);
  });

  // Harm: a task that runs the agent's own default reads as one whose model was not said, or the other way round.
  test("a task that runs its agent's own default says so, apart from one that was not said", () async {
    daemon.method(
      'List',
      (_) => <String, dynamic>{
        'tasks': <Map<String, dynamic>>[
          <String, dynamic>{
            ...older,
            'model': '',
            'modelLabel': '',
            'display': 'Agent Pi',
            'short': 'pi',
            'named': false,
          },
        ],
      },
    );

    final task = (await (await connect()).tasks()).single;

    expect(task.model, '');
    expect(task.display, 'Agent Pi');
    expect(task.short, 'pi');
    expect(task.named, isFalse);
  });

  // Harm: a project or a repository from an older machine crashes the project list, or names a default model
  // nobody set.
  test('a project and its repositories from an older machine read, with no default model', () async {
    daemon.method(
      'Projects',
      (_) => <String, dynamic>{
        'projects': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'checkout',
            'securityClass': 'guarded',
            'file': '/srv/checkout/project.yml',
            'repositories': <Map<String, dynamic>>[
              <String, dynamic>{'name': 'payments-api', 'own': false},
            ],
          },
        ],
      },
    );

    final project = (await (await connect()).projects()).single;

    expect(project.defaultModels, isEmpty);
    expect(project.repositoryStates.single.defaultModels, isEmpty);
  });

  // Harm: the default a repository names for its provider is lost, or one for another provider is taken for it.
  test('a repository names its default model per provider, as the machine merged it', () async {
    daemon.method(
      'Projects',
      (_) => <String, dynamic>{
        'projects': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'checkout',
            'securityClass': 'guarded',
            'file': '/srv/checkout/project.yml',
            'defaultModels': <Map<String, dynamic>>[
              <String, dynamic>{
                'provider': 'anthropic',
                'model': 'claude-sonnet',
                'label': 'Sonnet',
                'from': 'project',
              },
            ],
            'repositories': <Map<String, dynamic>>[
              <String, dynamic>{
                'name': 'payments-api',
                'own': false,
                'defaultModels': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'provider': 'anthropic',
                    'model': 'claude-opus',
                    'label': 'Opus',
                    'from': 'repository',
                  },
                  <String, dynamic>{'provider': 'openai', 'model': 'gpt', 'label': '', 'from': 'project'},
                ],
              },
            ],
          },
        ],
      },
    );

    final project = (await (await connect()).projects()).single;
    final repository = project.repositoryStates.single;

    expect(ProviderModel.forProvider(repository.defaultModels, 'anthropic')?.model, 'claude-opus');
    expect(ProviderModel.forProvider(repository.defaultModels, 'anthropic')?.from, 'repository');
    expect(ProviderModel.forProvider(repository.defaultModels, 'openai')?.model, 'gpt');
    expect(ProviderModel.forProvider(repository.defaultModels, 'mistral'), isNull);
    expect(ProviderModel.forProvider(project.defaultModels, 'anthropic')?.model, 'claude-sonnet');
  });

  // Harm: a start sends a model nobody chose, and the machine runs it in place of the provider's default.
  test('a start names a model only where one is given', () async {
    final asked = <Map<String, dynamic>>[];
    daemon.stream('Start', (parameters) {
      asked.add(parameters);
      return Stream.fromIterable(<Map<String, dynamic>>[
        <String, dynamic>{'container': 'porelo-checkout-pi', 'exitCode': 0},
      ]);
    });
    final client = await connect();

    await client.start(project: 'checkout').toList();
    await client.start(project: 'checkout', model: 'claude-opus').toList();

    expect(asked.first.containsKey('model'), isFalse);
    expect(asked.last['model'], 'claude-opus');
  });
}
