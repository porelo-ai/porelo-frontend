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
      work = map['work'] is Map<String, dynamic> ? PlanWork.from(map['work'] as Map<String, dynamic>) : null;

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

  /// Its work, when reported.
  final PlanWork? work;

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
