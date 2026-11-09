part of 'porelo_client.dart';

String _planText(Map<String, dynamic> map, String key) => map[key] is String ? map[key] as String : '';
List<String> _planStrings(Object? value) =>
    value is List ? value.whereType<String>().where((text) => text.trim().isNotEmpty).toList() : const [];
bool _planMapsReported(Object? value) => value is List && value.every((entry) => entry is Map<String, dynamic>);
bool _planStringsReported(Object? value) =>
    value is List && value.every((entry) => entry is String && entry.trim().isNotEmpty);
List<T> _planList<T>(Object? value, T Function(Map<String, dynamic>) read) =>
    value is List ? value.whereType<Map<String, dynamic>>().map(read).toList() : <T>[];

/// One state, with the machine's kind preserved even when unknown.
class PlanState {
  /// Reads fields without inventing an absent kind or completion rule.
  PlanState.from(Map<String, dynamic> map)
    : name = _planText(map, 'name'),
      kind = _planText(map, 'kind'),
      done = map['done'] is String ? map['done'] as String : null;

  /// The configured name.
  final String name;

  /// `WAITING`, `WORKING`, `CLOSED`, unknown, or empty when unsaid.
  final String kind;

  /// The completion rule, when reported.
  final String? done;
}

/// A configured column and the names of its states.
class PlanPhase {
  /// Reads a phase in its reported order.
  PlanPhase.from(Map<String, dynamic> map) : name = _planText(map, 'name'), states = _planStrings(map['states']);

  /// The column's name.
  final String name;

  /// Its states, in order.
  final List<String> states;
}

/// Work reported for a story, without inferring whether anyone is working.
class PlanWork {
  /// Reads the daemon's report.
  PlanWork.from(Map<String, dynamic> map)
    : tasks = _planStrings(map['tasks']),
      coordinator = map['coordinator'] is String ? map['coordinator'] as String : null,
      mode = _planText(map, 'mode'),
      agent = _planText(map, 'agent'),
      model = _planText(map, 'model'),
      since = _planText(map, 'since'),
      atWork = map['atWork'] is bool ? map['atWork'] as bool : null;

  /// The participating tasks.
  final List<String> tasks;

  /// The coordinator, if named.
  final String? coordinator;

  /// The mode as reported, including unknown modes.
  final String mode;

  /// The agent as reported.
  final String agent;

  /// The model as reported.
  final String model;

  /// The reported start instant.
  final String since;

  /// Whether work runs, or null when unsaid.
  final bool? atWork;
}

/// One issue belonging to a story.
class PlanIssue {
  /// Reads fields leniently.
  PlanIssue.from(Map<String, dynamic> map)
    : id = _planText(map, 'id'),
      repository = _planText(map, 'repository'),
      title = _planText(map, 'title'),
      state = _planText(map, 'state'),
      size = _planText(map, 'size'),
      blockedBy = _planStrings(map['blockedBy']),
      blockedByReported = _planStringsReported(map['blockedBy']),
      story = _planText(map, 'story'),
      revision = _planText(map, 'revision'),
      link = _planText(map, 'link'),
      rounds = map['rounds'] is int ? map['rounds'] as int : null,
      roundsMost = map['roundsMost'] is int ? map['roundsMost'] as int : null,
      readingStopped = map['readingStopped'] is bool ? map['readingStopped'] as bool : null;

  /// The issue's identifier.
  final String id;

  /// Its repository.
  final String repository;

  /// Its title.
  final String title;

  /// Its reported state.
  final String state;

  /// Its size, empty when unsaid.
  final String size;

  /// The identifiers blocking it.
  final List<String> blockedBy;

  /// Whether blockers were actually reported.
  final bool blockedByReported;

  /// Its owning story, when reported.
  final String story;

  /// Its opaque revision, when reported.
  final String revision;

  /// Its web link.
  final String link;

  /// The reading round as reported, or null when unsaid.
  final int? rounds;

