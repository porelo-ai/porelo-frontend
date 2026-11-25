import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/planner.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/ui/planning_embedding.dart';
import 'package:porelo_frontend/src/ui/planning_reports.dart';
import 'package:porelo_planning/porelo_planning.dart';

import 'package:porelo_frontend/src/app/planner_stage_results.dart';

import 'window_task_starts_test.dart' show discussionOrder, plannedOrders;

const _laptop = Machine(name: 'laptop', socketPath: '/run/laptop.sock');
const _provider = 'porelo-planner';
const _laterDiscussion = '00000000-0000-4000-8000-00000000d15d';

void main() {
  late MemorySettingsStore store;
  late Settings settings;
  late _Machine machine;
  late _Planner planner;
  late List<(Machine, String)> stopped;
  late Object? stopFails;
  late List<(String, String, List<(PlanningTaskOrder, PlanningTaskStarted)>)> shown;
  late Map<String, TaskResult> results;
  late List<(String, String, String, Map<String, Object?>?, String?)> stageResults;
  late List<Object> stageAnswers;

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
    DateTime Function()? now,
    Future<void> Function()? waitForOutcome,
    bool Function()? listed,
    TellRefused? tellRefused,
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
      waitForOutcome: waitForOutcome ?? () async {},
      sourceNamed: (name) => name == _provider && (reached?.call() ?? true) ? planner : null,
      tasksOn: (name) => name == on.name && (listed?.call() ?? true) ? machine.listed : null,
      stopOn: (machine, container) async {
        if (stopFails case final error?) {
          stopFails = null;
          throw error;
        }
        stopped.add((machine, container));
      },
      resultOf: (name, container) async =>
          name == on.name ? results[container] ?? fail('no result for $container') : fail('$name is not watched'),
      handResult: (project, task, offer, {result, missing, runtimeDirectory, projects}) async {
        stageResults.add((project, task, offer, result, missing));
        if (stageAnswers.isNotEmpty) throw stageAnswers.removeAt(0);
      },
      now: now ?? DateTime.now,
      tellRefused: tellRefused ?? planner.told,
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
    stopFails = null;
    shown = [];
    results = {};
    stageResults = [];
    stageAnswers = [];
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

  // Harm: the planner holds an offer started that Porelo refused, and its story waits for an end that never comes.
  test('a start Porelo refused is reported once as refused, in its own name and words', () async {
    final (starts, reports) = window();
    final order = (await plannedOrders()).first;
    machine.throwNext = const VarlinkException('org.fuin.porelo.Tasks1.RoleNotAllowed', {
      'role': 'REVIEWER',
      'place': {'pullRequest': 'https://forge.example/o/r/pull/7'},
    });

    await expectLater(starts(planner, 'demo', 'ST291', order), throwsA(isA<PlanningRefusal>()));
    await reports.idle;
    reports.sweep();
    await reports.idle;

    final told = planner.refusedTold.single;
    expect(
      (told.offer, told.machine, told.provider, told.project, told.story, told.task, told.name),
      (order.offer, 'laptop', _provider, 'demo', 'ST291', order.repository, 'RoleNotAllowed'),
    );
    expect(told.parameters, {'role': 'REVIEWER', 'place': '{"pullRequest":"https://forge.example/o/r/pull/7"}'});
    expect(told.detail, contains('laptop'));
    expect(planner.calls, isEmpty, reason: 'no task stands to be reported started');
    expect((await loaded()).refusedStarts, isEmpty, reason: 'the planner took it');
  });

  // Harm: a refusal told while the planner was not reached is lost, or told again after the planner took it.
  test('a refused start not taken is kept across a restart and told until the planner takes it', () async {
    var reached = false;
    final (starts, reports) = window(reached: () => reached);
    final order = (await plannedOrders()).first;
    machine.throwNext = const VarlinkException('org.fuin.porelo.Tasks1.UnknownForge', {'host': 'forge.example'});

    await expectLater(starts(planner, 'demo', 'ST291', order), throwsA(isA<PlanningRefusal>()));
    await reports.idle;
    expect(planner.refusedTold, isEmpty);
    expect((await loaded()).refusedStarts.single.name, 'UnknownForge');

    reached = true;
    planner.refusedAnswers.add(const PlanningRefusal('TimedOut', {}, 'The planner did not answer in time.'));
    final (_, reopened) = window(kept: await loaded(), reached: () => reached);
    reopened.sweep();
    await reopened.idle;
    reopened.sweep();
    await reopened.idle;
    reopened.sweep();
    await reopened.idle;

    expect(planner.refusedTold.map((each) => each.offer), [order.offer, order.offer]);
    expect((await loaded()).refusedStarts, isEmpty);
  });

  // Harm: a refusal the planner turned away for good is sent again on every change of a machine.
  test('a refused start the planner refused for good is not told again in the window\'s life', () async {
    final (starts, reports) = window();
    final problems = <String>[];
    reports.onProblem = (provider, project, error) => problems.add(planningFailureWords(error));
    planner.refusedAnswers.add(
      const PlanningRefusal('InvalidRequest', {}, 'The refusal is not what the planner takes.'),
    );
    machine.throwNext = const VarlinkException('org.fuin.porelo.Tasks1.NoPullRequest');

    await expectLater(starts(planner, 'demo', 'ST291', (await plannedOrders()).first), throwsA(isA<PlanningRefusal>()));
    await reports.idle;
    reports.sweep();
    await reports.idle;

    expect(planner.refusedTold, hasLength(1));
    expect(problems, ['The refusal is not what the planner takes.']);
    expect((await loaded()).refusedStarts, isEmpty, reason: 'nor is it kept for a later window');
  });

  // Harm: a refusal is told for an offer the planner already let go, and kept for ever.
  test('a refused start whose offer the planner no longer holds is let go', () async {
    final (starts, reports) = window();
    planner.refusedAnswers.add(const PlanningRefusal('TaskNotAnswered', {}, 'The planner holds nothing of it.'));
    machine.throwNext = const VarlinkException('org.fuin.porelo.Tasks1.NotTheTasksPush');

    await expectLater(starts(planner, 'demo', 'ST291', (await plannedOrders()).first), throwsA(isA<PlanningRefusal>()));
    await reports.idle;

    expect(planner.refusedTold, hasLength(1));
    expect((await loaded()).refusedStarts, isEmpty);
  });

  // Harm: the planner is told Porelo refused a start that never reached Start, or one that may have made its task.
  test('a start refused before Start, lost on the way, failed after it, or a discussion is not reported', () async {
    final (starts, reports) = window();
    final orders = await plannedOrders();
    final noMachine = WindowTaskStarts(
      machineFor: (_) => null,
      backendOf: (_) => machine,
      settings: settings,
      providerOf: (_) => _provider,
    );
    await expectLater(noMachine(planner, 'demo', 'ST291', orders.first), throwsA(isA<PlanningRefusal>()));
    machine.throwNext = const VarlinkDisconnected('the tunnel closed');
    await expectLater(starts(planner, 'demo', 'ST291', orders.first), throwsA(isA<PlanningRefusal>()));
    // Start answered a failed exit: it may have made its task, so nothing says Porelo refused it.
    machine.refuseNext = 'the agent exited';
    await expectLater(starts(planner, 'demo', 'ST291', orders[1]), throwsA(isA<PlanningRefusal>()));
    machine.throwNext = const VarlinkException('org.fuin.porelo.Tasks1.NoRepositoryReadable');
    starts.chooseDiscussion = (machine, project, task) async => (agent: 'pi', model: 'm');
    await expectLater(starts(planner, 'demo', '', discussionOrder()), throwsA(isA<PlanningRefusal>()));
    await reports.idle;
    reports.sweep();
    await reports.idle;

    expect(planner.refusedTold, isEmpty);
    expect((await loaded()).refusedStarts, isEmpty);
  });

  // Harm: the planner's call carries a container, or the refusal in other fields than kept, and the report is refused.
  test('a refused start is told through the task event call, with no container', () async {
    const refused = RefusedStart(
      offer: 'o-1',
      machine: 'laptop',
      provider: _provider,
      project: 'demo',
      story: 'ST291',
      task: 'foo',
      name: 'UnknownForge',
      parameters: {'host': 'forge.example'},
      detail: 'laptop refused.',
    );

    await tellPlannerRefused(planner, refused);

    final call = planner.calls.single;
    expect(
      (call.project, call.task, call.event, call.offer, call.container, call.machine),
      ('demo', 'foo', PlanningTaskEvent.refused, 'o-1', '', 'laptop'),
    );
    expect(call.refusal?.toMap(), {
      'name': 'UnknownForge',
      'parameters': {'host': 'forge.example'},
      'detail': 'laptop refused.',
    });
  });

  // Harm: a value of a refusal the planner does not name, which the window never shows, is written down and sent on.
  test('a refusal the planner does not name goes by its name and words alone', () async {
    final (starts, reports) = window();
    machine.throwNext = const VarlinkException('org.fuin.porelo.Tasks1.SomethingNew', {
      'url': 'https://x@forge.example',
    });

    await expectLater(starts(planner, 'demo', 'ST291', (await plannedOrders()).first), throwsA(isA<PlanningRefusal>()));
    await reports.idle;

    final told = planner.refusedTold.single;
    expect(told.name, 'SomethingNew');
    expect(told.parameters, isEmpty);
    expect(told.detail, isNot(contains('x@forge.example')));
  });

  // Harm: the planner refuses the whole report as a shape fault, and never learns the start was refused.
  test('a refusal is cut to the bounds the planner takes', () {
    final refused = RefusedStart.bounded(
      offer: 'o',
      machine: 'laptop',
      provider: _provider,
      project: 'demo',
      story: 'ST291',
      task: 'foo',
      name: 'Not.A-Name',
      parameters: {'nothing': null, for (var i = 0; i < 20; i++) 'key$i': 'v\u0007${'x' * 600}', '': 'no key'},
      detail: 'line one\nline\ttwo ${'d' * 1200}',
    );

    expect(refused.name, 'StartRefused');
    expect(refused.parameters, hasLength(16));
    expect(refused.parameters.keys, isNot(contains('nothing')), reason: 'a value Porelo did not give is not sent');
    expect(refused.parameters.values.every((value) => value.length == 500 && !value.contains('\u0007')), isTrue);
    expect(refused.detail.length, 1000);
    expect(refused.detail, startsWith('line one\nline two '));
    expect(refused.withinBounds, isTrue);
    expect(
      RefusedStart.bounded(
        offer: 'o',
        machine: 'm',
        provider: 'p',
        project: 'p',
        story: 's',
        task: 't',
        name: 'N',
        detail: '${'a' * 999}\u{1F600}',
      ).detail,
      'a' * 999,
      reason: 'never cut inside a surrogate pair',
    );
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

  // Harm: a task that declared BLOCKED and ended its run normally reads to the planner as done, and its issue moves on.
  test('an end goes with the outcome the task declared and its reason, once', () async {
    final (starts, reports) = window();
    final started = await starts(planner, 'demo', 'ST291', (await plannedOrders()).first);
    await reports.idle;

    machine.end(
      started.container,
      {'at': '2026-11-12T10:00:05Z', 'finished': true},
      declared: {'outcome': 'BLOCKED', 'why': 'The vault key is missing.', 'at': '2026-11-12T10:00:00Z'},
    );
    reports.sweep();
    await reports.idle;
    final (_, reopened) = window(kept: await loaded());
    reopened.sweep();
    await reopened.idle;

    final ends = planner.calls.where((call) => call.event == PlanningTaskEvent.ended).toList();
    expect(ends, hasLength(1));
    final ended = ends.single.ended!;
    expect((ended.outcome, ended.why, ended.finished), ('BLOCKED', 'The vault key is missing.', true));
  });

  // Harm: the row shows the run's end a moment before the outcome the task declared; the end goes out without it and is
  // never told again, so a task that declared BLOCKED reads to the planner as done.
  test('an end whose row has no outcome yet waits for it', () async {
    final shown = Completer<void>();
    final (starts, reports) = window(waitForOutcome: () => shown.future);
    final started = await starts(planner, 'demo', 'ST291', (await plannedOrders()).first);
    await reports.idle;

    machine.end(started.container, {'at': '2026-11-12T10:00:05Z', 'finished': true});
    reports.sweep();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    machine.end(
      started.container,
      {'at': '2026-11-12T10:00:05Z', 'finished': true},
      declared: {'outcome': 'BLOCKED', 'why': 'The vault key is missing.', 'at': '2026-11-12T10:00:00Z'},
    );
    shown.complete();
    await reports.idle;

    final ends = planner.calls.where((call) => call.event == PlanningTaskEvent.ended).toList();
    expect(ends, hasLength(1));
    expect(ends.single.ended!.outcome, 'BLOCKED');
  });

  /// The end record the planner is told once the one task started ends as [agent] and its row's [declared] say.
  Future<PlanningTaskEnded> reportedEnd(Map<String, dynamic> agent, {Map<String, dynamic>? declared}) async {
    final (starts, reports) = window();
    final started = await starts(planner, 'demo', 'ST291', (await plannedOrders()).first);
    await reports.idle;
    machine.end(started.container, agent, declared: declared);
    reports.sweep();
    await reports.idle;
    return planner.calls.singleWhere((call) => call.event == PlanningTaskEvent.ended).ended!;
  }

  // Harm: a run that failed is told to the planner as done.
  test('a run that failed is told as FAILED with its error', () async {
    final ended = await reportedEnd(
      {'at': 'a', 'finished': false, 'error': 'The provider refused the key.'},
      declared: {'outcome': 'FAILED', 'why': 'The provider refused the key.', 'at': 'a'},
    );

    expect((ended.outcome, ended.why), ('FAILED', 'The provider refused the key.'));
  });

  // Harm: an outcome this build does not know is dropped or mapped on its way to the planner.
  test('an outcome this build does not know is told as Porelo named it', () async {
    final ended = await reportedEnd({'at': 'b', 'finished': true}, declared: {'outcome': 'PARKED', 'at': 'b'});

    expect((ended.outcome, ended.why), ('PARKED', ''));
  });

  // Harm: an outcome is invented for a finished run that declared nothing.
  test('a finished run that declared nothing is told with no outcome, as before', () async {
    final ended = await reportedEnd({'at': 'c', 'finished': true});

    expect(ended.outcome, isNull);
    expect(ended.toMap(), {'at': 'c', 'finished': true, 'why': '', 'answer': '', 'unpushed': 0});
  });

  // Harm: an empty outcome goes to the planner as a word, neither DONE, BLOCKED nor FAILED.
  test('an empty outcome is told as none', () async {
    final ended = await reportedEnd({'at': 'd', 'finished': true}, declared: {'outcome': '', 'why': 'w', 'at': 'd'});

    expect((ended.outcome, ended.why), (null, 'w'));
  });

  // Harm: a declared end with no reason of its own hides the error the run ended with.
  test('a declared end without a reason keeps the run\'s error', () async {
    final ended = await reportedEnd(
      {'at': 'e', 'finished': false, 'error': 'The provider refused the key.'},
      declared: {'outcome': 'FAILED', 'at': 'e'},
    );

    expect((ended.outcome, ended.why), ('FAILED', 'The provider refused the key.'));
  });

  // Harm: another change of a machine while an end waits for its outcome sends the end without it, and it is never
  // told again, so a task that declared BLOCKED reads to the planner as done.
  test('an end waiting for its outcome still waits when the machines are looked at again', () async {
    final shown = Completer<void>();
    final (starts, reports) = window(waitForOutcome: () => shown.future);
    final started = await starts(planner, 'demo', 'ST291', (await plannedOrders()).first);
    await reports.idle;

    machine.end(started.container, {'at': '2026-11-12T10:00:05Z', 'finished': true});
    reports.sweep();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    reports.sweep();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(planner.calls.where((call) => call.event == PlanningTaskEvent.ended), isEmpty);
    machine.end(
      started.container,
      {'at': '2026-11-12T10:00:05Z', 'finished': true},
      declared: {'outcome': 'BLOCKED', 'why': 'The vault key is missing.', 'at': '2026-11-12T10:00:00Z'},
    );
    shown.complete();
    await reports.idle;

    final ends = planner.calls.where((call) => call.event == PlanningTaskEvent.ended).toList();
    expect(ends, hasLength(1));
    expect(ends.single.ended!.outcome, 'BLOCKED');
  });

  // Harm: a wait that fails keeps every later end from being told, and the window never settles.
  test('an end is told after a wait for its outcome that failed', () async {
    final (starts, reports) = window(waitForOutcome: () async => throw StateError('the wait broke'));
    final started = await starts(planner, 'demo', 'ST291', (await plannedOrders()).first);
    await reports.idle;

    machine.end(started.container, {'at': 'f', 'finished': true});
    reports.sweep();
    await reports.idle;

    expect(planner.calls.where((call) => call.event == PlanningTaskEvent.ended), hasLength(1));
  });

  // Harm: the end of a task the window stopped reaches the planner without the outcome the task declared.
  test('a stopped task\'s end goes with the outcome it declared', () async {
    final (starts, reports) = window();
    final started = await starts(planner, 'demo', 'ST291', (await plannedOrders()).first);
    await reports.idle;

    machine.end(
      started.container,
      {'at': 'g', 'finished': false},
      declared: {'outcome': 'BLOCKED', 'why': 'The vault key is missing.', 'at': 'g'},
    );
    await reports.stop(planner, 'demo', 'ST291', [started]);
    await reports.idle;

    final ended = planner.calls.singleWhere((call) => call.event == PlanningTaskEvent.ended).ended!;
    expect((ended.outcome, ended.why), ('BLOCKED', 'The vault key is missing.'));
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

  // Harm: a discussion's start is kept for ever in every later window's settings, or its end is reported to the
  // planner as a story's task: its idea comes back as a report its planner reads itself.
  test('a discussion keeps nothing, started or not answered yet, and reports nothing', () async {
    final (starts, reports) = window();
    await starts(planner, 'demo', '', discussionOrder());
    await reports.idle;
    expect((await loaded()).pendingStarts, isEmpty, reason: 'nothing is kept of a discussion Start answered');

    machine.hangAfterStart = true;
    unawaited(starts(planner, 'demo', '', discussionOrder(offer: _laterDiscussion)));
    await pumpEventQueue();
    expect((await loaded()).pendingStarts, isEmpty, reason: 'nor of one Start has not answered yet');
    expect(settings.planningOfferHanded(_laterDiscussion), isTrue, reason: 'it is still started only once');

    machine.end('porelo-demo-discussion', {'at': 'T9', 'finished': true});
    final (_, reopened) = window(kept: await loaded());
    reopened.sweep();
    await reopened.idle;
    expect((await loaded()).plannedOffers, isEmpty);
    expect(planner.calls, isEmpty);
  });

  // Harm: a discussion an earlier build kept waiting to be found again is kept for ever.
  test('a discussion an earlier build kept waiting is let go once its task is found', () async {
    await settings.handPlanningOffer(
      'an-earlier-discussion',
      pending: const PendingStart(
        offer: 'an-earlier-discussion',
        machine: 'laptop',
        provider: _provider,
        project: 'demo',
        story: '',
        discussion: true,
      ),
    );
    machine.listed.add(
      Task.from({
        'name': 'porelo-demo-discussion',
        'task': 'discussion',
        'project': 'demo',
        'running': true,
        'callerKey': 'an-earlier-discussion',
      }),
    );
    expect((await loaded()).pendingStarts, isNotEmpty);

    final (_, reopened) = window(kept: await loaded());
    reopened.sweep();
    await reopened.idle;

    expect((await loaded()).pendingStarts, isEmpty);
    expect(planner.calls, isEmpty);
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

  // Harm: a task of another project whose key equals an offer of this window is reported as that offer's task.
  test('a task found again by its key is taken only when it is of the offer\'s project', () async {
    final (starts, _) = window();
    final order = (await plannedOrders()).first;
    machine.hangAfterStart = true;
    unawaited(starts(planner, 'demo', 'ST291', order));
    await pumpEventQueue();
    machine.listed
      ..clear()
      ..add(
        Task.from({
          'name': 'porelo-shop-porelo',
          'task': 'porelo',
          'project': 'shop',
          'running': true,
          'callerKey': order.offer,
        }),
      );

    final (_, reopened) = window(kept: await loaded());
    reopened.sweep();
    await reopened.idle;

    expect((await loaded()).plannedOffers, isEmpty);
    expect(planner.calls, isEmpty);
  });

  // Harm: a start whose task names no task is kept waiting for ever, in every later window's settings.
  test('a start found again whose task names no task is let go', () async {
    final (starts, _) = window();
    final order = (await plannedOrders()).first;
    machine.hangAfterStart = true;
    unawaited(starts(planner, 'demo', 'ST291', order));
    await pumpEventQueue();
    machine.listed
      ..clear()
      ..add(
        Task.from({
          'name': 'porelo-demo-porelo',
          'task': '',
          'project': 'demo',
          'running': true,
          'callerKey': order.offer,
        }),
      );
    expect((await loaded()).pendingStarts, isNotEmpty);

    final (_, reopened) = window(kept: await loaded());
    reopened.sweep();
    await reopened.idle;

    expect((await loaded()).pendingStarts, isEmpty);
    expect((await loaded()).plannedOffers, isEmpty);
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

  // Harm: the window closes between the planner's answer to an end and Start making the follow-up's task, and after a
  // restart the story stands in its working state with nobody at work and nothing asked of the person.
  test('a follow-up the window closed on before Start made its task is started after a restart', () async {
    final (starts, reports) = window();
    final order = (await plannedOrders()).first;
    final followUp = _followUp(1);
    planner.answers.addAll([
      _answer(const []),
      // To the end, before and after the restart: the planner replays its answer to an identical report.
      _answer([followUp]),
      _answer([followUp]),
    ]);
    final started = await starts(planner, 'demo', 'ST291', order);
    await reports.idle;
    machine.end(started.container, {'at': 'the end', 'finished': true});
    machine.hangBeforeStart = true;
    reports.sweep();
    await pumpEventQueue();
    expect(machine.started, hasLength(1), reason: 'the window closed before Start made the follow-up');
    machine.hangBeforeStart = false;

    final (_, reopened) = window(kept: await loaded());
    reopened.sweep();
    await reopened.idle;
    final (_, again) = window(kept: await loaded());
    again.sweep();
    await again.idle;

    expect(machine.started.map((each) => each['callerKey']), [order.offer, followUp['offer']]);
    expect(shown.map((each) => each.$3.single.$1.offer), [followUp['offer']]);
    expect((await loaded()).pendingStarts, isEmpty);
  });

  // Harm: a follow-up is lost for good because another project's task carries the same key.
  test('another project\'s task with the follow-up\'s key does not count as its task after a restart', () async {
    final (starts, reports) = window();
    final order = (await plannedOrders()).first;
    final followUp = _followUp(1);
    planner.answers.addAll([
      _answer(const []),
      _answer([followUp]),
      _answer([followUp]),
    ]);
    final started = await starts(planner, 'demo', 'ST291', order);
    await reports.idle;
    machine.end(started.container, {'at': 'the end', 'finished': true});
    machine.hangBeforeStart = true;
    reports.sweep();
    await pumpEventQueue();
    machine.hangBeforeStart = false;
    machine.listed.add(
      Task.from({
        'name': 'porelo-elsewhere-1',
        'task': 'elsewhere',
        'project': 'elsewhere',
        'running': true,
        'callerKey': followUp['offer']!,
      }),
    );

    final (_, reopened) = window(kept: await loaded());
    reopened.sweep();
    await reopened.idle;

    expect(machine.started.map((each) => each['callerKey']), [order.offer, followUp['offer']]);
  });

  // Harm: a follow-up an earlier window handed is lost, or started twice, when its machine's tasks are not known yet.
  test('a follow-up an earlier window handed waits, said once, until its machine\'s tasks are known', () async {
    final (starts, reports) = window();
    final order = (await plannedOrders()).first;
    final followUp = _followUp(1);
    planner.answers.addAll([
      _answer(const []),
      // To the end before the restart, and to each of the three reports after it: the planner replays its answer.
      for (var answered = 0; answered < 4; answered++) _answer([followUp]),
    ]);
    final started = await starts(planner, 'demo', 'ST291', order);
    await reports.idle;
    machine.end(started.container, {'at': 'the end', 'finished': true});
    machine.hangBeforeStart = true;
    reports.sweep();
    await pumpEventQueue();
    machine.hangBeforeStart = false;

    var known = false;
    final (_, reopened) = window(kept: await loaded(), listed: () => known);
    final problems = <String>[];
    reopened.onProblem = (provider, project, error) => problems.add(planningFailureWords(error));
    final ended = (await loaded()).plannedOffer('laptop', started.container)!;
    for (var told = 0; told < 2; told++) {
      await reopened.report(
        'demo',
        started.task,
        PlanningTaskEvent.stopped,
        offer: ended.offer,
        container: started.container,
        machine: 'laptop',
      );
      await reopened.idle;
    }
    expect(machine.started, hasLength(1), reason: 'not started while the tasks of laptop are unknown');
    expect(problems, [contains('not known yet')], reason: 'said once');

    known = true;
    await reopened.report(
      'demo',
      started.task,
      PlanningTaskEvent.stopped,
      offer: ended.offer,
      container: started.container,
      machine: 'laptop',
    );
    await reopened.idle;

    expect(machine.started.map((each) => each['callerKey']), [order.offer, followUp['offer']]);
  });

  // Harm: a follow-up whose task Start made just before the window closed is started a second time after a restart.
  test('a follow-up whose task Start made before the window closed is not started again after a restart', () async {
    final (starts, reports) = window();
    final order = (await plannedOrders()).first;
    final followUp = _followUp(1);
    planner.answers.addAll([
      _answer(const []),
      _answer([followUp]),
      _answer([followUp]),
    ]);
    final started = await starts(planner, 'demo', 'ST291', order);
    await reports.idle;
    machine.end(started.container, {'at': 'the end', 'finished': true});
    machine.hangAfterStart = true;
    reports.sweep();
    await pumpEventQueue();
    machine.hangAfterStart = false;

    final (_, reopened) = window(kept: await loaded());
    reopened.sweep();
    await reopened.idle;
    final (_, again) = window(kept: await loaded());
    again.sweep();
    await again.idle;

    expect(machine.started.map((each) => each['callerKey']), [order.offer, followUp['offer']]);
    expect((await loaded()).pendingStarts, isEmpty);
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

  // Harm: a task of a stopped run runs on, or stays started at the planner, so its story can never be started again;
  // or its end is told twice.
  test('a stop stops each task on the machine it was started on, reports its end once and forgets its offer', () async {
    final (starts, reports) = window(now: () => DateTime.utc(2026, 11, 15, 16, 30));
    final order = (await plannedOrders()).first;
    final started = await starts(planner, 'demo', 'ST291', order);
    await reports.idle;
    await reports.stop(planner, 'demo', 'ST291', [started]);
    await reports.idle;
    // A Stop of the run already stopped names the task again; it was ended once.
    await reports.stop(planner, 'demo', 'ST291', [started]);
    machine.end(started.container, {'at': 'the end', 'finished': false});
    reports.sweep();
    await reports.idle;

    expect(stopped.first, (_laptop, started.container));
    expect(planner.calls.map((call) => (call.event, call.offer, call.container, call.machine)), [
      (PlanningTaskEvent.started, order.offer, started.container, 'laptop'),
      (PlanningTaskEvent.ended, order.offer, started.container, 'laptop'),
    ]);
    expect(planner.calls.last.ended?.at, '2026-11-15T16:30:00.000Z');
    expect(planner.calls.last.ended?.finished, isFalse);
    expect((await loaded()).planningOffer('laptop', started.container), isNull);
  });

  // Harm: a stop that failed leaves the task running and started at the planner, and no later Stop reaches it.
  test('a stop that failed keeps the offer, and the next Stop stops the task and ends it', () async {
    final (starts, reports) = window();
    final problems = <String>[];
    reports.onProblem = (provider, project, error) => problems.add(planningFailureWords(error));
    final order = (await plannedOrders()).first;
    final started = await starts(planner, 'demo', 'ST291', order);
    await reports.idle;
    stopFails = StateError('laptop did not answer.');

    await reports.stop(planner, 'demo', 'ST291', [started]);
    await reports.idle;
    expect(stopped, isEmpty);
    expect(planner.calls.map((call) => call.event), [
      PlanningTaskEvent.started,
    ], reason: 'nothing stopped, nothing ended');
    expect((await loaded()).planningOffer('laptop', started.container), order.offer, reason: 'kept for the next Stop');

    await reports.stop(planner, 'demo', 'ST291', [started]);
    await reports.idle;
    expect(stopped, [(_laptop, started.container)]);
    expect(planner.calls.map((call) => call.event), [PlanningTaskEvent.started, PlanningTaskEvent.ended]);
    expect((await loaded()).planningOffer('laptop', started.container), isNull);
    expect(problems, hasLength(1));
  });

  // Harm: an end the planner did not take is lost, so the task stays started there and its story cannot start again.
  test('an end the planner did not take keeps the offer, and the next Stop tells it again', () async {
    final (starts, reports) = window();
    final order = (await plannedOrders()).first;
    final started = await starts(planner, 'demo', 'ST291', order);
    await reports.idle;
    planner.answers.add(const PlanningRefusal('TimedOut', {}, 'The planner did not answer in time.'));

    await reports.stop(planner, 'demo', 'ST291', [started]);
    await reports.idle;
    expect((await loaded()).planningOffer('laptop', started.container), order.offer, reason: 'kept for the next Stop');

    machine.end(started.container, {'at': 'the end', 'finished': false});
    await reports.stop(planner, 'demo', 'ST291', [started]);
    await reports.idle;
    expect(stopped, [(_laptop, started.container)], reason: 'a task already stopped is not stopped again');
    expect(planner.calls.map((call) => call.event), [
      PlanningTaskEvent.started,
      PlanningTaskEvent.ended,
      PlanningTaskEvent.ended,
    ]);
    expect((await loaded()).planningOffer('laptop', started.container), isNull);
  });

  // Harm: a person is told of an error where the planner simply holds nothing of the task any more.
  test('an end the planner no longer answers for is not said, and the offer goes', () async {
    final (starts, reports) = window();
    final problems = <Object>[];
    reports.onProblem = (provider, project, error) => problems.add(error);
    final started = await starts(planner, 'demo', 'ST291', (await plannedOrders()).first);
    await reports.idle;
    planner.answers.add(const PlanningRefusal('TaskNotAnswered', {}, 'The planner no longer answers for this task.'));

    await reports.stop(planner, 'demo', 'ST291', [started]);
    await reports.idle;

    expect(problems, isEmpty);
    expect((await loaded()).planningOffer('laptop', started.container), isNull);
  });

  // Harm: a person is told of an error for the end of a task whose start the stop took over before the planner heard
  // it, or the end goes before its start.
  test('a Stop while the start waits for its answer tells the end after it, quietly where none started', () async {
    final (starts, reports) = window();
    final problems = <Object>[];
    reports.onProblem = (provider, project, error) => problems.add(error);
    planner.hold = Completer<void>();
    planner.answers
      ..add(_answer(const []))
      ..add(const PlanningRefusal('TaskEventConflict', {}, 'The task has not started or already ended differently.'));
    final started = await starts(planner, 'demo', 'ST291', (await plannedOrders()).first);
    await pumpEventQueue();

    await reports.stop(planner, 'demo', 'ST291', [started]);
    planner.hold!.complete();
    await reports.idle;

    expect(planner.calls.map((call) => call.event), [PlanningTaskEvent.started, PlanningTaskEvent.ended]);
    expect(problems, isEmpty);
    expect((await loaded()).planningOffer('laptop', started.container), isNull);
  });

  // Harm: the person's running agent is stopped for a refusal that halts nothing.
  for (final refusal in const [
    PlanningRefusal('TimedOut', {}, 'The planner did not answer in time.'),
    PlanningRefusal('InvalidSettings', {}, 'The report was not valid.'),
    PlanningRefusal('TaskEventConflict', {}, 'The offer does not match this task.'),
    PlanningRefusal('WorkNotAllowed', {}, 'The move is not allowed.'),
    PlanningRefusal('InvalidName', {}, 'The task name is invalid.'),
  ]) {
    test('a start refused with ${refusal.name} stops nothing and ends nothing', () async {
      final (starts, reports) = window();
      planner.answers.add(refusal);
      final started = await starts(planner, 'demo', 'ST291', (await plannedOrders()).first);
      await reports.idle;

      expect(stopped, isEmpty);
      expect(planner.calls.map((call) => call.event), [PlanningTaskEvent.started]);
      expect(settings.planningOffer('laptop', started.container), isNotNull);
    });
  }

  // Harm: a task whose start the planner refused after offering it stays started there, so its story can never be
  // started again; or it runs on unreported, or its end is told twice.
  // Each of the store's refusals halts the run when the start's save meets it, not only the ones a save alone throws.
  for (final name in const ['ItemChanged', 'Unreachable', 'Busy', 'NoSuchStory']) {
    test('a start the planner refused with $name is stopped and its end reported once', () async {
      final (starts, reports) = window();
      final problems = <String>[];
      reports.onProblem = (provider, project, error) => problems.add(planningFailureWords(error));
      planner.answers.add(PlanningRefusal(name, const {}, 'The board could not be saved.'));
      final order = (await plannedOrders()).first;

      final started = await starts(planner, 'demo', 'ST291', order);
      await reports.idle;
      machine.end(started.container, {'at': 'the end', 'finished': true});
      reports.sweep();
      await reports.idle;

      expect(stopped, [(_laptop, started.container)]);
      expect(planner.calls.map((call) => (call.event, call.offer)), [
        (PlanningTaskEvent.started, order.offer),
        (PlanningTaskEvent.ended, order.offer),
      ]);
      expect((await loaded()).planningOffer('laptop', started.container), isNull);
      expect(problems, [planningFailureWords(PlanningRefusal(name, const {}, 'The board could not be saved.'))]);
    });
  }

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
      (PlanningTaskEvent.ended, first.offer),
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
  group('an ended planned stage', () {
    const analysis = {
      'format': 'porelo-stage-result-1',
      'kind': 'ANALYSIS',
      'issues': [
        {'id': 'PI68', 'plan': 'Read the docs against the code.', 'size': 'S', 'sizeWhy': 'One module.'},
      ],
    };
    final analysisFile = {'name': 'analysis.json', 'state': 'handed', 'bytes': 10};

    /// A started stage whose order named `analysis.json`, as the planner orders one, and its reports.
    Future<(WindowTaskReports, PlanningTaskStarted, List<String>)> staged({
      DateTime Function()? now,
      bool Function()? reached,
    }) async {
      final (starts, reports) = window(now: now, reached: reached);
      final problems = <String>[];
      reports.onProblem = (provider, project, error) => problems.add(planningFailureWords(error));
      final started = await starts(planner, 'demo', 'ST366', (await plannedOrders()).first);
      await reports.idle;
      final kept = settings.plannedOffer('laptop', started.container)!;
      await settings.rememberPlanningOffer(
        machine: kept.machine,
        container: kept.container,
        offer: kept.offer,
        provider: kept.provider,
        project: kept.project,
        story: kept.story,
        task: kept.task,
        run: kept.run,
        result: 'analysis.json',
      );
      await settings.planningOfferReported('laptop', started.container, started: true);
      return (reports, started, problems);
    }

    Future<void> sweeps(WindowTaskReports reports) async {
      for (var change = 0; change < 3; change++) {
        reports.sweep();
        await reports.idle;
      }
    }

    List<PlanningTaskEvent> events() => [for (final call in planner.calls) call.event];

    // Harm: the planner moves the issue on an end before it has what the stage produced, or never gets it; or gets it
    // twice, or changed, or under another task or offer.
    test('hands its result once, unchanged, before its end is reported', () async {
      final (reports, started, problems) = await staged();
      results[started.container] = TaskResult.from({...analysisFile, 'content': jsonEncode(analysis)});
      machine.end(started.container, {'at': '2026-11-15T11:00:00Z', 'finished': true, 'result': analysisFile});

      await sweeps(reports);

      final offer = settings.plannedOffer('laptop', started.container)!;
      final (project, task, handedOffer, result, missing) = stageResults.single;
      expect((project, task, handedOffer, missing), ('demo', started.task, offer.offer, null));
      expect(result, analysis);
      expect(events(), [PlanningTaskEvent.started, PlanningTaskEvent.ended]);
      expect(problems, isEmpty);

      final (_, again) = window(kept: await loaded());
      await sweeps(again);
      expect(stageResults, hasLength(1), reason: 'a result the planner has is not handed again after a restart');
    });

    // Harm: a stage's end is reported while the planner could not be reached for its result, so the issue moves on
    // with nothing saved; or the result is never handed once it can be.
    test('keeps its end back while the planner cannot take its result, and hands both once it can', () async {
      final (reports, started, problems) = await staged();
      results[started.container] = TaskResult.from({...analysisFile, 'content': jsonEncode(analysis)});
      machine.end(started.container, {'at': '2026-11-15T11:00:00Z', 'finished': true, 'result': analysisFile});
      stageAnswers
        ..add(const StageResultNotSaved('no planner is running for this account', transient: true))
        ..add(const StageResultNotSaved('no planner is running for this account', transient: true));

      for (var change = 0; change < 2; change++) {
        reports.sweep();
        await reports.idle;
      }
      expect(events(), [PlanningTaskEvent.started], reason: 'no end before the result is saved');
      expect(problems, hasLength(1), reason: 'a planner not reached is said once');

      await sweeps(reports);
      expect(stageResults, hasLength(3));
      expect(events(), [PlanningTaskEvent.started, PlanningTaskEvent.ended]);
    });

    // Harm: a result the planner saved is handed again while its end waits for a planner not reached, also after a
    // restart.
    test('a result saved while its end could not be told is not handed again', () async {
      var reached = true;
      final (reports, started, _) = await staged(reached: () => reached);
      results[started.container] = TaskResult.from({...analysisFile, 'content': jsonEncode(analysis)});
      machine.end(started.container, {'at': '2026-11-15T11:00:00Z', 'finished': true, 'result': analysisFile});
      reached = false;

      await sweeps(reports);
      expect(stageResults, hasLength(1));
      expect(events(), [PlanningTaskEvent.started], reason: 'the end waits for the planner');

      final (_, again) = window(kept: await loaded());
      await sweeps(again);
      reached = true;
      await sweeps(again);
      expect(stageResults, hasLength(1));
      expect(events(), [PlanningTaskEvent.started, PlanningTaskEvent.ended]);
    });

    // Harm: a refused result keeps the end back for ever, or is refused in silence.
    test('a refused result says the planner\'s faults, and its end is still reported', () async {
      final (reports, started, problems) = await staged();
      results[started.container] = TaskResult.from({...analysisFile, 'content': jsonEncode(analysis)});
      machine.end(started.container, {'at': '2026-11-15T11:00:00Z', 'finished': true, 'result': analysisFile});
      stageAnswers.add(
        const StageResultNotSaved('The analysis is not saved.', faults: ['issues[0].size: not one of XS, S, M, L, XL']),
      );

      await sweeps(reports);

      expect(stageResults, hasLength(1));
      expect(events(), [PlanningTaskEvent.started, PlanningTaskEvent.ended]);
      expect(problems.single, contains('issues[0].size: not one of XS, S, M, L, XL'));
    });

    // Harm: a stage that wrote no result leaves its issue waiting for ever; or one the machine had not yet taken at the
    // end is said missing.
    test('a result missing past its settling is said as missing with why', () async {
      var at = DateTime.utc(2026, 11, 15, 11);
      final (reports, started, problems) = await staged(now: () => at);
      results[started.container] = const TaskResult(name: 'analysis.json', state: ResultState.missing);
      machine.end(started.container, {'at': '2026-11-15T11:00:00Z', 'finished': true});

      await sweeps(reports);
      expect(stageResults, isEmpty, reason: 'looked at again until it settles');
      expect(events(), [PlanningTaskEvent.started]);

      at = at.add(const Duration(minutes: 2));
      await sweeps(reports);
      expect(stageResults.single.$4, isNull);
      expect(stageResults.single.$5, 'it wrote no analysis.json');
      expect(events(), [PlanningTaskEvent.started, PlanningTaskEvent.ended]);
      expect(problems.single, contains('ended with no result'));
    });

    // Harm: a result that is no JSON object is handed as if it were one, or leaves its issue waiting for ever.
    test('a result that is no JSON object is said as missing with why', () async {
      final (reports, started, _) = await staged();
      results[started.container] = TaskResult.from({...analysisFile, 'content': '[1, 2]'});
      machine.end(started.container, {'at': '2026-11-15T12:00:00Z', 'finished': true, 'result': analysisFile});

      await sweeps(reports);

      expect(stageResults.single.$4, isNull);
      expect(stageResults.single.$5, 'analysis.json holds no JSON object');
      expect(events(), [PlanningTaskEvent.started, PlanningTaskEvent.ended]);
    });

    // Harm: a result past what the planner takes is sent and refused whole, or one the machine would not take is
    // handed as if empty; either leaves its issue without saying why.
    test('a result larger than the planner or the machine takes is said as missing with why', () async {
      final (reports, started, _) = await staged();
      final big = jsonEncode({...analysis, 'pad': 'x' * mostStageResultBytes});
      results[started.container] = TaskResult.from({...analysisFile, 'content': big});
      machine.end(started.container, {'at': '2026-11-15T12:00:00Z', 'finished': true, 'result': analysisFile});

      await sweeps(reports);

      expect(stageResults.single.$4, isNull);
      expect(stageResults.single.$5, 'analysis.json is larger than the planner takes (1 MiB)');
    });

    // Harm: a result of a size the planner takes, past the old 256 KiB, is said as missing instead of handed.
    test('a result of half a MiB is handed whole', () async {
      final (reports, started, _) = await staged();
      final big = {...analysis, 'pad': 'x' * (512 * 1024)};
      results[started.container] = TaskResult.from({...analysisFile, 'content': jsonEncode(big)});
      machine.end(started.container, {'at': '2026-11-15T12:00:00Z', 'finished': true, 'result': analysisFile});

      await sweeps(reports);

      expect(stageResults.single.$4, big);
      expect(stageResults.single.$5, isNull);
    });

    test('a result the machine would not take is said as missing with why', () async {
      final (reports, started, _) = await staged();
      results[started.container] = const TaskResult(name: 'analysis.json', state: ResultState.tooLarge);
      machine.end(started.container, {'at': '2026-11-15T12:00:00Z', 'finished': true});

      await sweeps(reports);

      expect(stageResults.single.$5, 'analysis.json is larger than the machine takes');
    });

    // Harm: a stage started just before the window ended is found again without its result file, so its end is
    // reported with nothing handed in and its issue moves on with no plan saved.
    test('a stage found again by its key after a restart still hands its result before its end', () async {
      final (starts, _) = window();
      final order = PlanningTaskOrder.from({
        'offer': '00000000-0000-4000-8000-0000000005a2',
        'repository': 'porelo',
        'issues': ['PI68'],
        'role': 'MAIN',
        'agent': 'claude',
        'model': 'opus',
        'mode': 'AGENT',
        'prompt': 'Analyse PI68 and write analysis.json.',
        'result': 'analysis.json',
      });
      machine.hangAfterStart = true;
      unawaited(starts(planner, 'demo', 'ST366', order));
      await pumpEventQueue();
      expect((await loaded()).plannedOffers, isEmpty);

      final (_, reopened) = window(kept: await loaded());
      reopened.sweep();
      await reopened.idle;
      results['porelo-demo-porelo'] = TaskResult.from({...analysisFile, 'content': jsonEncode(analysis)});
      machine.end('porelo-demo-porelo', {'at': '2026-11-15T13:00:00Z', 'finished': true, 'result': analysisFile});
      await sweeps(reopened);

      expect(stageResults.single.$3, order.offer);
      expect(events(), [PlanningTaskEvent.started, PlanningTaskEvent.ended]);
      final kept = (await loaded()).plannedOffer('laptop', 'porelo-demo-porelo')!;
      expect(
        (kept.role, kept.worksOn),
        ('MAIN', 'PI68 of ST366, in analysis'),
        reason: 'its row says what it works on',
      );
    });

    // Harm: a machine that cannot answer for a moment, as right after it is reached again, holds the stage's end back
    // for the rest of the window's life; or the failure is said on every change of the machine.
    test('a result the machine could not read is said once and read again, and its end follows', () async {
      final (reports, started, problems) = await staged();
      machine.end(started.container, {'at': '2026-11-15T11:00:00Z', 'finished': true, 'result': analysisFile});

      await sweeps(reports);
      expect(stageResults, isEmpty);
      expect(events(), [PlanningTaskEvent.started]);
      expect(problems, hasLength(1));

      results[started.container] = TaskResult.from({...analysisFile, 'content': jsonEncode(analysis)});
      await sweeps(reports);
      expect(stageResults.single.$4, analysis);
      expect(events(), [PlanningTaskEvent.started, PlanningTaskEvent.ended]);
      expect(problems, hasLength(1));
    });

    // Harm: work that pushes waits for a result it never writes, so its end is never reported.
    test('a task with no result file reports its end alone', () async {
      final (starts, reports) = window();
      final started = await starts(planner, 'demo', 'ST291', (await plannedOrders()).first);
      await reports.idle;
      machine.end(started.container, {'at': '2026-11-15T11:00:00Z', 'finished': true});

      await sweeps(reports);

      expect(stageResults, isEmpty);
      expect(events(), [PlanningTaskEvent.started, PlanningTaskEvent.ended]);
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
  PlanningStartRefusal? refusal,
});

/// A provider's source that records each report and answers what a test queued, an empty answer when none is.
class _Planner extends Fake implements PlanningSource {
  final calls = <_Call>[];
  final answers = <Object>[];

  /// Each new issue asked for: project, repository, title, what must be true, size and the versions seen.
  final issues = <(String, String, String, String, String?, Map<String, String>)>[];

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
    Map<String, String> seen, {
    IssueWorker worker = IssueWorker.agent,
    String? task,
  }) async {
    issues.add((project, repository, title, mustBeTrue, size, seen));
    tasksNamed.add(task);
    final next = issueAnswers.isEmpty ? null : issueAnswers.removeAt(0);
    if (next is Exception) throw next;
    return PlanningIssueAdded(id: 'F${900 + issues.length}', revision: 'r8');
  }

  /// Held until completed: the answer a report waits for meanwhile.
  Completer<void>? hold;

  /// Each refused start told, and what the next ones are answered, an empty answer when nothing is queued.
  final refusedTold = <RefusedStart>[];
  final refusedAnswers = <Object>[];

  Future<TaskEventResolution> told(PlanningSource source, RefusedStart refused) async {
    expect(source, same(this));
    refusedTold.add(refused);
    final next = refusedAnswers.isEmpty ? _answer(const []) : refusedAnswers.removeAt(0);
    if (next is Exception) throw next;
    return TaskEventResolution.from(next as Map<String, dynamic>);
  }

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
    PlanningStartRefusal? refusal,
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
      refusal: refusal,
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

  /// What the next Start throws, as the machine or the way to it refused.
  Object? throwNext;

  /// Start answers, but the window ends before it hears it: the call never returns.
  bool hangAfterStart = false;

  /// The window ends before its Start reaches the machine: the call never returns, and no task is made.
  bool hangBeforeStart = false;

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

  /// The agent of [container] ended as [ended] says, the task declared [declared], its work landed where [landed] says.
  void end(
    String container,
    Map<String, dynamic> ended, {
    List<Map<String, dynamic>>? landed,
    Map<String, dynamic>? declared,
  }) {
    final index = listed.indexWhere((task) => task.name == container);
    final task = listed[index];
    listed[index] = Task.from({
      'name': task.name,
      'task': task.task,
      'project': task.project,
      'running': false,
      'run': ?task.run,
      'agentEnded': ended,
      'ended': ?declared,
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
    void Function(StartEvent event)? onEvent,
    String? result,
    bool readOnly = false,
    Map<String, String> given = const {},
    TrackedWork? work,
    String? role,
    Map<String, Object?>? place,
    String? task,
  }) async {
    if (refuseNext case final words?) {
      refuseNext = null;
      return StartProgress(exitCode: 1, output: [words]);
    }
    if (throwNext case final error?) {
      throwNext = null;
      throw error;
    }
    if (hangBeforeStart) await Completer<void>().future;
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
    String? callerKey,
    void Function(StartEvent event)? onEvent,
  }) async {
    if (throwNext case final error?) {
      throwNext = null;
      throw error;
    }
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
    if (hangAfterStart) await Completer<void>().future;
    return StartProgress(container: container, exitCode: 0, action: StartAction.create);
  }

  @override
  Future<List<Task>> tasks() async {
    await whileListing?.call(++_listings);
    return List.of(listed);
  }
}
