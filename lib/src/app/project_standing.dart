import 'package:flutter/foundation.dart';

import 'organization_source.dart';

/// How this person stands in each project as `project list` last answered: the right to move a project's work.
class ProjectStandings extends ChangeNotifier {
  /// Reads through [source], absent where this computer reads no organization.
  ProjectStandings(this.source);

  /// Where the person's projects are read.
  final OrganizationSource? source;

  List<ListedProject>? _listed;
  String? _problem;
  int _reads = 0;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Reads again; a read that fails forgets the last answer, since a role that cannot be read gives no right.
  Future<void> read() async {
    final organization = source;
    if (organization == null) return;
    final read = ++_reads;
    List<ListedProject>? listed;
    String? problem;
    try {
      listed = await organization.myProjects();
    } on OrganizationRefused catch (refused) {
      problem = refused.words;
    } on Exception {
      problem = 'The projects could not be read.';
    }
    // A read answering after a later one was asked for may be the older.
    if (read != _reads || _disposed) return;
    _listed = listed;
    _problem = problem;
    notifyListeners();
  }

  /// Why the person may not move [project]'s work now, or null where they hold a role in it and are not locked.
  String? whyNoRight(String project) {
    if (source == null) return 'Your role in $project cannot be read: this computer reads no organization.';
    if (_problem case final problem?) return 'Your role in $project cannot be read: $problem';
    final listed = _listed;
    if (listed == null) return 'Your role in $project is still being read.';
    final mine = listed.where((each) => each.name == project).firstOrNull;
    // No check rests on a state the store could not vouch for: a lock since then would not show.
    if (mine?.stale ?? false) {
      return 'Porelo cannot reach the organization just now, so your role in $project is unsure.';
    }
    if (mine == null || mine.role == null || mine.role!.isEmpty) return 'You have no role in $project.';
    if (mine.locked) return 'You are locked in $project: one of its admins can let you back in.';
    return null;
  }
}