  /// The machine's reading round limit, or null when unsaid.
  final int? roundsMost;

  /// Whether the machine stopped this issue in Reading, or null when unsaid.
  final bool? readingStopped;
}

/// One story, whose state is always the machine's answer.
class PlanStory {
  /// Reads fields leniently and preserves unknown priorities.
  PlanStory.from(Map<String, dynamic> map)
    : id = _planText(map, 'id'),
      title = _planText(map, 'title'),
      state = _planText(map, 'state'),
      priority = _planText(map, 'priority'),
      revision = _planText(map, 'revision'),
      gain = _planText(map, 'gain'),
      test = _planText(map, 'test'),
      issues = _planList(map['issues'], PlanIssue.from),
      issuesReported = _planMapsReported(map['issues']),
      link = _planText(map, 'link'),
      work = map['work'] is Map<String, dynamic> ? PlanWork.from(map['work'] as Map<String, dynamic>) : null,
      ended = map['ended'] is Map<String, dynamic> ? StoryWorkEnded.from(map['ended'] as Map<String, dynamic>) : null,
      workReported = map.containsKey('work'),
      endedReported = map.containsKey('ended');

  /// Its identifier.
  final String id;

  /// Its title.
  final String title;

  /// Its reported state.
  final String state;

  /// Its reported priority, empty when unsaid.
  final String priority;

  /// Its opaque revision, when reported.
  final String revision;

  /// What it gains.
  final String gain;

  /// The acceptance test in words.
  final String test;

  /// Its issues, empty when unsaid.
  final List<PlanIssue> issues;

  /// Whether the daemon actually sent an issue list.
  final bool issuesReported;

  /// Its web link.
  final String link;

  /// Whether the watch supplied work status, including an explicitly absent work record.
  final bool workReported;

  /// Whether the watch supplied the ended outcome, including an explicitly cleared outcome.
  final bool endedReported;

  /// Its work, when reported.
  final PlanWork? work;

  /// Why the story stopped before reaching its done state.
  final StoryWorkEnded? ended;

  /// The number in Review or Finished, when the list and every issue state were reported.
  int? get completedIssues => issuesReported && issues.every((issue) => issue.state.isNotEmpty)
      ? issues.where((issue) => issue.state == 'Review' || issue.state == 'Finished').length
      : null;
}

/// A workflow or a whole board reply; absent fields stay empty.
class PlanningSnapshot {
  /// Reads a snapshot without deriving story states.
  PlanningSnapshot.from(Map<String, dynamic> map)
    : states = _planList(map['states'], PlanState.from),
      phases = _planList(map['phases'], PlanPhase.from),
      stories = _planList(map['stories'], PlanStory.from),
      revision = _planText(map, 'revision'),
      statesReported = map['states'] is List,
      phasesReported = map['phases'] is List,
      storiesReported = map['stories'] is List;

  /// Combines the separate workflow and story reads without deriving any states.
  PlanningSnapshot.fromParts(PlanningSnapshot workflow, PlanningSnapshot board)
    : states = workflow.states,
      phases = workflow.phases,
      stories = board.stories,
      revision = board.revision,
      statesReported = workflow.statesReported,
      phasesReported = workflow.phasesReported,
      storiesReported = board.storiesReported;

  /// Whether the daemon sent the state list.
  final bool statesReported;

  /// Whether the daemon sent the phase list.
  final bool phasesReported;

  /// Whether the daemon sent the story list.
  final bool storiesReported;

  /// Whether this is a complete whole-board reply.
  bool get complete => statesReported && phasesReported && storiesReported;

  /// The workflow's state order.
  final List<PlanState> states;

  /// The workflow's phase order.
  final List<PlanPhase> phases;

  /// The complete story list when present.
  final List<PlanStory> stories;

  /// The daemon's opaque revision.
  final String revision;
}

/// One destination in an atomic planning save.
sealed class PlanningMove {
  /// Allows story and issue destinations in the same reviewed batch.
  const PlanningMove();

