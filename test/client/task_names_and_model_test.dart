// Linux only: it stands the mock daemon on a unix socket, and on GitHub's Windows runner a test
// through it hung where no timeout could end it.
@Tags(<String>['linux'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/mock/mock_daemon.dart';

/// A task's names and model, and the model a start on a project would run per provider, as a machine answers them
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
    expect(task.modelFrom, isNull);
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
            'modelFrom': 'agent',
            'display': 'pi',
            'short': 'pi',
            'named': '',
          },
        ],
      },
    );

    final task = (await (await connect()).tasks()).single;

    expect(task.model, '');
    expect(task.modelFrom, 'agent');
    expect(task.display, 'pi');
    expect(task.short, 'pi');
    expect(task.named, '');
  });

  // Harm: one provider's model is taken for another's, or an entry that names no model reads as no answer.
  test('the models a start would run are read per provider, and the agent default is one of them', () async {
    final asked = <Map<String, dynamic>>[];
    daemon.method('ProviderModels', (parameters) {
      asked.add(parameters);
      return <String, dynamic>{
        'models': <Map<String, dynamic>>[
          <String, dynamic>{'provider': 'anthropic', 'model': 'claude-opus', 'label': 'Opus', 'from': 'repository'},
          <String, dynamic>{'provider': 'openai', 'model': '', 'label': '', 'from': 'agent'},
        ],
      };
    });
    final client = await connect();

    final models = await client.providerModels('checkout', repository: 'payments-api');
    await client.providerModels('checkout');

    expect(asked.first, <String, dynamic>{'project': 'checkout', 'repository': 'payments-api'});
    expect(asked.last.containsKey('repository'), isFalse, reason: 'omitted, the project file alone answers');
    expect(ProviderModel.forProvider(models, 'anthropic')?.model, 'claude-opus');
    expect(ProviderModel.forProvider(models, 'openai')?.model, '');
    expect(ProviderModel.forProvider(models, 'openai')?.from, 'agent');
    expect(ProviderModel.forProvider(models, 'mistral'), isNull);

    daemon.remove('ProviderModels');
    await expectLater(client.providerModels('checkout'), throwsA(isA<FeatureNotSupported>()));
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
