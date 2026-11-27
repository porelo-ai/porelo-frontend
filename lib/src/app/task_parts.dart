import 'package:porelo_frontend/client.dart';

import 'start_refusals.dart' show rightLabel, shownName;

/// What stands where the machine did not say a part of a task's start: never *none*, the default set or own work.
const notSaid = 'not said';

/// The longest pull request address a machine takes, so one it lists is shown whole.
const _longestAddress = 2048;

/// The workspace [task] was started with, for a person: the kind the machine recorded, the place of another task's
/// work, and the tasks whose landed work it reads beside it. A kind this build does not know is said by its name.
String workspaceWords(Task task) {
  final kind = switch (task.workspace) {
    null => notSaid,
    'own' => 'its own work',
    'foreign' => switch (_placeWords(task.place)) {
      '' => "another task's work, frozen and read only",
      final place => "another task's work, frozen and read only: $place",
    },
    'readOnly' => 'one repository, read only, with no gate',
    'allRepositories' => 'every repository, read only, with no gate',
    'none' => 'none: an empty directory, with no gate',
    final other => switch (shownName(other)) {
      '' => notSaid,
      final name => name,
    },
  };
  return switch (task.readLanded) {
    null => '$kind\nlanded work it reads: $notSaid',
    [] => kind,
    final tasks => '$kind\nreads the landed work of ${tasks.map(_named).join(', ')}',
  };
}

/// The equipment [task] was started with, for a person: whether it holds the project's services, and at a pull
/// request the account it writes as. Away from a pull request an account chooses nothing and is not said.
String equipmentWords(Task task) {
  final services = switch (task.projectServices) {
    null => "the project's services: $notSaid",
    true => "the project's services",
    false => "none of the project's services",
  };
  if (!(task.place?.atAPullRequest ?? false)) return services;
  final account = switch (task.writeAs) {
    null => 'the account it writes as: $notSaid',
    'author' => 'writes as the account that opened the pull request',
    'review' => "writes as the forge's review account",
    final other => 'writes as ${_named(other)}',
  };
  return '$services\n$account';
}

/// The rights [task] holds, one line each in plain words, a right this build does not know by its name: `none` for a
/// task holding no right, which is not one whose machine did not say. A name with nothing to show is said as that,
/// never left out and never read as a right the task holds.
String rightsWords(Task task) => switch (task.rights) {
  null => notSaid,
  [] => 'none',
  final rights => rights.map((right) => shownName(right).isEmpty ? _unnamedRight : rightLabel(right)).join('\n'),
};

const _unnamedRight = 'a right the machine did not name';

/// Where a run works, for a person; empty where [place] names nothing. Every part is the machine's text, shown
/// without controls so none adds a line of its own.
String _placeWords(RunPlace? place) => switch (place) {
  RunPlace(gatePush: (repository: final repository?, :final name)) =>
    'the push ${_named(name)} in ${_named(repository)} at the gate',
  RunPlace(gatePush: (repository: null, :final name)) => 'the push ${_named(name)} at the gate',
  RunPlace(pullRequest: final address?) => 'the pull request ${shownName(address, most: _longestAddress)}',
  RunPlace(ownPullRequest: true) => 'its own pull request',
  _ => '',
};

/// A name the machine sent, or that it sent none that can be shown.
String _named(String name) => switch (shownName(name)) {
  '' => 'one the machine did not name',
  final shown => shown,
};