  /// The work identifier.
  String get id;

  /// The requested state.
  String get to;

  /// The wire fields identifying the kind of work.
  Map<String, dynamic> toMap();
}

/// One story destination in an atomic board save.
class PlanningStoryMove extends PlanningMove {
  /// Keeps the daemon's story identifier and destination.
  const PlanningStoryMove(this.story, this.to);

  /// The story to move.
  final String story;

  /// The requested state.
  @override
  final String to;

  @override
  String get id => story;

  /// The wire fields.
  @override
  Map<String, dynamic> toMap() => {'story': story, 'to': to};
}

/// One issue destination sent as part of an atomic issue move.
class PlanningIssueMove extends PlanningMove {
  /// Keeps the daemon's issue identifier and destination.
  const PlanningIssueMove(this.issue, this.to);

  /// The issue to move.
  final String issue;

  /// The destination state.
  @override
  final String to;

  @override
  String get id => issue;

  /// The wire fields.
  @override
  Map<String, dynamic> toMap() => {'issue': issue, 'to': to};
}

/// The daemon's confirmation, without inventing a missing result or revision.
class PlanningMoveResult extends PlanningSnapshot {
  /// Reads the stand-in move reply.
  PlanningMoveResult.from(super.map) : moved = map['moved'] == true, super.from();

  /// Whether the daemon moved the requested work.
  final bool moved;
}

/// One finding from the reader's last report, preserving unknown severities.
class PlanFinding {
  /// Reads optional locations without manufacturing a file or line.
  PlanFinding.from(Map<String, dynamic> map)
    : number = map['number'] is int ? map['number'] as int : null,
      severity = _planText(map, 'severity'),
      text = _planText(map, 'text'),
      file = map['file'] is String && (map['file'] as String).isNotEmpty ? map['file'] as String : null,
      line = map['line'] is int ? map['line'] as int : null;

  /// The reported number, absent when malformed or unsaid.
  final int? number;

  /// BLOCKING, NOTE, an unknown value, or empty when unsaid.
  final String severity;

  /// The reader's words.
  final String text;

  /// The file, if given.
  final String? file;

  /// The line, if given.
  final int? line;
}

/// A sub-agent reported for an issue.
class PlanSubAgent {
  /// Preserves each field independently.
  PlanSubAgent.from(Map<String, dynamic> map)
    : name = _planText(map, 'name'),
      role = _planText(map, 'role'),
      agent = _planText(map, 'agent'),
      model = _planText(map, 'model'),
      brief = _planText(map, 'brief');

  /// Its name.
  final String name;

  /// Its role.
  final String role;

  /// Its agent.
  final String agent;

  /// Its model.
  final String model;

  /// Its brief.
  final String brief;
}

/// The standalone story and its source text.
class PlanStoryDetail {
  /// Keeps a missing record distinct from an empty story.
  PlanStoryDetail.from(Map<String, dynamic> map)
    : story = map['story'] is Map<String, dynamic> ? PlanStory.from(map['story'] as Map<String, dynamic>) : null,
      text = _planText(map, 'text');

  /// The story, when supplied.
  final PlanStory? story;

  /// Its Markdown source.
  final String text;
}

/// A separately read issue list; an omitted list is never an empty list.
class PlanIssueList {
  /// Reads the list and its presence.
  PlanIssueList.from(Map<String, dynamic> map)
    : issues = _planList(map['issues'], PlanIssue.from),
      reported = _planMapsReported(map['issues']),
      supplied = map['issues'] != null;

  /// The issues supplied.
  final List<PlanIssue> issues;

  /// Whether the daemon supplied a complete list.
  final bool reported;

  /// Whether any issue-list payload was supplied.
  final bool supplied;
}

