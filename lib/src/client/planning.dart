part of 'porelo_client.dart';

String _planText(Map<String, dynamic> map, String key) => map[key] is String ? map[key] as String : '';

/// The planning methods served by the daemon.
extension PlanningCalls on PoreloClient {
  /// Saves the entire reviewed batch in one atomic daemon call.
  Future<PlanningMoveResult> saveMoves(String project, List<PlanningMove> moves, String revision) async =>
      PlanningMoveResult.from(
        await _call('SaveMoves', {
          'project': project,
          'moves': moves.map((move) => move.toMap()).toList(),
          'revision': revision,
        }),
      );

  /// Explicitly refreshes the adapter store.
  Future<String> refreshStories(String project) async =>
      _planText(await _call('RefreshStories', {'project': project}), 'revision');

  /// Reads one story and its source text.
  Future<PlanStoryDetail> getStory(String project, String story) async =>
      PlanStoryDetail.from(await _call('GetStory', {'project': project, 'story': story}));

  /// Reads exactly the issues of one story.
  Future<PlanIssueList> listStoryIssues(String project, String story) async =>
      PlanIssueList.from(await _call('ListStoryIssues', {'project': project, 'story': story}));

  /// Reads one issue and its last reader report.
  Future<PlanIssueDetail> getIssue(String project, String issue) async =>
      PlanIssueDetail.from(await _call('GetIssue', {'project': project, 'issue': issue}));

  /// Reads a project's workflow.
  Future<PlanningSnapshot> planningWorkflow(String project) async =>
      PlanningSnapshot.from(await _call('GetPlanningWorkflow', {'project': project}));

  /// Reads a project's stories and revision.
  Future<PlanningSnapshot> stories(String project, {List<String>? states}) async =>
      PlanningSnapshot.from(await _call('ListStories', {'project': project, 'states': ?states}));

  /// Watches whole-board replacements, including the first reply immediately.
  Stream<PlanningSnapshot> watchStories(String project) {
    final replies = StreamController<PlanningSnapshot>();
    StreamSubscription<Map<String, dynamic>>? subscription;
    bool cancelled = false, fallingBack = false;
    replies.onListen = () {
      subscription = _callMore('WatchStories', {'project': project}).listen(
        (reply) => replies.add(PlanningSnapshot.from(reply)),
        onError: (Object error, StackTrace stack) async {
          if (error is VarlinkException && error.simpleName == 'NotYetBuilt') {
            fallingBack = true;
            try {
              final reply = await _call('WatchStories', {'project': project});
              if (!cancelled) replies.add(PlanningSnapshot.from(reply));
            } catch (failure, trace) {
              if (!cancelled) replies.addError(failure, trace);
            }
            if (!cancelled) await replies.close();
          } else if (!cancelled) {
            replies.addError(error, stack);
          }
        },
        onDone: () {
          if (!cancelled && !fallingBack && !replies.isClosed) unawaited(replies.close());
        },
      );
    };
    replies.onCancel = () {
      cancelled = true;
      return subscription?.cancel();
    };
    return replies.stream;
  }
}

/// Story work methods served by the daemon.
extension StoryWorkCalls on PoreloClient {
  /// Reads the proposed tasks and participants for a working state.
  Future<StoryWorkProposal> proposeStoryWork(String project, String story, String to) async =>
      StoryWorkProposal.from(await _call('ProposeStoryWork', {'project': project, 'story': story, 'to': to}));

  /// Starts story work with explicit choices and the board revision.
  Future<StoryWorkStarted> startStoryWork(StoryWorkRequest request) async =>
      StoryWorkStarted.from(await _call('StartStoryWork', request.toMap()));

  /// Reads current work and any ended outcome for a story.
  Future<StoryWorkStatus> getStoryWork(String project, String story) async =>
      StoryWorkStatus.from(await _call('GetStoryWork', {'project': project, 'story': story}));

  /// Stops the story’s work without changing its planning state.
  Future<StoryWorkStatus> stopStoryWork(String project, String story) async =>
      StoryWorkStatus.from(await _call('StopStoryWork', {'project': project, 'story': story}));

  /// Reads the issue’s last findings from GetIssue.
  Future<PlanningIssueDetail> getPlanningIssue(String project, String issue) async =>
      PlanningIssueDetail.from(await _call('GetIssue', {'project': project, 'issue': issue}));

  /// Sends a revision-bound decision for one stopped reading round.
  Future<ReadingResolution> resolveIssueReading(
    String project,
    String story,
    String issue,
    int round,
    String choice,
    String revision, {
    String? comment,
  }) async => ReadingResolution.from(
    await _call('ResolveIssueReading', {
      'project': project,
      'story': story,
      'issue': issue,
      'round': round,
      'choice': choice,
      'revision': revision,
      'comment': comment ?? '',
    }),
  );
}

/// The tasks a confirmed start returned, as this window's own task records.
extension StoryWorkStartedTasks on StoryWorkStarted {
  /// Runtime tasks reported by the authoritative start answer.
  List<Task> get tasks => tasksFor('');

  /// Supplies the project captured by the request when opening runtime tasks.
  List<Task> tasksFor(String project) => [
    for (final task in work?.tasks ?? <PlanWorkTask>[])
      Task.from({
        'name': task.task,
        'project': project,
        'containerId': task.containerId,
        'repository': task.repository,
        'agent': task.agent,
        'model': task.model,
        'running': task.atWork == true,
        'mode': task.mode == 'AGENT' ? 'SHELL' : task.mode,
        'state': task.state,
      }),
  ];

  /// The returned running participant matching the terminal identity.
  Task? get terminalTask =>
      terminalName == null ? null : tasks.where((task) => task.name == terminalName && task.running).firstOrNull;
}
