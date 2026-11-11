import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/planner.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/ui/planning_embedding.dart';
import 'package:porelo_frontend/src/ui/planning_reports.dart';
import 'package:porelo_planning/porelo_planning.dart';

import 'window_task_starts_test.dart' show plannedOrders;

const _laptop = Machine(name: 'laptop', socketPath: '/run/laptop.sock');
const _provider = 'porelo-planner';

void main() {
  late MemorySettingsStore store;
  late Settings settings;
  late _Machine machine;
  late _Planner planner;
  late List<(Machine, String)> stopped;
  late List<(String, String, List<(PlanningTaskOrder, PlanningTaskStarted)>)> shown;

  Future<Settings> loaded() async {
    final again = Settings(store);
    await again.load();
    return again;
  }

  /// The window's starts and reports as they stand after a start of the window on [settings].
  (WindowTaskStarts, WindowTaskReports) window({Machine on = _laptop, Settings? kept}) {
    final starts = WindowTaskStarts(
      machineFor: (_) => on,
      backendOf: (_) => machine,
      settings: kept ?? settings,
      providerOf: (source) => identical(source, planner) ? _provider : null,
      machineNamed: (name) => name == on.name ? on : null,
    );
    final reports = WindowTaskReports(
      settings: kept ?? settings,
      starts: starts,
      sourceNamed: (name) => name == _provider ? planner : null,
      tasksOn: (name) => name == on.name ? machine.listed : null,
      stopOn: (machine, container) async => stopped.add((machine, container)),
    );
    reports.onFollowUps = (source, project, story, tasks) async => shown.add((project, story, tasks));
    return (starts, reports);
  }

  setUp(() async {
    store = MemorySettingsStore();
    settings = await loaded();
    machine = _Machine();
    planner = _Planner();
    stopped = [];
    shown = [];
  });

  // Harm: the planner never learns that a task it ordered runs, or learns it for another machine or task.
  test('a confirmed start is reported once as started, on the machine it runs on', () async {
    final (starts, reports) = window();
    final order = (await plannedOrders()).first;

    final started = await starts(planner, 'demo', 'ST291', order);
    await reports.idle;
    reports.sweep();
    await reports.idle;

    expect(planner.calls, hasLength(1));
    final call = planner.calls.single;
    expect(
      (call.project, call.task, call.event, call.offer, call.container, call.machine, call.ended),
      ('demo', started.task, PlanningTaskEvent.started, order.offer, started.container, 'laptop', null),
    );
    expect((await loaded()).plannedOffer('laptop', started.container)!.startedReported, isTrue);
  });

  // Harm: a refused report undoes or hides a task that runs, or its refusal goes unsaid.
  test('a refused report keeps the task and says the planner\'s words', () async {
    final (starts, reports) = window();
    final problems = <String>[];
    reports.onProblem = (provider, project, error) => problems.add('$provider $project ${planningFailureWords(error)}');
    planner.answers.add(const PlanningRefusal('TaskEventConflict', {}, 'The offer does not match this task.'));
    final order = (await plannedOrders()).first;

    final started = await starts(planner, 'demo', 'ST291', order);
    await reports.idle;

    expect(started.container, isNotEmpty);
    expect(stopped, isEmpty);
    expect(settings.planningOffer('laptop', started.container), order.offer);
    expect(problems, ['porelo-planner demo The offer does not match this task.']);
  });

  // Harm: an agent's end is never told, told twice, or told in other words than Porelo recorded.
  test('a new end of the agent is reported once, as Porelo recorded it', () async {
    final (starts, reports) = window();
    final started = await starts(planner, 'demo', 'ST291', (await plannedOrders()).first);
    await reports.idle;

    machine.end(started.container, {
      'at': '2026-11-11T03:00:00Z',
      'finished': false,
      'error': 'The provider refused the key.',
      'source': 'provider',
      'status': 401,
      'unpushed': 2,
      'lastAnswer': 'Outcome: blocked.',
    });
    reports.sweep();
    await reports.idle;
    reports.sweep();
    await reports.idle;

    final ends = planner.calls.where((call) => call.event == PlanningTaskEvent.ended).toList();
    expect(ends, hasLength(1));
    expect(ends.single.ended!.toMap(), {
      'at': '2026-11-11T03:00:00Z',
      'finished': false,
      'why': 'The provider refused the key.',
      'answer': 'Outcome: blocked.',
      'unpushed': 2,
    });
  });

  // Harm: an end that was there before the task started again is reported as this run's end.
  test('an end the task showed when it started is no end of this run', () async {
    machine.endBeforeStart = {'at': 'earlier', 'finished': true};
    final (starts, reports) = window();
    await starts(planner, 'demo', 'ST291', (await plannedOrders()).first);
    await reports.idle;

    reports.sweep();
    await reports.idle;

    expect(planner.calls.map((call) => call.event), [PlanningTaskEvent.started]);
  });

  // Harm: a restart of the window reports an end twice, or never reports one that came while it was closed.
  test('after a restart, an end that came while the window was closed is reported once', () async {
    final (starts, reports) = window();
    final started = await starts(planner, 'demo', 'ST291', (await plannedOrders()).first);
    await reports.idle;
    machine.end(started.container, {'at': 'while closed', 'finished': true, 'lastAnswer': 'Done.'});

    final (_, reopened) = window(kept: await loaded());
    reopened.sweep();
    await reopened.idle;
    final (_, again) = window(kept: await loaded());
    again.sweep();
    await again.idle;

    expect(planner.calls.map((call) => call.event), [PlanningTaskEvent.started, PlanningTaskEvent.ended]);
  });

  // Harm: the planner's next task is never started, or started twice after a retry or a restart.
  test('a follow-up order is started once, for the project and story it came for, and shown', () async {
    final (starts, reports) = window();
    final orders = await plannedOrders();
    final followUp = _followUp(1);
    planner.answers.addAll([
      _answer([followUp]),
      _answer([followUp]),
    ]);
    final started = await starts(planner, 'demo', 'ST291', orders.first);
    await reports.idle;
    machine.end(started.container, {'at': 'the end', 'finished': true});
    reports.sweep();
    await reports.idle;

    final (_, reopened) = window(kept: await loaded());
    planner.answers.add(_answer([followUp]));
    await reopened.report(
      'demo',
      started.task,
      PlanningTaskEvent.stopped,
      offer: orders.first.offer!,
      container: started.container,
      machine: 'laptop',
    );
    await reopened.idle;

    expect(machine.started.map((each) => each['repository']), [orders.first.repository, 'builder-one']);
    expect(shown.map((each) => (each.$1, each.$2, each.$3.single.$1.offer)), [('demo', 'ST291', followUp['offer'])]);
  });

  // Harm: the follow-ups after a refused one start anyway, or the refusal goes unsaid.
  test('a refused follow-up stops the rest of the answer\'s orders and says why', () async {
    final (starts, reports) = window();
    final problems = <String>[];
    reports.onProblem = (provider, project, error) => problems.add(planningFailureWords(error));
    planner.answers.add(_answer([_followUp(1), _followUp(2, repository: 'builder-two')]));
    await starts(planner, 'demo', 'ST291', (await plannedOrders()).first);
    machine.refuseNext = 'porelo: the vault is locked';

    await reports.idle;

    expect(machine.started, hasLength(1), reason: 'only the order the screen started');
    expect(problems.single, contains('porelo: the vault is locked'));
    expect(shown, isEmpty);
  });

  // Harm: a task whose offer the planner voided goes on running, or is reported again and again.
  test('a report the planner no longer answers stops the task, forgets its offer and is not sent again', () async {
    final (starts, reports) = window();
    final started = await starts(planner, 'demo', 'ST291', (await plannedOrders()).first);
    await reports.idle;
    planner.answers.add(const PlanningRefusal('TaskNotAnswered', {}, 'The planner no longer answers for this task.'));
    machine.end(started.container, {'at': 'the end', 'finished': true});

    reports.sweep();
    await reports.idle;
    machine.end(started.container, {'at': 'a later end', 'finished': true});
    reports.sweep();
    await reports.idle;

    expect(stopped, [(_laptop, started.container)]);
    expect((await loaded()).planningOffer('laptop', started.container), isNull);
    expect(planner.calls.map((call) => call.event), [PlanningTaskEvent.started, PlanningTaskEvent.ended]);
  });

  // Harm: a task started while its story was stopped runs on, or is reported though the planner voided it.
  test('a stop stops each task on the machine it was started on, reports nothing and forgets its offer', () async {
    final (starts, reports) = window();
    final started = await starts(planner, 'demo', 'ST291', (await plannedOrders()).first);
    await reports.stop(planner, 'demo', 'ST291', [started]);
    await reports.idle;

    expect(stopped, [(_laptop, started.container)]);
    expect(planner.calls, isEmpty);
    expect((await loaded()).planningOffer('laptop', started.container), isNull);
  });

  // Harm: after a restart, a stopped story's task runs on because the window forgot where it started it.
  test('after a restart, a stop finds the machine by the kept offer', () async {
    final (starts, reports) = window();
    final started = await starts(planner, 'demo', 'ST291', (await plannedOrders()).first);
    await reports.idle;

    final (_, reopened) = window(kept: await loaded());
    await reopened.stop(planner, 'demo', 'ST291', [started]);

    expect(stopped, [(_laptop, started.container)]);
  });

  // Harm: a machine name the planner must refuse is sent, and binds the offer to a name it cannot keep.
  test('a machine name the planner refuses is refused here, and nothing is sent', () async {
    for (final name in ['x' * 129, 'line\u2028break', 'delete\x7fhere', 'lone\ud800surrogate']) {
      planner.calls.clear();
      final named = Machine(name: name, socketPath: '/run/named.sock');
      final (starts, reports) = window(on: named);
      final problems = <String>[];
      reports.onProblem = (provider, project, error) => problems.add(planningFailureWords(error));

      await starts(planner, 'demo', 'ST291', (await plannedOrders()).first);
      await reports.idle;

      expect(planner.calls, isEmpty, reason: 'the name ${name.runes.toList()}');
      expect(problems, hasLength(1), reason: 'the name ${name.runes.toList()}');
    }
  });

  // Harm: an entry an earlier build kept is reported with names guessed for it, or breaks every report.
  test('an entry an earlier build kept is not reported, and that is said once', () async {
    store = MemorySettingsStore({
      'planningOffers': [
        {'machine': 'laptop', 'container': 'porelo-demo-old', 'offer': '00000000-0000-4000-8000-0000000000aa'},
      ],
    });
    settings = await loaded();
    machine.listed.add(
      Task.from({
        'name': 'porelo-demo-old',
        'task': 'old',
        'project': 'demo',
        'agentEnded': {'at': 'the end', 'finished': true},
      }),
    );
    final (_, reports) = window();
    final problems = <String>[];
    reports.onProblem = (provider, project, error) => problems.add(planningFailureWords(error));

    reports.sweep();
    await reports.idle;
    reports.sweep();
    await reports.idle;

    expect(planner.calls, isEmpty);
    expect(problems, hasLength(1));
  });

  // Harm: a report through the window's planning client goes to another task's offer, or nowhere.
  test('a report through the planner client goes to the provider kept with the offer, only for that offer', () async {
    final (starts, reports) = window();
    final order = (await plannedOrders()).first;
    final started = await starts(planner, 'demo', 'ST291', order);
    await reports.idle;
    final client = LocalPlanner(projects: () => const ['demo'], repositories: (_) => throw UnimplementedError())
      ..reports = reports.report;
    addTearDown(client.dispose);

    await client.taskEvent(
      'demo',
      started.task,
      PlanningTaskEvent.stopped,
      offer: order.offer!,
      container: started.container,
      machine: 'laptop',
    );
    await expectLater(
      client.taskEvent(
        'demo',
        started.task,
        PlanningTaskEvent.stopped,
        offer: '00000000-0000-4000-8000-0000000000ff',
        container: started.container,
        machine: 'laptop',
      ),
      throwsA(isA<PlanningRefusal>()),
    );

    expect(planner.calls.map((call) => call.event), [PlanningTaskEvent.started, PlanningTaskEvent.stopped]);
  });
}