/// The standalone issue, acceptance criteria, last findings and sub-agents.
class PlanIssueDetail {
  /// Reads additive fields leniently without inventing absent reports.
  PlanIssueDetail.from(Map<String, dynamic> map)
    : issue = map['issue'] is Map<String, dynamic> ? PlanIssue.from(map['issue'] as Map<String, dynamic>) : null,
      text = _planText(map, 'text'),
      whatMustBeTrue = _planStrings(map['whatMustBeTrue']),
      criteriaReported = _planStringsReported(map['whatMustBeTrue']),
      criteriaSupplied = map['whatMustBeTrue'] != null,
      findings = _planList(map['findings'], PlanFinding.from),
      findingsReported = _planMapsReported(map['findings']),
      findingsSupplied = map['findings'] != null,
      subAgents = _planList(map['subAgents'], PlanSubAgent.from),
      subAgentsReported = _planMapsReported(map['subAgents']),
      subAgentsSupplied = map['subAgents'] != null;

  /// The issue when supplied.
  final PlanIssue? issue;

  /// Its Markdown source.
  final String text;

  /// Its acceptance criteria.
  final List<String> whatMustBeTrue;

  /// Whether acceptance criteria were supplied completely.
  final bool criteriaReported;

  /// Whether any acceptance criteria payload was supplied.
  final bool criteriaSupplied;

  /// The reader's last findings, in the reported order.
  final List<PlanFinding> findings;

  /// Whether the findings report is complete.
  final bool findingsReported;

  /// Whether any findings payload was supplied.
  final bool findingsSupplied;

  /// The reported sub-agents.
  final List<PlanSubAgent> subAgents;

  /// Whether the sub-agent list is complete.
  final bool subAgentsReported;

  /// Whether any sub-agent payload was supplied.
  final bool subAgentsSupplied;

  /// BLOCKING first, NOTE next, then unknown severities; report order within each group.
  List<PlanFinding> get orderedFindings => [
    ...findings.where((finding) => finding.severity == 'BLOCKING'),
    ...findings.where((finding) => finding.severity == 'NOTE'),
    ...findings.where((finding) => !{'BLOCKING', 'NOTE'}.contains(finding.severity)),
  ];
}

/// The stand-in planning protocol, isolated here until served by the daemon.
extension PlanningClient on PoreloClient {
  /// Saves staged stories and issues atomically and reads the resulting board and issue states.
  Future<PlanningMoveResult> moveStories(String project, List<PlanningMove> moves, String revision) async =>
      PlanningMoveResult.from(
        await _call('MoveStories', {
          'project': project,
          'moves': moves.map((move) => move.toMap()).toList(),
          'revision': revision,
        }),
      );

  /// Moves one story using the revision read before staging moves.
  Future<PlanningMoveResult> moveStory(String project, String story, String to, String revision) async =>
      PlanningMoveResult.from(
        await _call('MoveStory', {'project': project, 'story': story, 'to': to, 'revision': revision}),
      );

  /// Moves issues atomically using the daemon's current revision.
  Future<PlanningMoveResult> moveIssues(String project, List<PlanningIssueMove> moves, String revision) async =>
      PlanningMoveResult.from(
        await _call('MoveIssues', {
          'project': project,
          'moves': moves.map((move) => move.toMap()).toList(),
          'revision': revision,
        }),
      );

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
  Future<PlanningSnapshot> stories(String project) async =>
      PlanningSnapshot.from(await _call('ListStories', {'project': project}));

  /// Watches whole-board replacements, including the first reply immediately.
  Stream<PlanningSnapshot> watchStories(String project) =>
      _callMore('WatchStories', {'project': project}).map(PlanningSnapshot.from);
}

/// The machine's reason for an ended story run.
class StoryWorkEnded {
  /// Reads the machine’s reported fields.
  StoryWorkEnded.from(Map<String, dynamic> map) : at = _planText(map, 'at'), reason = _planText(map, 'reason');

  /// The instant reported by the machine, empty when unsaid.
  final String at;

  /// The machine’s verbatim explanation.
  final String reason;
}

