import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';

import 'fleet_backend.dart';
import 'host_forge_refresh.dart';

/// What has been backed up of a project's mirror, and the removing of one.
///
/// **The listing exists because nothing recorded that a backup had been taken.** A bundle is
/// written wherever an operator names it and the command forgets it the moment it returns, so
/// *"what has been taken"* was never a missing listing — it was a question the machine had no data
/// to answer. That bounds what this screen may promise: **backups taken by hand, or before the
/// record existed, are invisible and always will be.** An empty list means *nothing recorded*,
/// never *nothing exists*.
class Backups extends ChangeNotifier {
  /// Which project these belong to.
  String project = '';

  /// Which of its repositories, or null for the project's own — all a machine that names none has.
  /// **Backups are kept per repository**, so this is part of what a bundle is, not a filter.
  String? repository;

  /// What has been taken, newest first.
  List<Backup> taken = const <Backup>[];

  /// What removing one would take, once it has been asked and before it is agreed to.
  BackupDeleted? considering;

  /// Which bundle is being considered.
  String? bundle;

  /// What the last deletion did.
  BackupDeleted? removed;

  /// What a restore would do, or did.
  Restored? restoring;

  /// Which bundle is being restored from.
  String? restoringFrom;

  /// Whether the machine is being asked right now.
  bool busy = false;

  /// Why it could not be read, in words.
  String? problem;

  /// Whether anything has been read yet.
  bool get asked => problem != null || taken.isNotEmpty || _read;
  bool _read = false;

