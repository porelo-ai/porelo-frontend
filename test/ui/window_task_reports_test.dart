import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/planner.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/app/window_log.dart';
import 'package:porelo_frontend/src/ui/planning_embedding.dart';
import 'package:porelo_frontend/src/ui/planning_reports.dart';
import 'package:porelo_planning/porelo_planning.dart';

import 'package:porelo_frontend/src/app/planner_ideas.dart';

import 'window_task_starts_test.dart' show discussionOrder, plannedOrders;

const _laptop = Machine(name: 'laptop', socketPath: '/run/laptop.sock');
const _provider = 'porelo-planner';

void main() {
  late MemorySettingsStore store;
  late Settings settings;
  late _Machine machine;
  late _Planner planner;
  late List<(Machine, String)> stopped;
  late List<(String, String, List<(PlanningTaskOrder, PlanningTaskStarted)>)> shown;
  late List<(String, String, Map<String, Object?>)> handed;
  late List<(String, String)> removed;
  late List<Object> handAnswers;
  late Map<String, TaskResult> results;

  Future<Settings> loaded() async {
    final again = Settings(store);
    await again.load();
    return again;
  }

  /// The window's starts and reports as they stand after a start of the window on [settings].
  (WindowTaskStarts, WindowTaskReports) window({
    Machine on = _laptop,
    Settings? kept,
    bool Function()? reached,
    IssueFromIdea? handIssue,
    DateTime Function()? now,
  }) {
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
      sourceNamed: (name) => name == _provider && (reached?.call() ?? true) ? planner : null,
      tasksOn: (name) => name == on.name ? machine.listed : null,
      stopOn: (machine, container) async => stopped.add((machine, container)),
      removeOn: (machine, container) async => removed.add((machine, container)),
      resultOf: (name, container) async =>
          name == on.name ? results[container] ?? fail('no result for $container') : fail('$name is not watched'),
      hand: (project, offer, idea, {runtimeDirectory, projects}) async {
        handed.add((project, offer, idea));
        final next = handAnswers.isEmpty ? 'ST900' : handAnswers.removeAt(0);
        if (next is Exception) throw next;
        return next as String;
      },
      watched: () => [on.name],
      ideaPlanner: () => reached?.call() ?? true ? (_provider, planner) : null,
      repositoryOf: (name, task) => name == on.name && task.repository.isNotEmpty ? task.repository : null,
      handIssue: handIssue ?? issueFromIdea,
      now: now ?? DateTime.now,
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
    handed = [];
    removed = [];
    handAnswers = [];
    results = {};
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

  // Harm: a reader is started seeing none of the work it is to read, and searches for it until its time runs out.
  test('a reader the planner orders is started naming the tasks whose work it reads', () async {
    final (starts, reports) = window();
    planner.answers.add(
      _answer([
        _followUp(1, role: 'READER', reads: ['foo-1']),
      ]),
    );

    await starts(planner, 'demo', 'ST291', (await plannedOrders()).first);
    await reports.idle;

    expect(machine.started.map((each) => each['reads']), [
      const <String>[],
      const ['foo-1'],
    ]);
  });

  // Harm: the planner never learns where a build's work landed, and orders its reader to read a branch it cannot see.
  test('an end names where the work landed, as Porelo lists it', () async {
    final (starts, reports) = window();
    final started = await starts(planner, 'demo', 'ST291', (await plannedOrders()).first);
    await reports.idle;

    machine.end(started.container, {'at': 'the end', 'finished': true}, landed: [_landing]);
    reports.sweep();
    await reports.idle;
    final (_, reopened) = window(kept: await loaded());
    reopened.sweep();
    await reopened.idle;

    expect(planner.calls.map((call) => call.event), [PlanningTaskEvent.started, PlanningTaskEvent.ended]);
    expect(planner.calls.last.ended!.landed.map((landing) => landing.toMap()), [_landing]);
  });

  // Harm: a build whose work waited at the gate when it ended is never read, or its landing is told twice.
  test('work that landed after its task ended is reported once as landed, also across a restart', () async {
    final (starts, reports) = window();
    final started = await starts(planner, 'demo', 'ST291', (await plannedOrders()).first);
    await reports.idle;
    machine.end(started.container, {'at': 'the end', 'finished': true}, landed: const []);
    reports.sweep();
    await reports.idle;

    machine.land(started.container, [_landing]);
    reports.sweep();
    await reports.idle;
    reports.sweep();
    await reports.idle;
    final (_, reopened) = window(kept: await loaded());
    reopened.sweep();
    await reopened.idle;

    expect(planner.calls.map((call) => call.event), [
      PlanningTaskEvent.started,
      PlanningTaskEvent.ended,
      PlanningTaskEvent.landed,
    ]);
    expect(planner.calls[1].ended!.landed, isEmpty);
    expect(planner.calls.last.landed.map((landing) => landing.toMap()), [_landing]);
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
      'answer': 'Outcome: blocked.',
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

  // Harm: a planner not reached floods the window with the same line on every change of a machine, or its reports
  // are never sent once it answers.
  test('a planner not reached is said once, and the report goes once it is reached', () async {
    var reached = false;
    final (starts, reports) = window(reached: () => reached);
    final problems = <String>[];
    reports.onProblem = (provider, project, error) => problems.add(planningFailureWords(error));

    await starts(planner, 'demo', 'ST291', (await plannedOrders()).first);
    await reports.idle;
    for (var change = 0; change < 3; change++) {
      reports.sweep();
      await reports.idle;
    }
    expect(planner.calls, isEmpty);
    reached = true;
    reports.sweep();
    await reports.idle;

    expect(problems, hasLength(1));
    expect(planner.calls.map((call) => call.event), [PlanningTaskEvent.started]);
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

  // Harm: a task the window never started is reported to the planner under an earlier task's offer, because it took
  // the earlier one's container name after that one was removed while the window was closed.
  test('a later task under the same container name is not reported under the earlier task\'s offer', () async {
    final (starts, reports) = window();
    final started = await starts(planner, 'demo', 'ST291', (await plannedOrders()).first);
    await reports.idle;
    final earlier = machine.listed.singleWhere((task) => task.name == started.container);
    machine.listed
      ..remove(earlier)
      ..add(
        Task.from({
          'name': earlier.name,
          'task': earlier.task,
          'project': earlier.project,
          'running': false,
          'run': 'a-later-run',
          'agentEnded': {'at': '2026-11-12T14:10:05Z', 'finished': true, 'answer': 'Findings:'},
        }),
      );

    final (_, reopened) = window(kept: await loaded());
    reopened.sweep();
    await reopened.idle;

    expect(planner.calls.map((call) => call.event), [PlanningTaskEvent.started]);
    expect((await loaded()).plannedOffer('laptop', started.container), isNull);
  });

  // Harm: dropping an earlier task's offer takes a later discussion's kept record with it, so its idea is never handed.
  test('dropping an earlier task\'s offer keeps a discussion started under the same container name', () async {
    final (starts, reports) = window();
    final started = await starts(planner, 'demo', 'ST291', (await plannedOrders()).first);
    await reports.idle;
    await settings.rememberDiscussion(
      machine: 'laptop',
      container: started.container,
      offer: 'a-discussion-offer',
      provider: _provider,
      project: 'demo',
    );
    final earlier = machine.listed.singleWhere((task) => task.name == started.container);
    machine.listed
      ..remove(earlier)
      ..add(
        Task.from({
          'name': earlier.name,
          'task': earlier.task,
          'project': earlier.project,
          'running': true,
          'run': 'a-later-run',
        }),
      );

    final (_, reopened) = window(kept: await loaded());
    reopened.sweep();
    await reopened.idle;

    final kept = await loaded();
    expect(kept.plannedOffer('laptop', started.container), isNull);
    expect(kept.keptDiscussions.map((each) => each.offer), ['a-discussion-offer']);
  });

  // Harm: a restart of the window reports an end twice, or never reports one that came while it was closed.
  test('after a restart, an end that came while the window was closed is reported once', () async {
    final (starts, reports) = window();
    final started = await starts(planner, 'demo', 'ST291', (await plannedOrders()).first);
    await reports.idle;
    machine.end(started.container, {'at': 'while closed', 'finished': true, 'answer': 'Done.'});

    final (_, reopened) = window(kept: await loaded());
    reopened.sweep();
    await reopened.idle;
    final (_, again) = window(kept: await loaded());
    again.sweep();
    await again.idle;

    expect(planner.calls.map((call) => call.event), [PlanningTaskEvent.started, PlanningTaskEvent.ended]);
  });

  // Harm: a window that ended between Start's answer and keeping the offer leaves a task no window reports.
  test('a task started just before the window ended is found by its key and reported under its offer', () async {
    final (starts, _) = window();
    final order = (await plannedOrders()).first;
    machine.hangAfterStart = true;
    unawaited(starts(planner, 'demo', 'ST291', order));
    await pumpEventQueue();
    expect((await loaded()).plannedOffers, isEmpty);

    final (_, reopened) = window(kept: await loaded());
    reopened.sweep();
    await reopened.idle;
    final (_, again) = window(kept: await loaded());
    again.sweep();
    await again.idle;

    expect(machine.started.single['callerKey'], order.offer);
    expect(planner.calls.map((call) => (call.project, call.task, call.event, call.offer, call.container)), [
      ('demo', 'porelo', PlanningTaskEvent.started, order.offer, 'porelo-demo-porelo'),
    ]);
  });

  // Harm: the end of a task whose start the window never heard is never reported, or reported twice.
  test('a task started just before the window ended reports its end under its offer, once', () async {
    final (starts, _) = window();
    final order = (await plannedOrders()).first;
    machine.hangAfterStart = true;
    unawaited(starts(planner, 'demo', 'ST291', order));
    await pumpEventQueue();
    machine.end('porelo-demo-porelo', {'at': 'while closed', 'finished': true, 'answer': 'Done.'});

    final (_, reopened) = window(kept: await loaded());
    reopened.sweep();
    await reopened.idle;
    final (_, again) = window(kept: await loaded());
    again.sweep();
    await again.idle;

    expect(planner.calls.map((call) => (call.event, call.offer)), [
      (PlanningTaskEvent.started, order.offer),
      (PlanningTaskEvent.ended, order.offer),
    ]);
  });

  // Harm: a task some other caller started is reported under an offer of this window.
  test('a listed task whose key names no offer this window handed is not reported', () async {
    final (_, reports) = window();
    machine.listed.add(
      Task.from({'name': 'porelo-demo-other', 'task': 'other', 'project': 'demo', 'running': true, 'callerKey': 'x'}),
    );

    reports.sweep();
    await reports.idle;

    expect(planner.calls, isEmpty);
  });

  // Harm: the planner's next task is never started, or started twice when a later answer or a restart carries it again.
  test('a follow-up order is started once, for the project and story it came for, and shown', () async {
    final (starts, reports) = window();
    final orders = await plannedOrders();
    final followUp = _followUp(1);
    planner.answers.addAll([
      // To the screen's task's start: the follow-up, started.
      _answer([followUp]),
      // To the follow-up's own start: nothing.
      _answer(const []),
      // To the screen's task's end: the same offer again, not started again.
      _answer([followUp]),
    ]);
    final started = await starts(planner, 'demo', 'ST291', orders.first);
    await reports.idle;
    machine.end(started.container, {'at': 'the end', 'finished': true});
    reports.sweep();
    await reports.idle;
    expect(planner.calls.map((call) => (call.event, call.offer)), [
      (PlanningTaskEvent.started, orders.first.offer),
      (PlanningTaskEvent.started, followUp['offer']),
      (PlanningTaskEvent.ended, orders.first.offer),
    ], reason: 'each answer went to the report it was meant for');

    // After a restart, an answer carrying it once more.
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

    expect(planner.answers, isEmpty, reason: 'every answer was given');
    expect(machine.started.map((each) => each['repository']), [orders.first.repository, 'builder-one']);
    expect(shown.map((each) => (each.$1, each.$2, each.$3.single.$1.offer)), [('demo', 'ST291', followUp['offer'])]);
  });

  // Harm: the follow-ups after a refused one start anyway, a refused one is tried again, or the refusal goes unsaid.
  test('a refused follow-up stops the rest of the answer\'s orders, says why and is not tried again', () async {
    final (starts, reports) = window();
    final problems = <String>[];
    reports.onProblem = (provider, project, error) => problems.add(planningFailureWords(error));
    final orders = [_followUp(1), _followUp(2, repository: 'builder-two')];
    planner.answers.add(_answer(orders));
    final started = await starts(planner, 'demo', 'ST291', (await plannedOrders()).first);
    machine.refuseNext = 'porelo: the vault is locked';

    await reports.idle;

    expect(machine.started, hasLength(1), reason: 'only the order the screen started');
    expect(problems.single, contains('porelo: the vault is locked'));
    expect(shown, isEmpty);

    // The end's answer carries both again: the refused one was handed to Start and is not, the other one is.
    planner.answers.add(_answer(orders));
    machine.end(started.container, {'at': 'the end', 'finished': true});
    reports.sweep();
    await reports.idle;

    expect(machine.started.skip(1).map((each) => each['repository']), ['builder-two']);
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
      // A window of its own for each name: an offer handed to Start once is never started again.
      store = MemorySettingsStore();
      settings = await loaded();
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

  // Harm: the planner is told a task started twice, so it counts one run as two.
  test('a start the sweep reported while its own report waited is not reported again', () async {
    final (starts, reports) = window();
    final order = (await plannedOrders()).first;
    planner.answers.add(_answer([_followUp(1)]));
    // The follow-up's start lists the machine's tasks while the report that ordered it is still sent: the machine
    // changes meanwhile, and a sweep waits behind that report.
    machine.whileListing = (listing) async {
      if (listing == 2) reports.sweep();
    };

    await starts(planner, 'demo', 'ST291', order);
    await reports.idle;

    final starting = planner.calls.where((call) => call.event == PlanningTaskEvent.started).map((call) => call.offer);
    expect(starting, [order.offer, _followUp(1)['offer']]);
  });

  // Harm: a task started again in the container of a stopped one is never reported, so its story looks idle.
  test('a new offer in the container of a stopped task is reported', () async {
    final (starts, reports) = window();
    final first = (await plannedOrders()).first;
    final started = await starts(planner, 'demo', 'ST291', first);
    await reports.idle;
    await reports.stop(planner, 'demo', 'ST291', [started]);
    await reports.idle;

    final again = _order(_followUp(1, repository: first.repository!));
    final restarted = await starts(planner, 'demo', 'ST291', again);
    await reports.idle;

    expect(restarted.container, started.container);
    expect(planner.calls.map((call) => (call.event, call.offer)), [
      (PlanningTaskEvent.started, first.offer),
      (PlanningTaskEvent.started, again.offer),
    ]);
  });

  // Harm: an end that came while the planner was not reached is never told, so the story looks at work for ever.
  test('a start and an end that came while the planner was not reached are both told once it is', () async {
    var reached = false;
    final (starts, reports) = window(reached: () => reached);
    final started = await starts(planner, 'demo', 'ST291', (await plannedOrders()).first);
    await reports.idle;
    machine.end(started.container, {'at': 'the end', 'finished': true});

    reached = true;
    reports.sweep();
    await reports.idle;

    expect(planner.calls.map((call) => call.event), [PlanningTaskEvent.started, PlanningTaskEvent.ended]);
  });

  // Harm: a follow-up of a task the planner voided by a stop runs for a story that was stopped.
  test('a stop while a report waits for its answer starts none of the answer\'s follow-ups', () async {
    final (starts, reports) = window();
    planner.hold = Completer<void>();
    planner.answers.add(_answer([_followUp(1)]));
    final started = await starts(planner, 'demo', 'ST291', (await plannedOrders()).first);
    await pumpEventQueue();
    expect(planner.calls, hasLength(1), reason: 'the start\'s report waits for its answer');

    await reports.stop(planner, 'demo', 'ST291', [started]);
    planner.hold!.complete();
    await reports.idle;

    expect(machine.started, hasLength(1), reason: 'only the task the screen started');
    expect(shown, isEmpty);
  });

  // Harm: a task just started is said to go unreported, so the person stops or redoes work the planner is told of.
  test('a sweep while a start waits for the machine\'s list says nothing of an earlier build', () async {
    final (starts, reports) = window();
    final problems = <String>[];
    reports.onProblem = (provider, project, error) => problems.add(planningFailureWords(error));
    machine.whileListing = (_) async {
      reports.sweep();
      await reports.idle;
    };

    await starts(planner, 'demo', 'ST291', (await plannedOrders()).first);
    await reports.idle;

    expect(problems, isEmpty);
    expect(planner.calls.map((call) => call.event), [PlanningTaskEvent.started]);
  });

  // Harm: a report refused only because no watched machine had named the project's repository yet is never sent.
  group('an ended discussion', () {
    const idea = {
      'story': {'title': 'Night lights', 'gain': 'Less glare.', 'test': 'The lights dim.', 'priority': 3},
      'issues': [
        {'repository': 'porelo', 'title': 'Dim the lights', 'mustBeTrue': 'The lights dim.', 'worker': 'Agent'},
      ],
    };
    final ideaFile = {'name': 'idea.json', 'state': 'handed', 'bytes': 10};

    Map<String, dynamic> endAt(String at, {Map<String, Object>? result}) => {
      'at': at,
      'finished': true,
      'result': ?result,
    };

    Future<(WindowTaskReports, List<String>, List<String>)> discussed({
      Settings? kept,
      DateTime Function()? now,
    }) async {
      final (starts, reports) = window(kept: kept, now: now);
      final problems = <String>[], saved = <String>[];
      reports.onProblem = (provider, project, error) =>
          problems.add('$provider $project ${planningFailureWords(error)}');
      reports.onIdeaHanded = (discussion, story) => saved.add('${discussion.project} $story');
      await starts(planner, 'demo', '', discussionOrder());
      await reports.idle;
      return (reports, problems, saved);
    }

    Future<void> sweeps(WindowTaskReports reports) async {
      for (var change = 0; change < 3; change++) {
        reports.sweep();
        await reports.idle;
      }
    }

    // Harm: the idea a person agreed on is lost, handed twice, handed with another offer, or handed again after a
    // restart as a second story.
    test('hands its idea once, with its offer, and says the story it was saved as', () async {
      final (reports, problems, saved) = await discussed();
      results['porelo-demo-discussion'] = TaskResult.from({...ideaFile, 'content': jsonEncode(idea)});
      machine.end('porelo-demo-discussion', endAt('2026-11-12T01:00:00Z', result: ideaFile));

      await sweeps(reports);
      expect(handed.map((each) => (each.$1, each.$2)), [('demo', discussionOrder().offer)]);
      expect(handed.single.$3, idea);
      expect(saved, ['demo ST900']);
      expect(problems, isEmpty);
      expect(planner.calls, isEmpty, reason: 'a discussion is no story\'s task');

      final (_, again) = window(kept: await loaded());
      await sweeps(again);
      expect(handed, hasLength(1));

      // Kept no longer than its task: a removed task's discussion is forgotten.
      await settings.forgetPlanningOffer('laptop', 'porelo-demo-discussion');
      expect((await loaded()).keptDiscussions, isEmpty);
    });

    // Harm: a discussion is removed with ideas it proposed that were never handed in, and they are lost with it.
    test('stays while an idea it proposed waits to be handed in', () async {
      final (reports, _, saved) = await discussed();
      results['porelo-demo-discussion'] = TaskResult.from({...ideaFile, 'content': jsonEncode(idea)});
      machine.end('porelo-demo-discussion', endAt('2026-11-12T01:00:00Z', result: ideaFile));
      final index = machine.listed.indexWhere((task) => task.name == 'porelo-demo-discussion');
      final row = machine.listed[index];
      machine.listed[index] = Task.from({
        'name': row.name,
        'task': row.task,
        'project': 'demo',
        'running': false,
        'run': row.run!,
        'agentEnded': endAt('2026-11-12T01:00:00Z', result: ideaFile),
        'ideas': [
          {'id': 'idea-1', 'title': 'A side idea', 'whatMustBeTrue': 'It waits for its repository.', 'at': 'T'},
        ],
      });

      await sweeps(reports);

      expect(saved, ['demo ST900']);
      expect(removed, isEmpty);
    });

    // Harm: ideas the machine's listing left out for room are lost with a discussion removed once the listed ones were
    // handed in.
    test('stays while the listing holds back ideas it proposed', () async {
      final (reports, _, saved) = await discussed();
      results['porelo-demo-discussion'] = TaskResult.from({...ideaFile, 'content': jsonEncode(idea)});
      machine.end('porelo-demo-discussion', endAt('2026-11-12T01:00:00Z', result: ideaFile));
      final index = machine.listed.indexWhere((task) => task.name == 'porelo-demo-discussion');
      final row = machine.listed[index];
      machine.listed[index] = Task.from({
        'name': row.name,
        'task': row.task,
        'project': 'demo',
        'running': false,
        'run': row.run!,
        'agentEnded': endAt('2026-11-12T01:00:00Z', result: ideaFile),
        'ideas': <Object>[],
        'ideasHeldBack': 2,
      });

      await sweeps(reports);
      expect(saved, ['demo ST900']);
      expect(removed, isEmpty, reason: 'two of its ideas were not listed yet');
    });

    // Harm: an ended discussion stays on the machine after its idea was saved, or one whose idea was not saved goes,
    // and the person's agreed idea with it.
    test('removes the ended discussion once the planner saved its idea, and keeps one it did not', () async {
      final (reports, _, saved) = await discussed();
      results['porelo-demo-discussion'] = TaskResult.from({...ideaFile, 'content': jsonEncode(idea)});
      handAnswers.addAll([
        const IdeaNotSaved('The idea does not follow the idea format.', faults: ['story.title: Too long.']),
        const IdeaNotSaved('no planner is running for this account', transient: true),
        'ST902',
      ]);
      machine.end('porelo-demo-discussion', endAt('1', result: ideaFile));
      await sweeps(reports);
      expect(removed, isEmpty, reason: 'its idea was refused for its faults');

      machine.end('porelo-demo-discussion', endAt('2', result: ideaFile));
      await sweeps(reports);
      expect(saved, ['demo ST902']);
      expect(removed, [('laptop', 'porelo-demo-discussion')]);
    });

    // Harm: the idea of a discussion the person left is never handed in, since an attended session records no agent
    // end; or it is handed while the session still runs, or twice.
    test('hands the idea of a discussion whose session was left, once, by its result alone', () async {
      final (reports, problems, saved) = await discussed();
      results['porelo-demo-discussion'] = TaskResult.from({...ideaFile, 'content': jsonEncode(idea)});
      machine.leave('porelo-demo-discussion', ideaFile);

      await sweeps(reports);
      expect(handed.map((each) => each.$3), [idea]);
      expect(saved, ['demo ST900']);
      expect(problems, isEmpty);
      expect(removed, [('laptop', 'porelo-demo-discussion')]);
    });

    // Harm: a left discussion that wrote no idea says nothing, and the person waits for a story that never comes.
    test('says once that a discussion whose session was left wrote no idea', () async {
      var at = DateTime.utc(2026, 11, 13, 3);
      final (reports, problems, _) = await discussed(now: () => at);
      machine.leave('porelo-demo-discussion', {'name': 'idea.json', 'state': 'missing'});

      await sweeps(reports);
      at = at.add(const Duration(minutes: 1));
      await sweeps(reports);
      expect(handed, isEmpty);
      expect(problems, [
        'porelo-planner demo The discussion porelo-demo-discussion ended with no idea to hand to the planner: it '
            'wrote no idea.json.',
      ]);
    });

    // Harm: a discussion listed after its container was made, before its task started, shows as left with no result;
    // taken as its end, the idea the person agrees on afterwards is never handed in, and the planner waits for good.
    test('a left discussion whose result is missing is looked at again before it is said to have none', () async {
      var at = DateTime.utc(2026, 11, 13, 3);
      final (reports, problems, saved) = await discussed(now: () => at);
      machine.leave('porelo-demo-discussion', {'name': 'idea.json', 'state': 'missing'});

      await sweeps(reports);
      at = at.add(const Duration(seconds: 59));
      await sweeps(reports);
      expect(problems, isEmpty, reason: 'a result read before the task started is missing for a while');

      results['porelo-demo-discussion'] = TaskResult.from({...ideaFile, 'content': jsonEncode(idea)});
      machine.leave('porelo-demo-discussion', ideaFile);
      await sweeps(reports);
      expect(handed.map((each) => each.$3), [idea]);
      expect(saved, ['demo ST900']);
      expect(problems, isEmpty);
    });

    // Harm: why an idea was not handed in is shown on the board alone; once the board is gone, nothing tells it.
    test('what is said of an idea is written to the window\'s log too', () async {
      final logs = Directory(
        '${Directory.systemTemp.path}/porelo-reports-logs-${DateTime.now().microsecondsSinceEpoch}',
      )..createSync();
      final before = windowLog;
      windowLog = WindowLog(logs.path, level: ValueNotifier(LogLevel.debug), keepPrivate: (_) async {});
      addTearDown(() {
        windowLog = before;
        logs.deleteSync(recursive: true);
      });
      var at = DateTime.utc(2026, 11, 13, 3);
      final (reports, problems, _) = await discussed(now: () => at);
      machine.leave('porelo-demo-discussion', {'name': 'idea.json', 'state': 'missing'});

      await sweeps(reports);
      at = at.add(const Duration(minutes: 1));
      await sweeps(reports);
      expect(problems, hasLength(1));
      final log = File('${logs.path}/${WindowLog.fileName}');
      expect(
        log.existsSync() ? log.readAsStringSync() : '',
        contains('The discussion porelo-demo-discussion ended with no idea to hand to the planner'),
      );
    });

    // Harm: an idea an earlier run of the container wrote is handed in as this discussion's, under its offer.
    test('an end the discussion showed when it started hands nothing', () async {
      machine.endBeforeStart = endAt('0', result: ideaFile);
      results['porelo-demo-discussion'] = TaskResult.from({...ideaFile, 'content': jsonEncode(idea)});
      final (reports, problems, _) = await discussed();

      await sweeps(reports);
      expect(handed, isEmpty);
      expect(problems, isEmpty);
    });

    // Harm: a discussion that ended without an idea, or before the window watched it, hands something else or nothing
    // is said, or the same line comes on every change of a machine.
    test('one that left no idea, or no JSON object, hands nothing and says why once', () async {
      final (reports, problems, _) = await discussed();
      machine.end('porelo-demo-discussion', endAt('1', result: {'name': 'idea.json', 'state': 'missing'}));
      await sweeps(reports);
      results['porelo-demo-discussion'] = TaskResult.from({...ideaFile, 'content': '[1, 2]'});
      machine.end('porelo-demo-discussion', endAt('2', result: ideaFile));
      await sweeps(reports);

      expect(handed, isEmpty);
      expect(problems, [
        'porelo-planner demo The discussion porelo-demo-discussion ended with no idea to hand to the planner: it '
            'wrote no idea.json.',
        'porelo-planner demo The discussion porelo-demo-discussion ended with no idea to hand to the planner: '
            'idea.json holds no JSON object.',
      ]);
    });

    // Harm: the planner's faults never reach the person, a refused idea is sent again and again, or a planner not
    // running loses the idea for good.
    test('a refused idea says its faults once; one the planner could not take yet goes once it can', () async {
      final (reports, problems, saved) = await discussed();
      results['porelo-demo-discussion'] = TaskResult.from({...ideaFile, 'content': jsonEncode(idea)});
      handAnswers.addAll([
        const IdeaNotSaved('no planner is running for this account', transient: true),
        const IdeaNotSaved('no planner is running for this account', transient: true),
        'ST901',
        const IdeaNotSaved('The idea does not follow the idea format.', faults: ['story.title: Too long.']),
      ]);
      machine.end('porelo-demo-discussion', endAt('1', result: ideaFile));
      await sweeps(reports);
      expect(saved, ['demo ST901']);

      machine.end('porelo-demo-discussion', endAt('2', result: ideaFile));
      await sweeps(reports);
      expect(handed, hasLength(4));
      expect(problems, [
        'porelo-planner demo The idea of the discussion porelo-demo-discussion is not handed in yet: no planner is '
            'running for this account',
        'porelo-planner demo The planner did not save the idea of the discussion porelo-demo-discussion: The idea '
            'does not follow the idea format. story.title: Too long. Its result file stays in the task.',
      ]);
    });
  });

  group('an idea a task proposed', () {
    /// The task [container] on the machine as it lists it, with [ideas] proposed, of [run].
    void lists(String container, List<Map<String, Object>> ideas, {String run = 'run-1', String repository = 'shop'}) {
      machine.listed.removeWhere((task) => task.name == container);
      machine.listed.add(
        Task.from({
          'name': container,
          'task': 'pi',
          'project': 'demo',
          'repository': repository,
          'running': true,
          'run': run,
          'ideas': ideas,
        }),
      );
    }

    Map<String, Object> idea(int number, {String? title, String? text}) => {
      'id': 'idea-$number',
      'title': title ?? 'Idea $number',
      'whatMustBeTrue': text ?? 'What idea $number makes true.',
      'at': '2026-11-13T00:0$number:00Z',
    };

    Future<WindowTaskReports> swept([WindowTaskReports? reports]) async {
      final (_, sweeping) = reports == null ? window() : (null, reports);
      sweeping.sweep();
      await sweeping.idle;
      return sweeping;
    }

    late List<String> problems;

    setUp(() => problems = []);

    WindowTaskReports said(WindowTaskReports reports) =>
        reports
          ..onProblem = (provider, project, error) => problems.add('$provider $project ${planningFailureWords(error)}');

    // Harm: an idea a task proposed never reaches the board, reaches it twice, or lands in another repository.
    test('is handed once, as the task wrote it, into the task\'s repository, also across a restart', () async {
      lists('porelo-demo-pi', [idea(1)]);

      final reports = await swept();
      await swept(reports);
      await swept(window(kept: await loaded()).$2);

      expect(planner.issues.map((issue) => issue.toString()), [
        '(demo, shop, Idea 1, What idea 1 makes true., null, r7)',
      ]);
      expect(planner.boardsRead, ['demo']);

      lists('porelo-demo-pi', [idea(1), idea(2)]);
      await swept(reports);

      expect(planner.issues.map((issue) => issue.$3), ['Idea 1', 'Idea 2']);
    });

    // Harm: a later task under a removed task's container name has its own ideas taken for those already handed.
    test('of a later task under the same container is its own', () async {
      lists('porelo-demo-pi', [idea(1)]);
      final reports = await swept();

      lists('porelo-demo-pi', [idea(1)], run: 'run-2');
      await swept(reports);

      expect(planner.issues.map((issue) => issue.$3), ['Idea 1', 'Idea 1']);
    });

    // Harm: the planner's issue does not name the task an idea came from, so nobody knows whom to ask.
    test('reaches the planner naming the task it came from', () async {
      lists('porelo-demo-pi', [idea(1)]);

      await swept();

      expect(planner.tasksNamed, ['pi']);
    });

    // Harm: a task's name the planner would refuse holds its idea back at every start of the window.
    test('reaches the planner without a task name the planner does not take', () async {
      final (_, reports) = window(
        handIssue: (source, project, issue) => issueFromIdea(
          source,
          project,
          ProposedIssue(
            repository: issue.repository,
            title: issue.title,
            mustBeTrue: issue.mustBeTrue,
            revision: issue.revision,
            task: '-not a name',
          ),
        ),
      );
      lists('porelo-demo-pi', [idea(1)]);

      await swept(reports);

      expect(planner.issues.map((issue) => issue.$3), ['Idea 1']);
      expect(planner.tasksNamed, [null]);
    });

    // Harm: the task an idea came from is not handed with it, so nobody knows whom to ask.
    test('is handed with the name of the task it came from', () async {
      final named = <String>[];
      final (_, reports) = window(
        handIssue: (source, project, issue) {
          named.add(issue.task);
          return issueFromIdea(source, project, issue);
        },
      );
      lists('porelo-demo-pi', [idea(1)]);

      await swept(reports);

      expect(named, ['pi']);
    });

    // Harm: an idea is lost because the board moved on while it was handed.
    test('is read against the board again and sent once more when the board moved on', () async {
      planner.issueAnswers.add(const PlanningRefusal('StaleRevision', {}, 'The board changed.'));
      lists('porelo-demo-pi', [idea(1)]);

      await swept();

      expect(planner.issues.map((issue) => issue.$3), ['Idea 1', 'Idea 1']);
      expect(planner.boardsRead, ['demo', 'demo']);
    });

    // Harm: an idea proposed while no planner answers is lost, its successor overtakes it, or the person is told of
    // it on every change of a machine.
    test('waits, in order, while no planner is reached, said once, and goes once one is', () async {
      var reached = false;
      final (_, reports) = window(reached: () => reached);
      said(reports);
      lists('porelo-demo-pi', [idea(1), idea(2)]);
      await swept(reports);
      await swept(reports);

      expect(planner.issues, isEmpty);
      expect(problems, hasLength(1));

      reached = true;
      planner.issueAnswers.add(const PlanningRefusal('PlannerUnreachable', {}, 'The planner cannot be reached.'));
      await swept(reports);
      expect(planner.issues.map((issue) => issue.$3), ['Idea 1']);

      await swept(reports);
      expect(planner.issues.map((issue) => issue.$3), ['Idea 1', 'Idea 1', 'Idea 2']);
      expect(problems, hasLength(1));
    });

    // Harm: an idea the planner refused for its fields is sent again on every change of a machine, or its refusal is
    // never said.
    test('the planner refuses is said once with its words and not sent again, also across a restart', () async {
      planner.issueAnswers.add(
        const PlanningRefusal('IssueNotAllowed', {'field': 'title', 'reason': 'title: Too long.'}, 'title: Too long.'),
      );
      lists('porelo-demo-pi', [idea(1), idea(2)]);
      final reports = said(window().$2);

      await swept(reports);
      await swept(reports);
      await swept(said(window(kept: await loaded()).$2));

      expect(planner.issues.map((issue) => issue.$3), ['Idea 1', 'Idea 2']);
      expect(problems, hasLength(1));
      expect(problems.single, contains('title: Too long.'));
    });

    // Harm: an idea is lost because the planner could not save it once for a reason of its own, not of the idea.
    test('the planner could not save is said once and tried again, first, at the next start of the window', () async {
      for (final refusal in const [
        PlanningRefusal('CredentialRefused', {}, 'The forge refused the token.'),
        PlanningRefusal('IssueNotAllowed', {'field': '', 'reason': 'The repository\'s issues give no prefix.'}),
      ]) {
        planner.issues.clear();
        problems.clear();
        planner.issueAnswers.add(refusal);
        final container = 'porelo-demo-${refusal.name}';
        lists(container, [idea(1), idea(2)]);
        final reports = said(window().$2);

        await swept(reports);
        await swept(reports);
        expect(planner.issues.map((issue) => issue.$3), ['Idea 1'], reason: refusal.name);
        expect(problems, hasLength(1), reason: refusal.name);

        await swept(window(kept: await loaded()).$2);
        expect(planner.issues.map((issue) => issue.$3), ['Idea 1', 'Idea 1', 'Idea 2'], reason: refusal.name);
        machine.listed.removeWhere((task) => task.name == container);
      }
    });

    // Harm: a task's agent puts words the planner never checks, or lines of its own, into the window's problems, or
    // floods the board past what Porelo allows a task.
    test('out of the bounds Porelo states is never handed or quoted, and said once', () async {
      final bad = [
        idea(1, title: 'Two\nlines'),
        idea(2, title: 'x' * 121),
        idea(3, text: 'y' * 1001),
        idea(4, text: 'A bell \u0007 rings.'),
        idea(5, title: ' '),
        {...idea(6), 'id': 'idea-6\nforged'},
        idea(7, text: ''),
      ];
      lists('porelo-demo-pi', [...bad, idea(8, title: 'x' * 120, text: 'Two\nlines, ${'y' * 980}')]);
      final reports = said(window().$2);

      await swept(reports);
      await swept(reports);
      await swept(said(window(kept: await loaded()).$2));

      expect(planner.issues.map((issue) => issue.$3), ['x' * 120]);
      expect(problems, hasLength(bad.length));
      expect(problems.join(), isNot(contains('Two\nlines')));
      expect(problems.join(), isNot(contains('\u0007')));
      expect(problems.join(), isNot(contains('forged')));
    });

    // Harm: a task the planner voided, stopped but not removed, has its handed ideas sent again as new issues.
    test('of a task the planner voided is not handed again', () async {
      final (starts, reports) = window();
      final started = await starts(planner, 'demo', 'ST291', (await plannedOrders()).first);
      await reports.idle;
      final row = machine.listed.singleWhere((task) => task.name == started.container);
      machine.listed[machine.listed.indexOf(row)] = Task.from({
        'name': row.name,
        'task': row.task,
        'project': 'demo',
        'repository': 'shop',
        'running': false,
        'run': row.run!,
        'ideas': [idea(1)],
      });
      await swept(reports);
      expect(planner.issues, hasLength(1));

      planner.answers.add(const PlanningRefusal('TaskNotAnswered', {}, 'The planner no longer answers for this task.'));
      final ended = machine.listed.indexWhere((task) => task.name == started.container);
      machine.listed[ended] = Task.from({
        'name': row.name,
        'task': row.task,
        'project': 'demo',
        'repository': 'shop',
        'running': false,
        'run': row.run!,
        'agentEnded': {'at': 'the end', 'finished': true},
        'ideas': [idea(1)],
      });
      await swept(reports);
      await swept(window(kept: await loaded()).$2);

      expect(stopped, [(_laptop, started.container)]);
      expect(planner.issues, hasLength(1));
    });

    // Harm: an idea is handed into a repository nobody named, or lost while no machine names its repository yet.
    test('waits while no watched machine names its repository, and goes once one does', () async {
      lists('porelo-demo-pi', [idea(1)], repository: '');
      final reports = said(window().$2);
      await swept(reports);
      await swept(reports);

      expect(planner.issues, isEmpty);
      expect(problems, hasLength(1));

      lists('porelo-demo-pi', [idea(1)]);
      await swept(reports);

      expect(planner.issues.map((issue) => issue.$2), ['shop']);
    });

    // Harm: the marks of removed tasks grow without bound in the settings every window rewrites.
    test('a removed task\'s marks go with it', () async {
      lists('porelo-demo-pi', [idea(1)]);
      lists('porelo-demo-ui', [idea(1)]);
      await swept();
      expect(jsonEncode(await store.read()), allOf(contains('porelo-demo-pi'), contains('porelo-demo-ui')));

      await settings.forgetRemovedTask('laptop', 'porelo-demo-pi');

      expect(jsonEncode(await store.read()), allOf(isNot(contains('porelo-demo-pi')), contains('porelo-demo-ui')));
    });
  });

  test('a report refused for want of the project\'s repository goes once a machine names it', () async {
    final (starts, reports) = window();
    planner.answers.add(const PlanningRefusal('NoRepository', {}, 'No watched machine names demo\'s repository.'));
    await starts(planner, 'demo', 'ST291', (await plannedOrders()).first);
    await reports.idle;

    reports.sweep();
    await reports.idle;

    expect(planner.calls.map((call) => call.event), [PlanningTaskEvent.started, PlanningTaskEvent.started]);
  });
}

/// The planner's order [followUp], as an answer carries it.
PlanningTaskOrder _order(Map<String, dynamic> followUp) => TaskEventResolution.from(_answer([followUp])).tasks.single;

/// A follow-up order of the planner, a builder of B540 in [repository].
Map<String, dynamic> _followUp(
  int number, {
  String repository = 'builder-one',
  String role = 'BUILDER',
  List<String>? reads,
}) => {
  'offer': '00000000-0000-4000-8000-${'$number'.padLeft(12, '0')}',
  'repository': repository,
  'issues': ['B540'],
  'role': role,
  'reads': ?reads,
  'agent': 'codex',
  'model': 'a-model',
  'mode': 'UNATTENDED',
  'prompt': 'Build B540.',
};

/// Where a build's work landed, as Porelo's row names it.
const _landing = <String, dynamic>{
  'branch': 'porelo/foo-1',
  'ref': 'refs/porelo/landed/foo-1/porelo/foo-1',
  'remote': 'origin/landed/foo-1/porelo/foo-1',
  'commit': 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
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
  List<PlanningLanding> landed,
});

/// A provider's source that records each report and answers what a test queued, an empty answer when none is.
class _Planner extends Fake implements PlanningSource {
  final calls = <_Call>[];
  final answers = <Object>[];

  /// Each new issue asked for: project, repository, title, what must be true, size and revision.
  final issues = <(String, String, String, String, String?, String)>[];

  /// The task each issue was handed with, in the order of [issues].
  final tasksNamed = <String?>[];

  /// What the next new issues are answered, an id when nothing is queued.
  final issueAnswers = <Object>[];

  /// The projects whose board was read, in order.
  final boardsRead = <String>[];

  @override
  Future<PlanningSnapshot> stories(String project) async {
    boardsRead.add(project);
    return PlanningSnapshot.from({'revision': 'r7', 'stories': <Object>[]});
  }

  @override
  Future<PlanningIssueAdded> createIssue(
    String project,
    String repository,
    String title,
    String mustBeTrue,
    String? size,
    String revision, {
    IssueWorker worker = IssueWorker.agent,
    String? task,
  }) async {
    issues.add((project, repository, title, mustBeTrue, size, revision));
    tasksNamed.add(task);
    final next = issueAnswers.isEmpty ? null : issueAnswers.removeAt(0);
    if (next is Exception) throw next;
    return PlanningIssueAdded(id: 'F${900 + issues.length}', revision: 'r8');
  }

  /// Held until completed: the answer a report waits for meanwhile.
  Completer<void>? hold;

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
    List<PlanningLanding> landed = const [],
  }) async {
    calls.add((
      project: project,
      task: task,
      event: event,
      offer: offer,
      container: container,
      machine: machine,
      ended: ended,
      landed: landed,
    ));
    await hold?.future;
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

  /// Start answers, but the window ends before it hears it: the call never returns.
  bool hangAfterStart = false;

  /// Runs before each listing of the tasks is answered, numbered from 1: what the window does meanwhile.
  Future<void> Function(int listing)? whileListing;
  int _listings = 0;

  /// The attended session of [container] was left, as [result] stood: no agent end is recorded for one.
  void leave(String container, Map<String, Object> result, {String since = '1'}) {
    final index = listed.indexWhere((task) => task.name == container);
    final task = listed[index];
    listed[index] = Task.from({
      'name': task.name,
      'task': task.task,
      'project': task.project,
      'running': false,
      'since': since,
      'result': result,
      'callerKey': ?_keyOf(task),
    });
  }

  /// The agent of [container] ended as [ended] says, its work landed where [landed] says.
  void end(String container, Map<String, dynamic> ended, {List<Map<String, dynamic>>? landed}) {
    final index = listed.indexWhere((task) => task.name == container);
    final task = listed[index];
    listed[index] = Task.from({
      'name': task.name,
      'task': task.task,
      'project': task.project,
      'running': false,
      'run': ?task.run,
      'agentEnded': ended,
      'landed': ?landed,
      'callerKey': ?_keyOf(task),
    });
  }

  /// The key [task]'s start gave it, which the machine keeps through every change of the task.
  static String? _keyOf(Task task) => task.callerKey.isEmpty ? null : task.callerKey;

  /// The ended task in [container]'s work has left the gate for [landed].
  void land(String container, List<Map<String, dynamic>> landed) {
    final index = listed.indexWhere((task) => task.name == container);
    final task = listed[index];
    listed[index] = Task.from({
      'name': task.name,
      'task': task.task,
      'project': task.project,
      'running': false,
      'run': ?task.run,
      'agentEnded': {
        'at': task.agentEnded!.at,
        'finished': task.agentEnded!.finished,
        'answer': task.agentEnded!.lastAnswer,
      },
      'landed': landed,
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
    String? callerKey,
    List<String> reads = const [],
  }) async {
    if (refuseNext case final words?) {
      refuseNext = null;
      return StartProgress(exitCode: 1, output: [words]);
    }
    started.add({'project': project, 'repository': repository, 'callerKey': ?callerKey, 'reads': reads});
    final container = 'porelo-$project-$repository';
    listed.removeWhere((task) => task.name == container);
    listed.add(
      Task.from({
        'name': container,
        'task': repository,
        'project': project,
        'running': true,
        'run': 'run-${started.length}',
        'callerKey': ?callerKey,
        'agentEnded': ?endBeforeStart,
      }),
    );
    if (hangAfterStart) await Completer<void>().future;
    return StartProgress(container: container, exitCode: 0, action: StartAction.create);
  }

  @override
  Future<String?> whyNoDiscussion() async => null;

  @override
  Future<StartProgress> startDiscussion({
    required String project,
    required String agent,
    required String model,
    required Mode mode,
    required String prompt,
    required String result,
    String? callerKey,
  }) async {
    final container = 'porelo-$project-discussion';
    listed.removeWhere((task) => task.name == container);
    listed.add(
      Task.from({
        'name': container,
        'task': 'discussion',
        'project': project,
        'running': true,
        'run': 'run-${started.length}',
        'callerKey': ?callerKey,
        'agentEnded': ?endBeforeStart,
      }),
    );
    return StartProgress(container: container, exitCode: 0, action: StartAction.create);
  }

  @override
  Future<List<Task>> tasks() async {
    await whileListing?.call(++_listings);
    return List.of(listed);
  }
}
