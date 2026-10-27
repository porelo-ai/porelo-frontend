/// Porelo's rule for a task name, shared by every start that names one.
///
/// Accepted after `Foo Bar` was sent, the image built, and only `podman create` refused it.
/// Lowercase letters, digits and inner hyphens: podman names the container `porelo-<project>-<task>`,
/// git names the ref after the task, and a case-insensitive filesystem makes `Foo` and `foo` one ref.
/// Not only digits, which a login container's name is. And the container name at most
/// [longestContainerName] characters, because the task's longest socket path must fit. Start stays
/// the authority; this only stops a name it will refuse from being sent.
library;

/// The longest a task's container name may be, prefix included.
const int longestContainerName = 65;

final RegExp _taskName = RegExp(r'^[a-z0-9]([a-z0-9-]*[a-z0-9])?$');
final RegExp _onlyDigits = RegExp(r'^[0-9]+$');

/// Why [name] cannot be a task's in [project], or null when it can or none was typed.
///
/// [taken] are the names new work may not take: a start under a name the project has means *that*
/// work again.
String? taskNameProblem(String name, {String? project, Set<String> taken = const <String>{}}) {
  if (name.isEmpty) return null;
  if (name.contains(' ')) return 'A name cannot hold a space. Use lowercase letters, digits and "-".';
  if (name != name.toLowerCase()) return 'A name is lowercase: letters, digits and "-".';
  if (!_taskName.hasMatch(name)) {
    return 'A name holds only lowercase letters, digits and "-", and starts and ends with a letter '
        'or a digit.';
  }
  if (_onlyDigits.hasMatch(name)) return 'A name cannot be only digits.';
  if (taken.contains(name)) {
    return 'The name "$name" is taken: work of this project on this machine has it already. Choose '
        'another, or open that work from its tile.';
  }
  if (project != null) {
    final container = 'porelo-$project-$name';
    if (container.length > longestContainerName) {
      return 'That name is too long for this project: "$container" is ${container.length} '
          'characters, and at most $longestContainerName fit.';
    }
  }
  return null;
}

/// A name a task can have, made from [from] (a repository's or a project's name) and numbered on
/// where [taken] has it already.
String suggestedTaskName(String from, Set<String> taken) {
  var base = from.toLowerCase().replaceAll(RegExp('[^a-z0-9-]+'), '-').replaceAll(RegExp('-+'), '-');
  base = base.replaceAll(RegExp(r'^-+|-+$'), '');
  if (base.isEmpty || _onlyDigits.hasMatch(base)) base = 'work${base.isEmpty ? '' : '-$base'}';
  var candidate = base;
  for (var number = 2; taken.contains(candidate); number++) {
    candidate = '$base-$number';
  }
  return candidate;
}
