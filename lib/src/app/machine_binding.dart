import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';
import 'package:yaml/yaml.dart';

import 'fleet_backend.dart';
import 'forge.dart';
import 'project_workspace.dart';
import 'quiet_after_dispose.dart';

/// What a project's configuration says of itself, as far as its waiting changes need it.
class ProjectShape {
  /// Its name, which every machine knows it by.
  final String name;

  /// Its work repositories: each name to its central forge's address.
  final Map<String, String> repositories;

  /// Constructor taking both.
  const ProjectShape({required this.name, required this.repositories});

  /// Reads it from [text], a `project.yml`. Refused, in words, where it has no name.
  factory ProjectShape.of(String text) {
    final Object? read;
    try {
      read = loadYaml(text);
    } on YamlException catch (ex) {
      throw WorkspaceRefused('project.yml cannot be read: ${ex.message}');
    }
    final project = read is YamlMap ? read['project'] : null;
    final name = project is YamlMap ? project['name'] : null;
    if (name is! String || name.isEmpty) throw const WorkspaceRefused('project.yml names no project.');
    if (name.toLowerCase() == defaultProject) {
      throw const WorkspaceRefused(
        'project.yml names Default, the project every machine has: it needs a name of its own.',
      );
    }
    final repositories = read is YamlMap ? read['repositories'] : null;
    return ProjectShape(
      name: name,
      repositories: <String, String>{
        if (repositories is YamlMap)
          for (final entry in repositories.entries)
            // `central:` names it; `upstream:` in a file written before the rename.
            if (entry.value case final YamlMap each when (each['central'] ?? each['upstream']) is String)
              '${entry.key}': (each['central'] ?? each['upstream']) as String,
      },
    );
  }
}

/// `owner/name` on github.com for an upstream git reaches it by, or null for anything else.
String? onGitHub(String upstream) {
  final match = RegExp(r'^(?:git@github\.com:|ssh://git@github\.com/|https://github\.com/)([^/]+/[^/]+?)(?:\.git)?/?$')
      .firstMatch(upstream.trim());
  return match?.group(1);
}

/// A project's configuration changes waiting at one machine's gate, merged from the project's clone here.
class MachineBinding extends ChangeNotifier with QuietAfterDispose {
  /// Constructor taking the forge, the project's clone here, and the machine.
  MachineBinding(this.forge, this.workspace, this._machine, {required this.machineName, required this.login});

  /// The forge the project's repositories are on, reached with the token in use.
  Forge forge;

  /// The project's own repository, cloned on this computer.
  ProjectWorkspace workspace;

  final FleetBackend _machine;

  /// The machine, as the person calls it.
  final String machineName;

  /// The forge login a signed commit is pushed with.
  final String login;

  /// What was done, in order, in words.
  final List<String> done = <String>[];

  /// Why the last step did not happen, or null.
  String? problem;

  /// Whether a step is running.
  bool busy = false;

  /// Configuration changes waiting at the machine's gate for the project's own repository, or null
  /// before they were asked for. A person merges them here, signed, and the machine is told they landed.
  List<PendingPush>? changes;

  /// The change being looked at, and what it would change against the default branch.
  String? reviewing;

  /// What [reviewing] would change against the default branch, as a diff.
  String reviewDiff = '';

  /// Asks the machine what waits at its gate for the project's own repository.
  Future<void> loadChanges() => _doing(() async {
    final shape = ProjectShape.of(await workspace.read() ?? '');
    final project = (await _machine.projects()).where((each) => each.name == shape.name).firstOrNull;
    if (project == null) {
      changes = const <PendingPush>[];
      _say('$machineName does not have ${shape.name}, so nothing waits there for it.');
      return;
    }
    // Asked by the project's name, as every gate call takes it.
    changes = (await _machine.gateOf(project.name)).pending;
  });

  /// Takes [change] from the gate into the clone here, to be read before it is merged.
  Future<void> review(PendingPush change) => _doing(() async {
    final shape = ProjectShape.of(await workspace.read() ?? '');
    final handed = await _machine.pendingBundle(shape.name, change.name, branch: workspace.repository.defaultBranch);
    reviewDiff = await workspace.takeBundle(handed.bundle, change.name);
    reviewing = change.name;
  });

  /// Merges [change], once reviewed, signed with [person], pushes it, and tells the machine it landed.
  Future<void> merge(PendingPush change, SigningKey person) async {
    if (reviewing != change.name) return;
    await _doing(() async {
      final shape = ProjectShape.of(await workspace.read() ?? '');
      final branch = workspace.repository.defaultBranch;
      await workspace.mergeAndPush(change.name, 'Take “${change.subject}” from $machineName', person, login: login);
      final told = await _machine.landed(shape.name, change.name, branch: branch);
      _say(
        told.landed
            ? 'Merged “${change.subject}” signed, pushed to $branch, and cleared at $machineName’s gate.'
            : 'Merged “${change.subject}” signed and pushed; $machineName says: ${told.detail}',
      );
      reviewing = null;
      reviewDiff = '';
      changes = <PendingPush>[
        for (final each in changes ?? const <PendingPush>[])
          if (each.name != change.name || !told.landed) each,
      ];
    });
  }

  void _say(String words) {
    done.add(words);
    notifyListeners();
  }

  Future<void> _doing(Future<void> Function() action) async {
    busy = true;
    problem = null;
    notifyListeners();
    try {
      await action();
    } on FormatException catch (error) {
      problem = error.message;
    } on ForgeRefused catch (refused) {
      problem = refused.words;
    } on WorkspaceRefused catch (refused) {
      problem = refused.words;
    } on FeatureNotSupported {
      problem = '$machineName cannot do this from here: its Porelo is older than that.';
    } on VarlinkException catch (refusal) {
      problem = refusal.simpleName == 'BundleTooLarge'
          ? 'It is too large to review here (${refusal.parameters['bytes']} bytes, at most '
                '${refusal.parameters['limit']}); take it at $machineName’s own terminal.'
          : '$machineName refused it: ${refusal.parameters['message'] ?? refusal.simpleName}.';
    } on VarlinkDisconnected catch (ex) {
      problem = 'Lost contact with $machineName: ${ex.message}';
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
