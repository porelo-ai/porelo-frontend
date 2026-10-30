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

/// Core's noninteractive vault boundary, pending its served delivery contract.
abstract interface class CentralCredentialSource {
  /// Uses the current person's token once without storing it in app state.
  ///
  /// A locked vault or missing token throws [CentralCredentialUnavailable] before
  /// [use] is called. Implementations must not include credentials in exceptions.
  Future<T> withCredential<T>(TransferSelection selection, Future<T> Function(String token) use);
}

/// A public refusal from Core, containing no credential or process diagnostics.
class CentralCredentialUnavailable implements Exception {
  /// Identifies a locked vault or absent credential without a secret input form.
  const CentralCredentialUnavailable();
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
  /// Accepts Core's credential delivery and a pinned transport seam for tests.
  ProjectTransfers({
    required this.credentials,
    Remote Function(Machine)? remoteFor,
    this.answerWithin = const Duration(minutes: 6),
  }) : _remoteFor = remoteFor ?? _sharedHost;

  /// The noninteractive credential boundary; never the platform token store.
  final CentralCredentialSource credentials;

  /// The bound on credential delivery and the one submitted command together.
  final Duration answerWithin;
  final Remote Function(Machine) _remoteFor;
  final Set<String> _busy = {};
  final Set<String> _uncertain = {};
  final Set<String> _submitted = {};
  final Map<String, int> _generations = {};

  static Remote _sharedHost(Machine machine) => OpenSsh.sharedHost(card: machine.hostCard!, config: machine.sshConfig);

  String _key(TransferSelection selection) => '${selection.machine.host}/${selection.project}';

  /// Explains why an action cannot start, without consulting a selected UI role.
  String? unavailable(TransferSelection selection) {
    if (!selection.canPush) return 'Your verified admission does not allow this transfer.';
    if (selection.machine.hostCard == null || selection.machine.hostCard!.login != selection.person) {
      return 'Join this host as the current person before transferring.';
    }
    if (selection.machine.whyNotReachableHere case final reason?) return reason;
    if (_busy.contains(_key(selection)) || _submitted.contains(_key(selection))) {
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
      if (_busy.contains(key) || _submitted.contains(key) || generation != _generations[key]) {
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
    final command = projectTransferCommand(direction, selection.project, selection.repositories);
    final key = _key(selection);
    _busy.add(key);
    _generations[key] = (_generations[key] ?? 0) + 1;
    notifyListeners();
    TransferAnswer answer;
    var active = true;
    var submitted = false;
    try {
      answer = await credentials
          .withCredential(selection, (token) async {
            if (!active || submitted) throw const CentralCredentialUnavailable();
            if (token.isEmpty || token.contains(RegExp(r'[\x00-\x20\x7f]'))) {
              throw const CentralCredentialUnavailable();
            }
            final lines = <String>[];
            try {
              final remote = _remoteFor(selection.machine);
              submitted = true;
              _submitted.add(key);
              final result = await remote.run(
                selection.machine.host,
                '',
                command,
                input: '$token\n',
                onLine: (line) {
                  final words = line.replaceAll(token, '[redacted]');
                  lines.add(words);
                  if (active) onProgress?.call(words);
                },
              );
              final state = result.exitCode == 255 || result.exitCode < 0
                  ? TransferState.unconfirmed
                  : result.exitCode == 0
                  ? TransferState.completed
                  : TransferState.refused;
              return TransferAnswer(
                state,
                [
                  ...lines,
                  if (result.stderr.isNotEmpty) result.stderr,
                  if (state == TransferState.unconfirmed)
                    'The host result is unconfirmed. Read its state before trying again.',
                ].join('\n').replaceAll(token, '[redacted]'),
              );
            } on Exception {
              return const TransferAnswer(
                TransferState.unconfirmed,
                'The host result is unconfirmed. Read its state before trying again.',
              );
            } finally {
              _submitted.remove(key);
              notifyListeners();
            }
          })
          .timeout(answerWithin);
    } on TimeoutException {
      answer = TransferAnswer(
        submitted ? TransferState.unconfirmed : TransferState.unavailable,
        submitted
            ? 'The host result is unconfirmed. Read its state before trying again.'
            : 'Core credential delivery timed out.',
      );
    } on CentralCredentialUnavailable {
      answer = submitted
          ? const TransferAnswer(
              TransferState.unconfirmed,
              'The host result is unconfirmed. Read its state before trying again.',
            )
          : const TransferAnswer(
              TransferState.unavailable,
              'Unlock your vault and make your central forge token available through Core.',
            );
    } on Exception {
      answer = submitted
          ? const TransferAnswer(
              TransferState.unconfirmed,
              'The host result is unconfirmed. Read its state before trying again.',
            )
          : const TransferAnswer(TransferState.unavailable, 'Core could not deliver your central forge credential.');
    } finally {
      active = false;
    }
    try {
      if (answer.state == TransferState.unconfirmed) _uncertain.add(key);
      if (answer.state == TransferState.completed) {
        try {
          await refresh();
        } on Exception {
          return TransferAnswer(
            answer.state,
            '${answer.words}\nThe transfer completed, but observed state could not be refreshed.',
          );
        }
      }
      return answer;
    } finally {
      _busy.remove(key);
      notifyListeners();
    }
  }
}
