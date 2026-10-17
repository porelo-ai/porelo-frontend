import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';

import 'fleet_backend.dart';

/// What one project's work may reach, read and shown. Changed only in project.yml in the project's
/// repository (walk 10), never from here.
class Egress extends ChangeNotifier {
  /// Which project this is about.
  Project? project;

  /// Which of its repositories, or null for the project itself — what every repository gets.
  ///
  /// **A repository's grants are added to the project's, never in place of them**, so with one
  /// chosen the list is the project's and the repository's together, each host naming its origin,
  /// and what it adds is in its own block of project.yml.
  String? repository;

  /// Every host its work may reach, in the order the sources granted them. **Never sorted:** the
  /// first grant wins, so the order is what says which source a host came from.
  List<EgressHost> reachable = const <EgressHost>[];

  /// What an agent asks for and is deliberately not given.
  ///
  /// The distinction a dropped packet cannot make: "we said no" and "nobody added it" look
  /// identical to the firewall, and only one of them is somebody's decision.
  List<String> refused = const <String>[];

  /// The sets installed on this machine, and the directories searched, most specific first.
  List<EgressSet> sets = const <EgressSet>[];

  /// Where the sets were found, in search order.
  List<String> locations = const <String>[];

  /// Whether something is being asked for right now.
  bool busy = false;

  /// Why it could not be read, in words.
  String? problem;

  /// Whether [host] is one the chosen repository adds, rather than one every repository gets.
  bool addedByTheRepository(EgressHost host) =>
      repository != null && host.origin == 'repository $repository';

  /// Whether this project can be asked about at all.
  bool get reachableAtAll => project?.canBeActedOn ?? false;

  /// Reads what a project may reach, and what sets are installed.
  Future<void> lookAt(FleetBackend backend, Project project, {String? repository}) async {
    this.project = project;
    this.repository = repository;
    if (!project.canBeActedOn) {
      reachable = const <EgressHost>[];
      refused = const <String>[];
      problem = '${project.name} is not a project this machine follows, so nothing can be asked '
          'about its egress. Following its repository makes it one.';
      notifyListeners();
      return;
    }
    await _asking(() async {
      final (hosts, notGiven) = await backend.egressOf(project.name, repository: repository);
      final (installed, where) = await backend.egressSets();
      reachable = hosts;
      refused = notGiven;
      sets = installed;
      locations = where;
    });
  }

  Future<void> _asking(Future<void> Function() ask) async {
    busy = true;
    problem = null;
    notifyListeners();
    try {
      await ask();
    } on VarlinkException catch (refusal) {
      problem = refusal.simpleName == 'ProjectRequired'
          ? 'No project file was given, and every call about egress takes one.'
          : 'Refused: ${refusal.simpleName}.';
    } on VarlinkDisconnected catch (ex) {
      problem = 'Lost contact with the machine: ${ex.message}';
    } on FeatureNotSupported catch (ex) {
      problem = '$ex';
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
