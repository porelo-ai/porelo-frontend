import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/app/window_log.dart';
import 'package:porelo_frontend/src/ui/planning_embedding.dart';
import 'package:porelo_planning/porelo_planning.dart';

import '../features/support/world.dart';

void main() {
  test('a planner no machine is named after offers the agents of the machine its project runs on', () async {
    final machines = Machines(
      Settings(MemorySettingsStore()),
      reach: (_) => FakeBackend(const []),
      tunnels: FakeTunnels(),
    );
    addTearDown(machines.dispose);
    final source = _Source();
    final client = _PathPlanner(source);

    expect(planningMachineOf(machines, client, source, project: 'foo-project'), same(machines.current));
    // The person stands on the project's board: no project is chosen in Work.
    final offered = await MachinePlanningAgents(machines, client, project: () => 'foo-project').on(source);
    expect(offered.agents.map((each) => each.name), ['an-agent', 'other-agent']);
  });

  test('a board whose project the window is not told offers the agents of the machine its planner lists', () async {
    final machines = Machines(
      Settings(MemorySettingsStore()),
      reach: (_) => FakeBackend(const []),
      tunnels: FakeTunnels(),
    );
    addTearDown(machines.dispose);
    final source = _Source();

    // The planning screen chose the board's project itself; neither the place nor Work names it.
    final offered = await MachinePlanningAgents(machines, _PathPlanner(source)).on(source);
    expect(offered.agents.map((each) => each.name), ['an-agent', 'other-agent']);
  });

  // Harm: Start work preselects an agent that cannot work on the machine, or offers models and efforts it refuses.
  test('each agent says whether it is ready there, and the models and efforts the machine lists', () async {
    Agent agent(String name, String found, {String provider = '', List<String>? efforts}) => Agent.from({
      'name': name,
      'label': name,
      'binary': '/usr/bin/$name',
      'version': '1',
      'from': '',
      'allowedDomains': const <String>[],
      'found': found,
      'foundProvider': provider,
      'efforts': ?efforts,
    });
    final backend = FakeBackend(const [])
      ..theAgentsItHas = [
        agent('signed', 'SIGNED_IN', provider: 'anthropic', efforts: const ['low', 'high']),
        agent('out', 'NOT_SIGNED_IN', efforts: const []),
        agent('unsure', 'CANNOT_SAY'),
      ]
      ..theModelsItOffers = const {
        'anthropic': [OfferedModel(id: 'model-one', label: 'Model One')],
      };
    final machines = Machines(Settings(MemorySettingsStore()), reach: (_) => backend, tunnels: FakeTunnels());
    addTearDown(machines.dispose);
    final source = _Source();

    final offered = await MachinePlanningAgents(
      machines,
      _PathPlanner(source),
      project: () => 'foo-project',
    ).on(source);
    final byName = {for (final each in offered.agents) each.name: each};

    expect(byName['signed']!.unready, isNull);
    expect(byName['signed']!.models.map((each) => (each.id, each.label)), [('model-one', 'Model One')]);
    expect(byName['signed']!.efforts, ['low', 'high']);
    expect(byName['out']!.unready, contains('not signed in'));
    expect(byName['out']!.efforts, isEmpty, reason: 'an agent that takes no effort lists none');
    expect(byName['out']!.models, isEmpty, reason: 'no provider was found to ask');
    expect(byName['unsure']!.unready, isNull, reason: 'cannot say is never read as signed out');
    expect(byName['unsure']!.efforts, isNull, reason: 'an older machine does not say its efforts');
  });

  // Harm: one slow or refusing model list holds every agent of Start work back, or hides why no model is listed.
  test(
    'a model list that fails or does not answer offers the agent with its model typed, and the log says why',
    () async {
      final backend = FakeBackend(const [])
        ..theAgentsItHas = [
          Agent.from({
            'name': 'signed',
            'label': 'signed',
            'binary': '/usr/bin/signed',
            'version': '1',
            'from': '',
            'allowedDomains': const <String>[],
            'found': 'SIGNED_IN',
            'foundProvider': 'anthropic',
          }),
        ];
      final machines = Machines(Settings(MemorySettingsStore()), reach: (_) => backend, tunnels: FakeTunnels());
      addTearDown(machines.dispose);
      final source = _Source();
      final agents = MachinePlanningAgents(
        machines,
        _PathPlanner(source),
        project: () => 'foo-project',
        modelsWait: const Duration(milliseconds: 50),
      );
      final logs = Directory('${Directory.systemTemp.path}/porelo-agents-logs-${DateTime.now().microsecondsSinceEpoch}')
        ..createSync();
      final before = windowLog;
      windowLog = WindowLog(logs.path, level: ValueNotifier(LogLevel.debug), keepPrivate: (_) async {});
      addTearDown(() {
        windowLog = before;
        logs.deleteSync(recursive: true);
      });
      List<String> logged() {
        final log = File('${logs.path}/${WindowLog.fileName}');
        return log.existsSync() ? log.readAsLinesSync() : const [];
      }

      backend.offeredModelsFail = VarlinkException(
        'org.fuin.porelo.Tasks1.CredentialRefused',
        const <String, dynamic>{},
      );
      final refused = await agents.on(source);
      expect(refused.agents.single.models, isEmpty);
      expect(refused.agents.single.unready, isNull, reason: 'the agent is still offered');

      backend
        ..offeredModelsFail = null
        ..offeredModelsHeld = Completer<void>();
      final slow = await agents.on(source).timeout(const Duration(seconds: 5));
      expect(slow.agents.single.models, isEmpty, reason: 'the agents are not held back by the model list');
      backend.offeredModelsHeld!.complete();

      await Future<void>.delayed(const Duration(milliseconds: 20));
      final said = logged().where((line) => line.contains('the models of signed on')).toList();
      expect(said, hasLength(2));
      expect(said.first, contains('CredentialRefused'));
      expect(said.last, contains('did not answer within'));
    },
  );

  test('a refusal of the agents says which part of the machine is not known', () async {
    final machines = Machines(
      Settings(MemorySettingsStore()),
      reach: (_) => FakeBackend(const []),
      tunnels: FakeTunnels(),
    );
    addTearDown(machines.dispose);
    final source = _Source();
    final client = _PathPlanner(source, projects: const []);

    await expectLater(
      MachinePlanningAgents(machines, client).on(source),
      throwsA(predicate((error) => '$error'.contains('which project planner starts on'))),
    );
    await expectLater(
      MachinePlanningAgents(machines, client, project: () => 'foo-project').on(_Source()),
      throwsA(predicate((error) => '$error'.contains('no longer follows planner'))),
    );
  });
}

/// The planner found on the path: a provider named as no watched machine is.
class _PathPlanner extends ChangeNotifier implements PlanningClient {
  _PathPlanner(this.source, {this.projects = const ['foo-project']});

  final PlanningSource source;

  final List<String> projects;

  @override
  List<PlanningProvider> get providers => [
    PlanningProvider(name: 'porelo-planner', connected: true, projects: projects, source: source),
  ];

  @override
  String? get currentProvider => 'porelo-planner';

  @override
  String? get chosenProject => null;

  @override
  Future<void> taskEvent(
    String project,
    String task,
    PlanningTaskEvent event, {
    required String offer,
    required String container,
    required String machine,
    PlanningTaskEnded? ended,
    List<PlanningLanding> landed = const [],
  }) async {}
}

class _Source extends Fake implements PlanningSource {
  @override
  String get label => 'planner';
}