/// One proposed participant, including the reader.
class StoryWorkSubAgent {
  /// Reads the machine’s reported fields.
  StoryWorkSubAgent.from(Map<String, dynamic> map)
    : name = _planText(map, 'name'),
      role = _planText(map, 'role'),
      agent = _planText(map, 'agent'),
      model = _planText(map, 'model'),
      brief = _planText(map, 'brief');

  /// The proposed participant’s name within its repository.
  final String name;

  /// The role as reported, including unknown roles.
  final String role;

  /// The agent identifier named by the machine or selected for a replacement.
  final String agent;

  /// The model identifier, including an explicitly empty default.
  final String model;

  /// The participant’s work order as supplied by the machine.
  final String brief;
}

/// A repository's task and its proposed participants.
class StoryWorkRepository {
  /// Reads the machine’s reported fields.
  StoryWorkRepository.from(Map<String, dynamic> map)
    : repository = _planText(map, 'repository'),
      task = _planText(map, 'task'),
      agent = _planText(map, 'agent'),
      model = _planText(map, 'model'),
      modelHint = _planText(map, 'modelHint'),
      workOrder = _planText(map, 'workOrder'),
      issues = _planStrings(map['issues']),
      subAgents = _planList(map['subAgents'], StoryWorkSubAgent.from);

  /// The repository name supplied by the machine.
  final String repository;

  /// The task name supplied by the machine.
  final String task;

  /// The agent identifier named by the machine or selected for a replacement.
  final String agent;

  /// The model identifier, including an explicitly empty default.
  final String model;

  /// The machine's explanation of the proposed model.
  final String modelHint;

  /// The main agent's work order, shown read-only.
  final String workOrder;

  /// The issues covered by this task, as named by the proposal.
  final List<String> issues;

  /// The proposed participants, or the explicit choices sent at start.
  final List<StoryWorkSubAgent> subAgents;
}

/// An issue whose reading limit can be overridden at start.
class StoryWorkIssue {
  /// Reads the machine’s reported fields.
  StoryWorkIssue.from(Map<String, dynamic> map) : id = _planText(map, 'id'), repository = _planText(map, 'repository');

  /// The issue identifier supplied by the machine.
  final String id;

  /// The repository name supplied by the machine.
  final String repository;
}

/// The complete proposal for a start; missing limits are never invented.
class StoryWorkProposal {
  /// Reads the machine’s reported fields.
  StoryWorkProposal.from(Map<String, dynamic> map)
    : modes = _planStrings(map['modes']),
      repositories = _planList(map['repositories'], StoryWorkRepository.from),
      coordinator = map['coordinator'] is Map<String, dynamic>
          ? StoryWorkCoordinator.from(map['coordinator'] as Map<String, dynamic>)
          : null,
      readingRounds = map['readingRounds'] is int ? map['readingRounds'] as int : null,
      issues = _planList(map['issues'], StoryWorkIssue.from),
      modeDetails = _planList(map['modeDetails'], StoryWorkMode.from),
      startLabel = _planText(map, 'startLabel');

  /// The daemon's explanations and work orders for the allowed modes.
  final List<StoryWorkMode> modeDetails;

  /// The action-specific start button label, when supplied.
  final String startLabel;

  /// The modes the project permits, preserving unknown values.
  final List<String> modes;

  /// The proposed repository tasks in the machine’s order.
  final List<StoryWorkRepository> repositories;

  /// The proposed coordinator, when supplied.
  final StoryWorkCoordinator? coordinator;

  /// The proposed or selected overall reading limit, null when unsaid.
  final int? readingRounds;

  /// The issues available for per-issue reading limits.
  final List<StoryWorkIssue> issues;
}

/// The daemon's words describing one way of working.
class StoryWorkMode {
  /// Reads a mode description without inventing missing words.
  StoryWorkMode.from(Map<String, dynamic> map)
    : mode = _planText(map, 'mode'),
      words = _planText(map, 'words'),
      workOrder = _planText(map, 'workOrder');

