import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/ui/planning_embedding.dart';
import 'package:porelo_planning/planning_fake.dart' show MockPlanningSource;
import 'package:porelo_planning/porelo_planning.dart';

void main() {
  const laptop = Machine(name: 'laptop', socketPath: '/run/laptop.sock');
  const builder = Machine(name: 'builder', socketPath: '/run/builder.sock');
  const host = Machine(name: 'host', socketPath: '/run/host.sock', kind: 'host');

  group('where a planned task runs', () {
    // Harm: a story's task starts on a machine that does not carry its project while one that does is watched.
    test('a host that carries the project comes before any other machine', () {
      final carrying = {builder, host, laptop};
      expect(plannedTaskMachine([laptop, builder, host], laptop, carrying.contains), host);
    });

    // Harm: as above, where no host carries it.
    test('without a host, the machine that carries it, the one connected first', () {
      expect(plannedTaskMachine([laptop, builder, host], laptop, {builder}.contains), builder);
      expect(plannedTaskMachine([builder, laptop], laptop, {builder, laptop}.contains), laptop);
    });

    // Harm: a project no watched machine carries is never started, or started somewhere at random.
    test('where none carries it, the machine the window is connected to', () {
      expect(plannedTaskMachine([laptop, builder, host], builder, (_) => false), builder);
      expect(plannedTaskMachine(const [], null, (_) => true), isNull);
    });
  });

  group('the window starts a planned task', () {
    late MemorySettingsStore store;
    late Settings settings;
    late _Starting machine;

    setUp(() async {
      store = MemorySettingsStore();
      settings = Settings(store);
      await settings.load();
      machine = _Starting();
    });

    WindowTaskStarts starts({Machine? on = laptop}) =>
        WindowTaskStarts(machineFor: (_) => on, backendOf: (_) => machine, settings: settings, providerOf: (_) => 'p');

    // Harm: a task starts with arguments the planner did not order, or the screen keeps names Start did not give.
    test('Start gets the order as given, and the task and container Porelo answered come back', () async {
      final order = (await plannedOrders()).first;
      final hook = starts();

      final started = await hook(MockPlanningSource('planner'), 'demo', 'ST291', order);

      expect(machine.started.single, {
        'project': 'demo',
        'repository': order.repository,
        'agent': order.agent,
        'model': order.model,
        'mode': order.mode,
        'prompt': order.prompt,
      });
      expect(started.container, 'porelo-demo-${order.repository}');
      expect(started.task, order.repository, reason: 'the name the machine lists for that container');
      expect(hook.startedOn('demo', started.container), laptop);
    });

    // Harm: the offer of a started task is lost, so its end cannot be reported against it.
    test('an order\'s offer is kept beside the machine and the container it started in', () async {
      final order = (await plannedOrders()).first;

      final started = await starts()(MockPlanningSource('planner'), 'demo', 'ST291', order);

      expect(order.offer, isNotNull);
      final again = Settings(store);
      await again.load();
      expect(again.planningOffer('laptop', started.container), order.offer);
    });

    // Harm: a refused start reads as a started task, or its reason is replaced by the window's own words.
    test('a refusal by Start is a planning refusal in the machine\'s words, and keeps no offer', () async {
      final order = (await plannedOrders()).first;
      machine.answer = const StartProgress(
        container: 'porelo-demo-porelo',
        exitCode: 1,
        action: StartAction.running,
        output: ['porelo: the task porelo-demo-porelo is already running'],
      );

      await expectLater(
        starts()(MockPlanningSource('planner'), 'demo', 'ST291', order),
        throwsA(
          isA<PlanningRefusal>().having(
            planningFailureWords,
            'words',
            contains('porelo: the task porelo-demo-porelo is already running'),
          ),
        ),
      );
      expect(settings.planningOffer('laptop', 'porelo-demo-porelo'), isNull);
    });

    // Harm: a start that made its container and then failed reads as a started task, and its reason is lost.
    test('a start that made its task but failed is a planning refusal in its words, and keeps no offer', () async {
      final order = (await plannedOrders()).first;
      machine.answer = const StartProgress(
        container: 'porelo-demo_porelo',
        exitCode: 70,
        action: StartAction.create,
        output: ['porelo: the agent could not be started'],
      );

      await expectLater(
        starts()(MockPlanningSource('planner'), 'demo', 'ST291', order),
        throwsA(
          isA<PlanningRefusal>()
              .having((refusal) => refusal.name, 'name', 'StartRefused')
              .having(planningFailureWords, 'words', contains('porelo: the agent could not be started')),
        ),
      );
      expect(settings.planningOffer('laptop', 'porelo-demo_porelo'), isNull);
    });

    // Harm: a named refusal of the machine reaches the screen as a crash or a generic failure.
    test('a named refusal of the machine is a planning refusal with its name and words', () async {
      final order = (await plannedOrders()).first;
      machine.refusal = const VarlinkException('org.fuin.porelo.Tasks1.VaultLocked', {
        'detail': 'The vault is locked.',
      });

      await expectLater(
        starts()(MockPlanningSource('planner'), 'demo', 'ST291', order),
        throwsA(
          isA<PlanningRefusal>()
              .having((refusal) => refusal.name, 'name', 'VaultLocked')
              .having(planningFailureWords, 'words', contains('The vault is locked.')),
        ),
      );
    });

    // Harm: a planner's order runs twice, as two agents on the same work.
    test('an offer handed to Start before is refused, and nothing is started again', () async {
      final order = (await plannedOrders()).first;
      final source = MockPlanningSource('planner');
      await starts()(source, 'demo', 'ST291', order);

      await expectLater(starts()(source, 'demo', 'ST291', order), throwsA(isA<PlanningRefusal>()));
      expect(machine.started, hasLength(1));
    });

    // Harm: a task is started on no machine, or on one the person did not watch.
    test('no machine to start on is refused, and nothing is started', () async {
      final order = (await plannedOrders()).first;

      await expectLater(
        starts(on: null)(MockPlanningSource('planner'), 'demo', 'ST291', order),
        throwsA(isA<PlanningRefusal>()),
      );
      expect(machine.started, isEmpty);
    });

    // Harm: a discussion starts with an agent the person never chose, or as an ordinary task that may push.
    test('a discussion asks the person for agent and model and starts over every repository, read only', () async {
      final order = discussionOrder();
      final hook = starts();
      final asked = <(Machine, String, PlanningTaskOrder)>[];
      hook.chooseDiscussion = (machine, project, task) async {
        asked.add((machine, project, task));
        return (agent: 'pi', model: 'z-ai/glm-5.3-flash');
      };

      final started = await hook(MockPlanningSource('planner'), 'demo', '', order);

      expect(asked.single, (laptop, 'demo', order));
      expect(machine.started, isEmpty, reason: 'no repository is started on its own');
      expect(machine.discussed.single, {
        'project': 'demo',
        'agent': 'pi',
        'model': 'z-ai/glm-5.3-flash',
        'mode': 'AGENT',
        'prompt': order.prompt,
        'result': 'idea.json',
      });
      expect(started.container, 'porelo-demo-discussion');
      expect(started.task, 'discussion');
      expect(hook.startedOn('demo', started.container), laptop);
    });

    // Harm: a discussion the person turned away starts all the same, or uses up its offer.
    test('a discussion the person turns away starts nothing and keeps its offer unhanded', () async {
      final order = discussionOrder();
      final hook = starts()..chooseDiscussion = (machine, project, task) async => null;

      await expectLater(
        hook(MockPlanningSource('planner'), 'demo', '', order),
        throwsA(isA<PlanningRefusal>().having((refusal) => refusal.name, 'name', 'NotStarted')),
      );
      expect(machine.discussed, isEmpty);
      expect(settings.planningOfferHanded(order.offer!), isFalse);
    });

    // Harm: a discussion's offer is started twice, as two agents in the same talk.
    test('a discussion\'s offer is handed once, and a second start of it is refused', () async {
      final order = discussionOrder();
      final hook = starts()..chooseDiscussion = (machine, project, task) async => (agent: 'pi', model: 'm');
      await hook(MockPlanningSource('planner'), 'demo', '', order);

      await expectLater(hook(MockPlanningSource('planner'), 'demo', '', order), throwsA(isA<PlanningRefusal>()));
      expect(machine.discussed, hasLength(1));
    });

    // Harm: a machine that cannot read every repository fails as a crash, not in its own words.
    test('a machine that cannot start a discussion is a planning refusal in its words', () async {
      machine.refusal = const VarlinkException('org.fuin.porelo.Tasks1.NoRepositoryReadable', {
        'detail': 'No repository of demo can be read here.',
      });
      final hook = starts()..chooseDiscussion = (machine, project, task) async => (agent: 'pi', model: 'm');

      await expectLater(
        hook(MockPlanningSource('planner'), 'demo', '', discussionOrder()),
        throwsA(
          isA<PlanningRefusal>()
              .having((refusal) => refusal.name, 'name', 'NoRepositoryReadable')
              .having(planningFailureWords, 'words', contains('No repository of demo can be read here.')),
        ),
      );
    });

    // Harm: the person chooses an agent and a model for a discussion the machine cannot start, and the offer is used up.
    test(
      'a machine that cannot start a discussion is refused before the person is asked, its offer unhanded',
      () async {
        machine.noDiscussion = 'It needs a newer Porelo.';
        final order = discussionOrder();
        var asked = false;
        final hook = starts()
          ..chooseDiscussion = (machine, project, task) async {
            asked = true;
            return (agent: 'pi', model: 'm');
          };

        await expectLater(
          hook(MockPlanningSource('planner'), 'demo', '', order),
          throwsA(
            isA<PlanningRefusal>()
                .having((refusal) => refusal.name, 'name', 'NoDiscussion')
                .having(planningFailureWords, 'words', contains('It needs a newer Porelo.')),
          ),
        );
        expect(asked, isFalse);
        expect(machine.discussed, isEmpty);
        expect(settings.planningOfferHanded(order.offer!), isFalse);
      },
    );

    // Harm: the person chose for one machine, and the discussion starts on another, or on one no longer watched.
    test('a machine that no longer carries the project once the person chose starts nothing', () async {
      final order = discussionOrder();
      Machine? carrying = laptop;
      final hook =
          WindowTaskStarts(
              machineFor: (_) => carrying,
              backendOf: (_) => machine,
              settings: settings,
              providerOf: (_) => 'p',
            )
            ..chooseDiscussion = (machine, project, task) async {
              carrying = builder;
              return (agent: 'pi', model: 'm');
            };

      await expectLater(
        hook(MockPlanningSource('planner'), 'demo', '', order),
        throwsA(isA<PlanningRefusal>().having((refusal) => refusal.name, 'name', 'NoMachine')),
      );
      expect(machine.discussed, isEmpty);
      expect(settings.planningOfferHanded(order.offer!), isFalse);
    });

    // Harm: a discussion starts and the person is never shown its session, so nobody leads the talk.
    test('a started discussion is told with the task the machine lists for it', () async {
      final shown = <(Machine, String)>[];
      final hook = starts()
        ..chooseDiscussion = ((machine, project, task) async => (agent: 'pi', model: 'm'))
        ..onDiscussionStarted = (machine, task) => shown.add((machine, task.name));

      await hook(MockPlanningSource('planner'), 'demo', '', discussionOrder());

      expect(shown, [(laptop, 'porelo-demo-discussion')]);
    });

    // Harm: the end of a discussion is reported to a story it does not belong to.
    test('a discussion is kept as no story\'s task', () async {
      final order = discussionOrder();
      final hook = starts()..chooseDiscussion = (machine, project, task) async => (agent: 'pi', model: 'm');

      final started = await hook(MockPlanningSource('planner'), 'demo', '', order);

      expect(settings.planningOffer('laptop', started.container), isNull);
    });
  });
}

