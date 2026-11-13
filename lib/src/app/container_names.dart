/// The names porelod gives a task's container, read without guessing the project.
///
/// porelod names a new task of project `porelo` `porelo_<task>`, and every other project's
/// `porelo-<project or its short spelling>_<task>`. A task made before keeps its name: `porelo-<task>` in project
/// `porelo`, and `porelo-<project>-<task>` from a porelo older still.
library;

/// The container name porelod gives a new task [task] of [project] that sets no short spelling.
String newContainerName(String project, String task) =>
    project == 'porelo' ? 'porelo_$task' : 'porelo-${project}_$task';

/// [container] without the prefix porelod gave it: `porelo_` or `porelo-<project>_`, since neither a project's name nor
/// a task's holds `_`; else, in a name from before, which does not say where its project ends, only `porelo-`. A name of
/// none of these shapes, or whose prefix has nothing after it, is kept whole.
String withoutContainerPrefix(String container) {
  final shaped = _newShape.firstMatch(container) ?? _before.firstMatch(container);
  return shaped == null ? container : shaped.group(1)!;
}

final RegExp _newShape = RegExp(r'^porelo(?:_|-[a-z0-9][a-z0-9-]*_)([^_]+)$');
final RegExp _before = RegExp(r'^porelo-([^_]+)$');