  /// Reads what has been taken.
  Future<void> look(FleetBackend backend, String name, {String? repository}) async {
    project = name;
    this.repository = repository;
    busy = true;
    problem = null;
    considering = null;
    removed = null;
    notifyListeners();
    try {
      taken = await backend.backups(name, repository: repository);
      _read = true;
    } on VarlinkException catch (refusal) {
      problem = 'Refused: ${refusal.simpleName}.';
    } on VarlinkDisconnected catch (ex) {
      problem = 'Lost contact with the machine: ${ex.message}';
    } on FeatureNotSupported catch (ex) {
      problem = '$ex';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Asks the upstream about one project by name, without the listing being open.
  Future<String> syncFor(
    FleetBackend backend,
    String name, {
    String? repository,
    required bool joinedHost,
    HostForgeRefresh? hostForge,
  }) async {
    return _sync(backend, name, repository, joinedHost: joinedHost, hostForge: hostForge);
  }

  /// Asks the upstream how far behind this project is, now.
  ///
  /// **Its own call and not a refresh of the listing**: a listing that reached the network would
  /// make every redraw cost what a listing must not. It writes the same record the daemon's timer
  /// writes, so a triggered fetch and a timed one cannot disagree.
  Future<String> sync(FleetBackend backend, {required bool joinedHost, HostForgeRefresh? hostForge}) =>
      _sync(backend, project, repository, joinedHost: joinedHost, hostForge: hostForge);

  Future<String> _sync(
    FleetBackend backend,
    String name,
    String? selectedRepository, {
    required bool joinedHost,
    HostForgeRefresh? hostForge,
  }) async {
    try {
      if (joinedHost && hostForge == null) throw const FeatureNotSupported('Host forge refresh');
      final answer = joinedHost
          ? await hostForge!.sync(name, repository: selectedRepository)
          : await backend.syncUpstream(name, repository: selectedRepository);
      return wordsFor(answer);
    } on VarlinkException catch (refusal) {
      return 'Refused: ${refusal.simpleName}.';
    } on VarlinkDisconnected catch (ex) {
      return 'Lost contact with the machine: ${ex.message}';
    } on FeatureNotSupported catch (ex) {
      return '$ex';
    }
  }

  /// Asks what restoring from one would take, restoring nothing.
  Future<void> considerRestoring(FleetBackend backend, Backup backup) async {
    restoringFrom = backup.bundle;
    removed = null;
    considering = null;
    await _asking(() async {
      restoring = await backend.restoreBackup(project, backup.bundle, dryRun: true, repository: repository);
    });
  }

  /// Restores from the one being considered. With [force], despite unreviewed work.
  Future<void> restore(FleetBackend backend, {bool force = false}) async {
    final path = restoringFrom;
    if (path == null) return;
    await _asking(() async {
      restoring = await backend.restoreBackup(project, path, force: force ? true : null, repository: repository);
      if (restoring?.done ?? false) taken = await backend.backups(project, repository: repository);
    });
  }

  /// What a restore did or would do, in one line.
  String get restoreWords {
    final said = restoring;
    if (said == null) return '';
    return switch (said.outcome) {
      'PREVIEWED' when said.unreviewed.isEmpty =>
        'This writes over the mirror from that bundle. Nothing is waiting for review, so nothing '
            'that exists only there would be lost.',
      // **The one thing worth refusing over.** Unreviewed pushes are in the mirror and nowhere
      // else — not upstream, not in a workspace, not in the bundle.
      'PREVIEWED' =>
        'This writes over the mirror, and ${said.unreviewed.length} '
            '${said.unreviewed.length == 1 ? 'push' : 'pushes'} nobody has reviewed exist only '
            'there. Restoring destroys the only copy there has ever been.',
      'HOLDS_WORK' =>
        'Refused: ${said.unreviewed.length} '
            '${said.unreviewed.length == 1 ? 'push' : 'pushes'} nobody has reviewed would be '
            'destroyed. Nothing was written.',
      'RESTORED' when said.unreviewed.isEmpty => 'The mirror is restored from that bundle.',
      // Said after the fact as well as before it: somebody who forced needs it in the record,
      // not only in the warning they clicked past.
      'RESTORED' =>
        'The mirror is restored, and ${said.unreviewed.length} unreviewed '
            '${said.unreviewed.length == 1 ? 'push is' : 'pushes are'} gone: '
            '${said.unreviewed.join(', ')}.',
      'NO_SUCH_BACKUP' => 'No record names that bundle, so nothing here will restore from it.',
      'FAILED' => 'It could not be restored. ${said.detail}'.trim(),
      _ => '${said.outcome}. ${said.detail}'.trim(),
    };
  }

  /// Asks what removing one would take, removing nothing.
  Future<void> consider(FleetBackend backend, Backup backup) async {
    bundle = backup.bundle;
    removed = null;
    await _asking(() async {
      considering = await backend.deleteBackup(project, backup.bundle, dryRun: true);
    });
  }

  /// Removes the one being considered.
  Future<void> remove(FleetBackend backend) async {
    final path = bundle;
    if (path == null) return;
    await _asking(() async {
      removed = await backend.deleteBackup(project, path);
      considering = null;
      if (removed?.gone ?? false) taken = await backend.backups(project, repository: repository);
    });
  }

  /// Puts what is on screen away.
  void letItBe() {
    bundle = null;
    considering = null;
    removed = null;
    restoring = null;
    restoringFrom = null;
    notifyListeners();
  }

  /// What a sync answered, in one line.
  ///
  /// **`behind` means nothing unless it was measured**, and zero is the answer both for a project
  /// that is up to date and for one nothing could be measured about.
  static String wordsFor(Synced said) {
    if (said.outcome == 'NO_MIRROR') {
      return 'Nothing has used the gate here yet, so there is nothing to measure against.';
    }
    if (said.outcome != 'MEASURED') {
      return 'The upstream could not be asked. ${said.detail}'.trim();
    }
    if (!said.measured) {
      return switch (said.reason) {
        'NO_UPSTREAM' => 'This project has no upstream, so there is nothing to be behind.',
        'OFFLINE' => 'An offline project reaches nothing, so nothing was tried.',
        'NEVER_CHECKED' => 'Nothing has looked yet.',
        _ => 'How far behind it is could not be established. ${said.detail}'.trim(),
      };
    }
    return said.behind == 0
        ? 'Up to date with the upstream, as of now.'
        : '${said.behind} ${said.behind == 1 ? 'commit' : 'commits'} behind the upstream, as of '
              'now.';
  }

  /// What to say about the last deletion, in one line.
  ///
  /// **A record cleared for a bundle somebody had already moved is a tidy-up, not a loss**, and
  /// saying both the same way would tell somebody they had destroyed something they had not.
  String get words {
    final said = removed;
    if (said == null) return '';
    return switch (said.outcome) {
      'DELETED' when said.fileRemoved =>
        'Gone: the bundle and the record of it. It held ${said.refs} '
            '${said.refs == 1 ? 'push' : 'pushes'}.',
      'DELETED' =>
        'The record is cleared. The file was already gone — somebody had moved it, and '
            'nothing here removed anything.',
      'NO_SUCH_BACKUP' => 'No record names that file, so nothing here will remove it. ${said.detail}'.trim(),
      'FAILED' => 'It could not be removed. ${said.detail}'.trim(),
      _ => '${said.outcome}. ${said.detail}'.trim(),
    };
  }

  Future<void> _asking(Future<void> Function() ask) async {
    busy = true;
    problem = null;
    notifyListeners();
    try {
      await ask();
    } on VarlinkException catch (refusal) {
      problem = 'Refused: ${refusal.simpleName}.';
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