  /// The wire mode described.
  final String mode;

  /// What this involvement means, in the machine's words.
  final String words;

  /// The main work order for this mode.
  final String workOrder;
}

/// A proposed coordinator and whether it is started or told about the story.
class StoryWorkCoordinator {
  /// Reads the daemon's proposal and action sentence.
  StoryWorkCoordinator.from(Map<String, dynamic> map)
    : agent = _planText(map, 'agent'),
      model = _planText(map, 'model'),
      sentence = _planText(map, 'sentence');

  /// The proposed agent.
  final String agent;

  /// The proposed model.
  final String model;

  /// Whether the coordinator starts or is told, in the machine's words.
  final String sentence;
}

/// The main agent and model chosen for one repository.
class StoryWorkMainAgent {
  /// Keeps the repository identity and explicit main-agent choice.
  const StoryWorkMainAgent({required this.repository, required this.agent, required this.model});

  /// The repository the choice applies to.
  final String repository;

  /// The chosen agent identifier.
  final String agent;

  /// The chosen model identifier.
  final String model;

  /// Serializes the fields accepted by StartStoryWork.
  Map<String, dynamic> toMap() => {'repository': repository, 'agent': agent, 'model': model};
}

/// The explicit choice for one proposed sub-agent.
class StoryWorkChoice {
  /// Keeps the source facts and choices for this view or decision.
  const StoryWorkChoice({required this.repository, required this.name, required this.choice, this.agent, this.model});

  /// The repository name supplied by the machine.
  final String repository;

  /// The proposed participant’s name within its repository.
  final String name;

  /// The explicit KEEP, CHANGE or DROP choice.
  final String choice;

  /// The agent identifier named by the machine or selected for a replacement.
  final String? agent;

  /// The model identifier, including an explicitly empty default.
  final String? model;

  /// Serializes the exact fields sent to the daemon, omitting absent overrides.
  Map<String, dynamic> toMap() => {
    'repository': repository,
    'name': name,
    'choice': choice,
    if (agent != null) 'agent': agent,
    if (model != null) 'model': model,
  };
}

/// A revision-bound start decision.
class StoryWorkRequest {
  /// Keeps the source facts and choices for this view or decision.
  const StoryWorkRequest({
    required this.project,
    required this.story,
    required this.to,
    required this.mode,
    required this.revision,
    required this.subAgents,
    this.repositories = const [],
    this.comment,
    this.readingRounds,
    this.issueReadingRounds = const {},
  });

  /// The project name sent to the machine.
  final String project;

  /// The story identifier reported by the board.
  final String story;

  /// The target working state named by the workflow.
  final String to;

  /// The explicitly selected wire mode.
  final String mode;

  /// The opaque revision used to bind this decision.
  final String revision;

  /// The proposed participants, or the explicit choices sent at start.
  final List<StoryWorkChoice> subAgents;

  /// The chosen main agent and model for every proposed repository.
  final List<StoryWorkMainAgent> repositories;

  /// The explanation for changed or dropped participants.
  final String? comment;

  /// The proposed or selected overall reading limit, null when unsaid.
  final int? readingRounds;

  /// Explicit issue limits, omitted on the wire when there are no overrides.
  final Map<String, int> issueReadingRounds;

  /// Serializes the exact fields sent to the daemon, omitting absent overrides.
  Map<String, dynamic> toMap() => {
    'project': project,
    'story': story,
    'to': to,
    'mode': mode,
    'revision': revision,
    'subAgents': subAgents.map((each) => each.toMap()).toList(),
    'repositories': repositories.map((each) => each.toMap()).toList(),
    'comment': ?comment,
    if (readingRounds != null) 'readingRounds': readingRounds,
    if (issueReadingRounds.isNotEmpty)
      'issueReadingRounds': [
        for (final each in issueReadingRounds.entries) {'issue': each.key, 'rounds': each.value},
      ],
  };
}