/// A follow-up order of the planner, a builder of B540 in [repository].
Map<String, dynamic> _followUp(int number, {String repository = 'builder-one'}) => {
  'offer': '00000000-0000-4000-8000-${'$number'.padLeft(12, '0')}',
  'repository': repository,
  'issues': ['B540'],
  'role': 'BUILDER',
  'agent': 'codex',
  'model': 'a-model',
  'mode': 'UNATTENDED',
  'prompt': 'Build B540.',
};

/// The planner's answer to a report, with [followUps] still valid.
Map<String, dynamic> _answer(List<Map<String, dynamic>> followUps) => {
  'revision': 'r1',
  'tasks': followUps,
  'work': {
    'atWork': true,
    'coordinator': null,
    'since': 'then',
    'comment': '',
    'readingRounds': 2,
    'tasks': [
      {
        'task': 'main',
        'containerId': 'porelo-demo-main',
        'machine': 'laptop',
        'ended': null,
        'atWork': true,
        'repository': 'porelo',
        'issues': ['B540'],
        'state': 'Implementing',
        'done': '',
        'mode': 'UNATTENDED',
        'agent': 'codex',
        'model': 'a-model',
        'role': 'MAIN',
        'since': 'then',
      },
    ],
    'repositories': [
      for (final repository in ['porelo', 'builder-one', 'builder-two'])
        {
          'repository': repository,
          'issues': ['B540'],
        },
    ],
    'issues': <Object>[],
    'issueReadingRounds': <Object>[],
  },
};

