import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';

import 'fleet_backend.dart';

/// Whom one task may talk to, how each is moderated, and what a person writes to one of them.
///
/// **Derived from the task's project, never kept here**: the project says who may be addressed
/// and the mailbox says whether anything goes there, so both are asked of the machine each time.
class TaskPeers extends ChangeNotifier {
  /// Constructor taking the machine and the task.
  TaskPeers(this._backend, this.task);

  final FleetBackend _backend;

  /// The task whose peers these are.
  final Task task;

  /// Its peers, or null before the machine answered.
  List<TalkPeer>? peers;

  /// Why the last thing asked of the machine did not happen, or null.
  String? problem;

  /// What the last message a person wrote became, in words, or null.
  String? said;

  /// Whether something is being asked of the machine right now.
  bool busy = false;

  /// Asks the machine whom the task may talk to.
  Future<void> load() => _asking(() async {
        if (task.project.isEmpty) {
          problem = 'Nothing recorded which project ${task.name} belongs to, and its project is '
              'what says whom it may talk to.';
          peers = const <TalkPeer>[];
          return;
        }
        peers = await _backend.peers(task.name, task.project);
      });

  /// Holds everything for [peer], or lets it go again.
  Future<void> setHeld(TalkPeer peer, bool held) =>
      _asking(() => _moderated(peer, _backend.moderate(task.name, task.project, peer.name, held: held)));

  Future<void> _moderated(TalkPeer peer, Future<TalkPeer> asked) async {
    final now = await asked;
    final list = peers ?? const <TalkPeer>[];
    peers = <TalkPeer>[
      for (final each in list)
        each.name == peer.name
            ? TalkPeer(
                name: each.name,
                address: each.address,
                trust: each.trust,
                perDay: each.perDay,
                mode: now.mode.isEmpty ? each.mode : now.mode,
                held: now.held,
                sentToday: each.sentToday,
                receivedToday: each.receivedToday,
              )
            : each,
    ];
  }

  Future<void> _asking(Future<void> Function() action) async {
    busy = true;
    problem = null;
    notifyListeners();
    try {
      await action();
    } on FeatureNotSupported {
      problem = 'This machine cannot say whom work may talk to.';
    } on VarlinkException catch (refusal) {
      problem = switch (refusal.simpleName) {
        // The daemon's own sentence, which names what refused it.
        'Failed' => '${refusal.parameters['message'] ?? 'The machine refused it.'}',
        'NoSuchProject' => 'This machine does not follow ${task.project}, so it cannot say whom '
            '${task.name} may talk to.',
        'NoSuchTask' => '${task.name} is not a task on this machine any more.',
        _ => 'The machine refused it: ${refusal.simpleName}.',
      };
    } on VarlinkDisconnected catch (ex) {
      problem = 'Lost contact with the machine: ${ex.message}';
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
