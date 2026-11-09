part of 'porelo_client.dart';

String _planText(Map<String, dynamic> map, String key) => map[key] is String ? map[key] as String : '';
List<String> _planStrings(Object? value) => value is List ? value.whereType<String>().toList() : const [];
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
      gain = _planText(map, 'gain'),
      test = _planText(map, 'test'),
      issues = _planList(map['issues'], PlanIssue.from),
      issuesReported = map['issues'] is List,
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

/// The stand-in planning protocol, isolated here until served by the daemon.
extension PlanningClient on PoreloClient {
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
