import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';
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

  test('a refusal of the agents says which part of the machine is not known', () async {
    final machines = Machines(
      Settings(MemorySettingsStore()),
      reach: (_) => FakeBackend(const []),
      tunnels: FakeTunnels(),
    );
    addTearDown(machines.dispose);
    final source = _Source();
    final client = _PathPlanner(source);

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
  _PathPlanner(this.source);

  final PlanningSource source;

  @override
  List<PlanningProvider> get providers => [
    PlanningProvider(name: 'porelo-planner', connected: true, projects: const ['foo-project'], source: source),
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
  }) async {}
}

class _Source extends Fake implements PlanningSource {
  @override
  String get label => 'planner';
}