/// A planner's order to discuss an idea: no repository, no issue, the person driving it, a result file to hand back.
PlanningTaskOrder discussionOrder() => PlanningTaskOrder.from({
  'offer': '00000000-0000-4000-8000-00000000d15c',
  'issues': <String>[],
  'role': 'DISCUSSION',
  'agent': 'codex',
  'model': 'mock-model',
  'mode': 'AGENT',
  'prompt': 'Discuss this idea with the person, change nothing, and once they agree write idea.json.',
  'result': 'idea.json',
});

/// The tasks a planner orders for ST291's analysis, each with an offer and a prompt of its own.
Future<List<PlanningTaskOrder>> plannedOrders() async {
  final source = MockPlanningSource('planner');
  final proposal = await source.proposeStoryWork('demo', 'ST291', 'In analysis');
  final request = StoryWorkRequest(
    project: 'demo',
    story: 'ST291',
    to: 'In analysis',
    mode: proposal.modes.first,
    revision: proposal.revision,
    subAgents: [
      for (final repo in proposal.repositories)
        for (final sub in repo.subAgents) StoryWorkChoice(repository: repo.repository, name: sub.id, choice: 'DROP'),
    ],
    repositories: [
      for (final repo in proposal.repositories)
        StoryWorkMainAgent(repository: repo.repository, agent: repo.agent, model: repo.model),
    ],
    proposedRepositories: proposal.repositories,
    comment: 'Only the main agents work on it.',
    readingRounds: proposal.readingRounds,
  );
  final served = await source.startStoryWork(request);
  return StoryWorkOrder.from(
    {
      'revision': served.revision,
      'tasks': [
        for (final (index, task) in served.tasks.indexed)
          {
            'offer': '00000000-0000-4000-8000-${'$index'.padLeft(12, '0')}',
            'repository': task.repository,
            'issues': task.issues,
            'role': task.role,
            'agent': task.agent,
            'model': task.model,
            'mode': task.mode,
            'prompt': '  Work on ${task.repository}.\n',
          },
      ],
    },
    request: request,
    proposal: proposal,
  ).tasks;
}

