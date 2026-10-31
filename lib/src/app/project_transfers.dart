import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:porelo_host/porelo_host.dart';

import 'machines.dart';
import 'quiet_after_dispose.dart';

/// A captured selection from Core's verified admission, independent of UI roles.
class TransferSelection {
  /// Captures public values before any asynchronous credential read.
  TransferSelection({
    required this.machine,
    required this.person,
    required this.forge,
    required this.project,
    required this.canPush,
    List<String> repositories = const [],
  }) : repositories = List.unmodifiable(repositories);

  /// The joined host and its pinned shared SSH configuration.
  final Machine machine;

  /// The current person's verified login.
  final String person;

  /// The central forge selected for this project.
  final String forge;

  /// The project's name on the host.
  final String project;

  /// The repositories selected at the start; empty means the whole project.
  final List<String> repositories;

  /// Whether verified admission permits this person to transfer the project.
  final bool canPush;
}

/// A terminal executor that keeps the local secrets-file token outside Dart.
abstract interface class CentralTransferSource {
  /// Runs the captured action and reports the shell's SSH submission marker.
  ///
  /// Public output has already been redacted in the terminal shell.
  Future<TransferResult> run(
    TransferSelection selection,
    ProjectTransfer direction, {
    required void Function() onSubmitted,
    void Function(String line)? onLine,
  });
}

/// A terminal result with an explicit local refusal when no host command ran.
class TransferResult extends RemoteResult {
  /// Keeps the host exit and words, or a confirmed pre-submission refusal.
  const TransferResult(
    super.exitCode,
    super.stderr, {
    this.notSubmitted = false,
    this.uncertain = false,
    this.childEnded,
  });

  /// Whether the local terminal confirmed that it sent nothing to the host.
  final bool notSubmitted;

  /// Whether shutdown or lost output leaves the transfer unconfirmed.
  final bool uncertain;

  /// The child exit still required before reconciling an uncertain shutdown.
  ///
  /// A negative code or failed future cannot confirm death and keeps replay blocked.
  final Future<int>? childEnded;
}

/// Whether a host confirmed a transfer, refused it, or lost its answer.
enum TransferState {
  /// The host confirmed completion.
  completed,

  /// The host returned a refusal.
  refused,

  /// Submission may have completed without an answer.
  unconfirmed,

  /// Admission or credentials prevented submission.
  unavailable,
}

/// A public answer safe to show beside the captured project.
class TransferAnswer {
  /// Keeps only public host output and its confirmation state.
  const TransferAnswer(this.state, this.words);

  /// The confirmed or uncertain outcome.
  final TransferState state;

  /// The host's words, with echoed credential values removed.
  final String words;
}

/// Explicit central transfers, with no timer, reconnect hook, or automatic retry.
class ProjectTransfers extends ChangeNotifier with QuietAfterDispose {
  /// Accepts a terminal executor, with no token-bearing callback in the interface.
  ProjectTransfers({required this.source});

  /// The terminal-only transfer boundary.
  final CentralTransferSource source;

  final Set<String> _busy = {};
  final Set<String> _uncertain = {};
  final Set<String> _pending = {};
  final Map<String, int> _generations = {};

  String _key(TransferSelection selection) => '${selection.machine.host}/${selection.project}';

  /// Explains why an action cannot start, without consulting a selected UI role.
  String? unavailable(TransferSelection selection) {
    if (selection.forge.trim().isEmpty) return 'Choose a central forge.';
    try {
      projectTransferCommand(ProjectTransfer.push, selection.project, selection.repositories);
    } on FormatException catch (refusal) {
      return refusal.message;
    }
    if (!selection.canPush) return 'Your verified admission does not allow this transfer.';
    if (selection.machine.hostCard == null || selection.machine.hostCard!.login != selection.person) {
      return 'Join this host as the current person before transferring.';
    }
    if (selection.machine.whyNotReachableHere case final reason?) return reason;
    if (_busy.contains(_key(selection)) || _pending.contains(_key(selection))) {
      return 'A transfer is still running for this project.';
    }
    if (_uncertain.contains(_key(selection))) {
      return 'Read the host and central state before retrying an unconfirmed transfer.';
    }
    return null;
  }

  /// Clears uncertainty only after the caller explicitly reads both observed states.
  Future<void> reconcile(TransferSelection selection, Future<void> Function() readObservedState) async {
    final key = _key(selection);
    final generation = _generations[key];
    void requireSettled() {
      if (_busy.contains(key) || _pending.contains(key) || generation != _generations[key]) {
        throw StateError('The host operation must settle before its result can be reconciled.');
      }
    }

    requireSettled();
    await readObservedState();
    requireSettled();
    _uncertain.remove(key);
    notifyListeners();
  }

  /// Runs the captured action once and refreshes observed state on confirmed completion.
  Future<TransferAnswer> start(
    TransferSelection selection,
    ProjectTransfer direction, {
    required Future<void> Function() refresh,
    void Function(String words)? onProgress,
  }) async {
    if (unavailable(selection) case final reason?) return TransferAnswer(TransferState.unavailable, reason);
    final key = _key(selection);
    var active = true;
    var submitted = false;
    final lines = <String>[];
    _busy.add(key);
    _pending.add(key);
    _generations[key] = (_generations[key] ?? 0) + 1;
    try {
      notifyListeners();
      TransferAnswer answer;
      try {
        final result =
            await Future<TransferResult>.sync(
              () => source.run(
                selection,
                direction,
                onSubmitted: () {
                  if (submitted) throw const RemoteNotStarted();
                  submitted = true;
                  if (!active) _uncertain.add(key);
                  notifyListeners();
                },
                onLine: (line) {
                  lines.add(line);
                  if (active) onProgress?.call(line);
                },
              ),
            ).whenComplete(() {
              _pending.remove(key);
              if (!submitted) _uncertain.remove(key);
              notifyListeners();
            });
        if (result.childEnded case final ended?) {
          _pending.add(key);
          unawaited(
            ended.then<void>(
              (code) {
                if (code < 0) return;
                _pending.remove(key);
                notifyListeners();
              },
              onError: (Object _) {
                // Failed confirmation cannot release the replay guard.
              },
            ),
          );
        }
        final state = result.uncertain
            ? TransferState.unconfirmed
            : !submitted || result.notSubmitted
            ? TransferState.unavailable
            : result.exitCode >= 128 || result.exitCode < 0
            ? TransferState.unconfirmed
            : result.exitCode == 0
            ? TransferState.completed
            : TransferState.refused;
        answer = TransferAnswer(
          state,
          [
            ...lines,
            if (result.stderr.isNotEmpty) result.stderr,
            if (state == TransferState.unconfirmed) _unconfirmed,
          ].join('\n'),
        );
      } catch (_) {
        answer = TransferAnswer(
          submitted || _pending.contains(key) ? TransferState.unconfirmed : TransferState.unavailable,
          submitted || _pending.contains(key)
              ? _unconfirmed
              : 'The local terminal could not prepare the central transfer.',
        );
      } finally {
        active = false;
      }
      if (answer.state == TransferState.unconfirmed) _uncertain.add(key);
      if (answer.state == TransferState.completed) {
        try {
          await refresh();
        } catch (_) {
          return TransferAnswer(
            answer.state,
            '${answer.words}\nThe transfer completed, but observed state could not be refreshed.',
          );
        }
      }
      return answer;
    } finally {
      active = false;
      _busy.remove(key);
      notifyListeners();
    }
  }

  static const _unconfirmed = 'The host result is unconfirmed. Read its state before trying again.';
}
