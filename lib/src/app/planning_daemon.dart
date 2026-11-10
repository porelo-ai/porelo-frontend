import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_planning/porelo_planning.dart'
    show PlanningClient, PlanningProvider, PlanningRefusal, PlanningSource, PlanningTaskEvent, PlanningUnsupported;

import 'fleet_backend.dart';
import 'fleet_model.dart';
import 'machines.dart';

/// A daemon's planning failure in the planning package's words; anything else stays as it is.
Object planningErrorOf(Object error) => switch (error) {
  VarlinkException() => PlanningRefusal(error.simpleName, error.parameters, error.toString(), error.isMethodNotFound),
  FeatureNotSupported() => PlanningUnsupported(error.toString()),
  _ => error,
};

Future<T> _answered<T>(Future<T> Function() call) async {
  try {
    return await call();
  } catch (error, stack) {
    final mapped = planningErrorOf(error);
    if (identical(mapped, error)) rethrow;
    Error.throwWithStackTrace(mapped, stack);
  }
}

/// One machine's daemon as a provider of planning: its own calls, its failures in the package's words.
class FleetPlanningSource implements PlanningSource {
  /// The one source of [fleet], so a board can tell by identity whether its machine was replaced.
  factory FleetPlanningSource(FleetBackend fleet) => _sources[fleet] ??= FleetPlanningSource._(fleet);

  FleetPlanningSource._(this.fleet);

  static final _sources = Expando<FleetPlanningSource>();

  /// The machine's daemon.
  final FleetBackend fleet;

  @override
  String get label => fleet.label;

  @override
  Stream<PlanningSnapshot> watchStories(String project) {
    final Stream<PlanningSnapshot> replies;
    try {
      replies = fleet.watchStories(project);
    } catch (error, stack) {
      final mapped = planningErrorOf(error);
      if (identical(mapped, error)) rethrow;
      Error.throwWithStackTrace(mapped, stack);
    }
    return replies.transform(
      StreamTransformer.fromHandlers(handleError: (error, stack, sink) => sink.addError(planningErrorOf(error), stack)),
    );
  }

  @override
  Future<PlanningSnapshot> planningWorkflow(String project) => _answered(() => fleet.planningWorkflow(project));

  @override
  Future<PlanningSnapshot> stories(String project) => _answered(() => fleet.stories(project));

  @override
  Future<PlanningMoveResult> saveMoves(String project, List<PlanningMove> moves, String revision) =>
      _answered(() => fleet.saveMoves(project, moves, revision));

  @override
  Future<PlanStoryDetail> getStory(String project, String story) => _answered(() => fleet.getStory(project, story));

  @override
  Future<PlanIssueList> listStoryIssues(String project, String story) =>
      _answered(() => fleet.listStoryIssues(project, story));

  @override
  Future<PlanIssueDetail> getIssue(String project, String issue) => _answered(() => fleet.getIssue(project, issue));

  @override
  Future<StoryWorkProposal> proposeStoryWork(String project, String story, String to) =>
      _answered(() => fleet.proposeStoryWork(project, story, to));

  @override
  Future<StoryWorkStatus> getStoryWork(String project, String story) =>
      _answered(() => fleet.getStoryWork(project, story));

  @override
  Future<StoryWorkStatus> stopStoryWork(String project, String story) =>
      _answered(() => fleet.stopStoryWork(project, story));

  @override
  Future<PlanningIssueDetail> getPlanningIssue(String project, String issue) =>
      _answered(() => fleet.getPlanningIssue(project, issue));

  @override
  Future<ReadingResolution> resolveIssueReading(
    String project,
    String story,
    String issue,
    int round,
    String choice,
    String revision, {
    String? comment,
  }) => _answered(() => fleet.resolveIssueReading(project, story, issue, round, choice, revision, comment: comment));

  /// The agents this machine offers a start, failures in the package's words.
  Future<AgentsOnTheMachine> agentsOn() => _answered(fleet.agentsOn);

  /// Starts story work on this machine's daemon, as the window has always started it.
  Future<StoryWorkStarted> startStoryWork(StoryWorkRequest request) => _answered(() => fleet.startStoryWork(request));
}

/// How a start of story work reaches the window: through the chosen machine's own story-work start.
Future<StoryWorkStarted> daemonStartTask(PlanningSource source, StoryWorkRequest request) =>
    (source as FleetPlanningSource).startStoryWork(request);

/// The watched machines as providers of planning, each answering from its own daemon.
class DaemonPlanningClient implements PlanningClient {
  /// Follows [machines], whose changes are the providers' changes.
  DaemonPlanningClient(this.machines);

  /// The watched machines.
  final Machines machines;

  @override
  void addListener(VoidCallback listener) => machines.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => machines.removeListener(listener);

  @override
  List<PlanningProvider> get providers => [
    for (final machine in machines.all)
      PlanningProvider(
        name: machine.name,
        connected: machines.of(machine).reachability == Reachability.connected,
        projects: [for (final project in machines.of(machine).listedProjects) project.name],
        source: FleetPlanningSource(machines.of(machine).backend),
      ),
  ];

  @override
  String? get currentProvider => machines.current.name;

  @override
  String? get chosenProject => machines.fleet.selectedProject?.name;

  /// Nothing to tell: the daemon follows the tasks it starts itself, so a change reaches the board through its watch.
  @override
  Future<void> taskEvent(String project, String task, PlanningTaskEvent event) async {}
}