/// A machine whose Start answers what a test sets, and lists each container it made under its repository's name.
class _Starting extends Fake implements FleetBackend {
  final started = <Map<String, Object>>[];
  StartProgress? answer;
  VarlinkException? refusal;
  final _listed = <Task>[];

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
    if (refusal case final refusal?) throw refusal;
    started.add({
      'project': project,
      'repository': repository,
      'agent': agent,
      'model': model,
      'mode': mode.name,
      'prompt': prompt,
    });
    final container = 'porelo-$project-$repository';
    final answer = this.answer ?? StartProgress(container: container, exitCode: 0, action: StartAction.create);
    if (answer.action?.starts ?? false) {
      _listed.add(Task.from({'name': container, 'task': repository, 'project': project, 'running': true}));
    }
    return answer;
  }

  final discussed = <Map<String, Object>>[];

  @override
  Future<StartProgress> startDiscussion({
    required String project,
    required String agent,
    required String model,
    required Mode mode,
    required String prompt,
    required String result,
  }) async {
    if (refusal case final refusal?) throw refusal;
    discussed.add({
      'project': project,
      'agent': agent,
      'model': model,
      'mode': mode.name,
      'prompt': prompt,
      'result': result,
    });
    final container = 'porelo-$project-discussion';
    _listed.add(Task.from({'name': container, 'task': 'discussion', 'project': project, 'running': true}));
    return StartProgress(container: container, exitCode: 0, action: StartAction.create);
  }

  @override
  Future<List<Task>> tasks() async => List.of(_listed);

  /// Why this machine cannot start a discussion, or null where it can.
  String? noDiscussion;

  @override
  Future<String?> whyNoDiscussion() async => noDiscussion;
}