typedef _Call = ({
  String project,
  String task,
  PlanningTaskEvent event,
  String offer,
  String container,
  String machine,
  PlanningTaskEnded? ended,
});

/// A provider's source that records each report and answers what a test queued, an empty answer when none is.
class _Planner extends Fake implements PlanningSource {
  final calls = <_Call>[];
  final answers = <Object>[];

  @override
  String get label => 'planner';

  @override
  Future<TaskEventResolution> taskEvent(
    String project,
    String task,
    PlanningTaskEvent event, {
    required String offer,
    required String container,
    required String machine,
    PlanningTaskEnded? ended,
  }) async {
    calls.add((
      project: project,
      task: task,
      event: event,
      offer: offer,
      container: container,
      machine: machine,
      ended: ended,
    ));
    final next = answers.isEmpty ? _answer(const []) : answers.removeAt(0);
    if (next is Exception) throw next;
    return TaskEventResolution.from(next as Map<String, dynamic>);
  }
}

/// A machine whose Start makes a container per repository and lists it under the repository's name.
class _Machine extends Fake implements FleetBackend {
  final started = <Map<String, Object>>[];
  final listed = <Task>[];
  Map<String, dynamic>? endBeforeStart;
  String? refuseNext;

  /// The agent of [container] ended as [ended] says.
  void end(String container, Map<String, dynamic> ended) {
    final index = listed.indexWhere((task) => task.name == container);
    final task = listed[index];
    listed[index] = Task.from({
      'name': task.name,
      'task': task.task,
      'project': task.project,
      'running': false,
      'agentEnded': ended,
    });
  }

  @override
  String get label => 'laptop';

  @override
  Future<StartProgress> startOrdered({
    required String project,
    required String repository,
    required String agent,
    required String model,
    required Mode mode,
    required String prompt,
  }) async {
    if (refuseNext case final words?) {
      refuseNext = null;
      return StartProgress(exitCode: 1, output: [words]);
    }
    started.add({'project': project, 'repository': repository});
    final container = 'porelo-$project-$repository';
    listed.removeWhere((task) => task.name == container);
    listed.add(
      Task.from({
        'name': container,
        'task': repository,
        'project': project,
        'running': true,
        'agentEnded': ?endBeforeStart,
      }),
    );
    return StartProgress(container: container, exitCode: 0, action: StartAction.create);
  }

  @override
  Future<List<Task>> tasks() async => List.of(listed);
}
