/// Start orders and the roles of their tasks, as a planner serves them to the window's tests.
library;

/// A role as a project's work rules define it: its [name], how its task ends and the parts of a start.
Map<String, dynamic> plannedRole(
  String name,
  String endKind,
  String workspace,
  List<String> rights, {
  bool readLanded = false,
  bool projectServices = true,
  String writeAs = 'author',
}) => <String, dynamic>{
  'name': name,
  'endKind': endKind,
  'workspace': workspace,
  'readLanded': readLanded,
  'projectServices': projectServices,
  'writeAs': writeAs,
  'rights': rights,
};

/// A role that builds on its own work and pushes it.
final authorRole = plannedRole('author', 'PUSHES_WORK', 'own', ['push', 'reply']);

/// A second role that builds, named as a project might name a helper.
final builderRole = plannedRole('builder', 'PUSHES_WORK', 'own', ['push', 'reply']);

/// A role of a planned stage: one repository read only, a result file handed back.
final stageRole = plannedRole('analyst', 'HANDS_BACK_RESULT', 'readOnly', ['report']);

/// A role that reads another task's work at its place and gives points there.
final reviewerRole = plannedRole(
  'reviewer',
  'GIVES_POINTS',
  'foreign',
  ['reply', 'openThreads'],
  projectServices: false,
  writeAs: 'review',
);

/// A role that reads the landed work of other tasks and reports what it found.
final readerRole = plannedRole('reader', 'REPORTS_FINDINGS', 'readOnly', ['report'], readLanded: true);

/// A work order of [role], its parts written out as Start is handed them, with [members] beside or over them.
Map<String, dynamic> workOrder(Map<String, dynamic> role, Map<String, dynamic> members) => <String, dynamic>{
  'kind': 'work',
  'role': role,
  'rights': role['rights'],
  'readLanded': <String>[],
  'projectServices': role['projectServices'],
  // As the planner does: a task at another task's work is started under a name of its own.
  if (role['workspace'] == 'foreign') 'ownTask': true,
  // As the planner does: a task at another task's work names that work's place, here one a test may replace.
  if (role['workspace'] == 'foreign')
    'place': <String, dynamic>{
      'gatePush': <String, dynamic>{'name': 'the-work'},
    },
  if (role['workspace'] == 'readOnly' || role['workspace'] == 'allRepositories') 'readOnly': true,
  if (role['workspace'] == 'allRepositories') 'allRepositories': true,
  if (role['workspace'] == 'none') 'noGate': true,
  ...members,
};

/// A discussion's order: no role, every repository read only, its idea reported back, with [members] beside them.
Map<String, dynamic> discussionOrderOf(Map<String, dynamic> members) => <String, dynamic>{
  'kind': 'discussion',
  'rights': <String>['report'],
  'readLanded': <String>[],
  'projectServices': true,
  'readOnly': true,
  'allRepositories': true,
  ...members,
};
