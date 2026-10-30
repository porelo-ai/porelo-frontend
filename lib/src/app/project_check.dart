import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';

import 'backups.dart';
import 'fleet_backend.dart';
import 'host_forge_refresh.dart';

/// Checking a followed project now, rather than at the machine's next round: its repository fetched
/// again, and each of its repositories' upstream asked how far ahead it is.
///
/// A project whose vault was just opened, or whose repository was just pushed to, otherwise goes on
/// saying what it said until the machine's next round, with nothing a person could press meanwhile.
class ProjectCheck extends ChangeNotifier {
  String? _checking;
  String? _about;
  List<String> _said = const <String>[];

  /// Whether [project] is being checked now.
  bool isChecking(String project) => _checking == project;

  /// What the last check of [project] found, a line each; empty when it was not checked.
  List<String> saidAbout(String project) => _about == project ? _said : const <String>[];

  /// Fetches [project] now and asks each of [repositories]' upstream, or the project's own when it
  /// names none, then says what came back. One check at a time.
  Future<void> checkNow(
    FleetBackend backend,
    String project,
    List<String> repositories, {
    required bool joinedHost,
    HostForgeRefresh? hostForge,
  }) async {
    if (_checking != null) return;
    _checking = project;
    _about = project;
    _said = const <String>[];
    notifyListeners();
    final said = <String>[];
    try {
      if (joinedHost && hostForge == null) throw const FeatureNotSupported('Host forge refresh');
      final records = joinedHost ? await hostForge!.refresh(project) : await backend.refreshProjects(project: project);
      final followed = records.where((each) => each.name == project).firstOrNull;
      said.add(followed?.words ?? 'The machine fetched nothing for $project.');
      for (final repository in repositories.isEmpty ? const <String?>[null] : repositories) {
        try {
          final answer = joinedHost
              ? await hostForge!.sync(project, repository: repository)
              : await backend.syncUpstream(project, repository: repository);
          said.add('${repository ?? project}: ${Backups.wordsFor(answer)}');
        } on VarlinkException catch (refusal) {
          said.add('${repository ?? project}: refused: ${refusal.simpleName}.');
        }
      }
    } on VarlinkException catch (refusal) {
      said.add(
        refusal.simpleName == 'NoSuchProject'
            ? '$project is no longer followed here.'
            : 'Refused: ${refusal.simpleName}.',
      );
    } on VarlinkDisconnected catch (lost) {
      said.add('Lost contact with the machine: ${lost.message}');
    } on FeatureNotSupported catch (older) {
      said.add('$older');
    } finally {
      _checking = null;
      _said = said;
      notifyListeners();
    }
  }
}