/// Whether the machine accepted the start, and its resulting revision.
class StoryWorkStarted {
  /// Reads the machine’s reported fields.
  StoryWorkStarted.from(Map<String, dynamic> map)
    : started = map['started'] == true,
      revision = _planText(map, 'revision'),
      tasks = _planList(map['tasks'], Task.from),
      coordinator = map['coordinator'] is Map<String, dynamic>
          ? Task.from(map['coordinator'] as Map<String, dynamic>)
          : null;

  /// The started tasks returned by the same authoritative start answer.
  final List<Task> tasks;

  /// The coordinator returned by the start, when several repositories need one.
  final Task? coordinator;

  /// The task whose terminal With you opens.
  Task? get terminalTask {
    final task = coordinator ?? (tasks.length == 1 ? tasks.single : null);
    return task != null && task.name.isNotEmpty && task.running ? task : null;
  }

  /// Whether the daemon confirmed that story work started.
  final bool started;

  /// The opaque revision used to bind this decision.
  final String revision;
}

/// The work and any ended outcome returned by GetStoryWork.
class StoryWorkStatus {
  /// Reads the machine’s reported fields.
  StoryWorkStatus.from(Map<String, dynamic> map)
    : work = map['work'] is Map<String, dynamic> ? PlanWork.from(map['work'] as Map<String, dynamic>) : null,
      ended = map['ended'] is Map<String, dynamic> ? StoryWorkEnded.from(map['ended'] as Map<String, dynamic>) : null;

  /// The work status reported by the daemon.
  final PlanWork? work;

  /// The machine’s reported reason and instant for an ended story run.
  final StoryWorkEnded? ended;
}

/// One last reading finding, preserving unknown severity words.
class ReadingFinding {
  /// Reads the machine’s reported fields.
  ReadingFinding.from(Map<String, dynamic> map) : severity = _planText(map, 'severity'), text = _planText(map, 'text');

  /// The finding’s severity, preserving unknown values.
  final String severity;

  /// The finding’s words supplied by the machine.
  final String text;
}

/// The findings returned by GetIssue, separate from the compact board summary.
class PlanningIssueDetail {
  /// Reads the machine’s reported fields.
  PlanningIssueDetail.from(Map<String, dynamic> map)
    : findings = _planList(map['findings'], ReadingFinding.from),
      findingsReported =
          map['findings'] is List &&
          (map['findings'] as List).every(
            (each) => each is Map<String, dynamic> && each['severity'] is String && each['text'] is String,
          );

  /// Whether the reply supplied a complete, correctly shaped findings list.
  final bool findingsReported;

  /// The last findings returned by the machine.
  final List<ReadingFinding> findings;

  /// Findings in reported order within blocking and remaining severities.
  List<ReadingFinding> get blockingFirst => [
    ...findings.where((each) => each.severity == 'BLOCKING'),
    ...findings.where((each) => each.severity != 'BLOCKING'),
  ];
}

/// Story work methods of the planning stand-in protocol.
extension StoryWorkClient on PoreloClient {
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
  Future<void> stopStoryWork(String project, String story) async {
    await _call('StopStoryWork', {'project': project, 'story': story});
  }

  /// Reads the issue’s last findings from GetIssue.
  Future<PlanningIssueDetail> getPlanningIssue(String project, String issue) async =>
      PlanningIssueDetail.from(await _call('GetIssue', {'project': project, 'issue': issue}));

  /// Sends a revision-bound decision for one stopped reading round.
  Future<String> resolveIssueReading(
    String project,
    String issue,
    int round,
    String choice,
    String revision, {
    String? comment,
  }) async => _planText(
    await _call('ResolveIssueReading', {
      'project': project,
      'issue': issue,
      'round': round,
      'choice': choice,
      'revision': revision,
      'comment': ?comment,
    }),
    'revision',
  );
}
