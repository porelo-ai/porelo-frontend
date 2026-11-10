import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';

import 'connections.dart' show quoteForAShell;
import 'fleet_backend.dart';
import 'machines.dart';

/// One open pull request on a host's forge, as a row of *Needs you* shows it.
@immutable
class PullRequestRow {
  /// Constructor taking what the row is about.
  const PullRequestRow({required this.machine, required this.project, required this.request, required this.stale});

  /// The host whose forge it is on, whose daemon read it.
  final Machine machine;

  /// The project it belongs to, as the machine lists it.
  final Project project;

  /// The pull request, as the machine last said it.
  final HostPullRequest request;

  /// Whether what it says may be out of date: its watch ended without an answer since, and is being asked again.
  final bool stale;

  /// The one thing it asks of the person, in words.
  String get action => 'Pull request ${request.number} of ${request.repository} waits for your approval and merge';

  /// Where it is on the host's forge, through this computer's forward to it; null where that is not known.
  Uri? get address => pullRequestAddress(forge: machine.hostCard?.forgeUrl, project: project, request: request);
}

/// A host forge's pull requests the machine would not read, as a row of *Needs you* says it.
@immutable
class PullRequestsRefusedRow {
  /// Constructor taking what the row is about.
  const PullRequestsRefusedRow({required this.machine, required this.project, required this.refusal});

  /// The host whose forge it is.
  final Machine machine;

  /// The project whose pull requests were asked for.
  final String project;

  /// What the machine answered.
  final Object refusal;

  /// What it means, in words; never the machine's own token for it.
  String get words {
    final which = "The pull requests of $project on ${machine.name}'s forge cannot be read";
    return switch (refusal) {
      MissingHostForgeToken(:final credential) =>
        '$which: no forge token of yours is stored on ${machine.name}'
            '${credential.isEmpty ? '' : ' under $credential'}. Store it there with the command below, in a terminal '
            'on ${machine.name}; until then no pull request waiting for you there is shown.',
      HostPullRequestsRefused(:final reason, :final message) =>
        '$which: ${_why(reason)}${message.isEmpty ? '' : ' The machine says: $message.'}',
      _ => '$which: the machine stopped answering about them. They are asked for again.',
    };
  }

  static String _why(String reason) => switch (reason) {
    'settings' => "the host's forge settings are not in order.",
    'vault-unreadable' => 'the vault there is locked or cannot be read.',
    'not-carried' => 'the host does not carry this project for you.',
    'forge' => 'its forge did not answer.',
    'forge-answer' => "its forge's answer could not be read.",
    'makers' => 'the makers of a pull request could not be read from its copy there.',
    'bounds' => 'there are more pull requests or repositories than it reads at once.',
    _ => 'the machine refused.',
  };

  /// The command that stores the missing token, to be run on the machine by the person; null where none is named.
  String? get storeCommand => switch (refusal) {
    MissingHostForgeToken(:final storeCommand) when storeCommand.isNotEmpty =>
      storeCommand.map(quoteForAShell).join(' '),
    _ => null,
  };
}

/// A name on a host's forge, as its copy of a repository is named there: never `..`, an option or a path.
final _segment = RegExp(r'^[A-Za-z0-9_][A-Za-z0-9._-]*$');

/// Where [request] is on the host's forge: its forge forward [forge], the path of its repository there and its
/// number; null where any of them is not known. The window never asks a forge itself; it only opens this.
///
/// The host's forge keeps its copy of a repository under the project's name and the last part of the repository's
/// address, which is the same for its central address and for the address it is reached at on the host.
Uri? pullRequestAddress({required String? forge, required Project project, required HostPullRequest request}) {
  if (forge == null || request.number <= 0) return null;
  final base = Uri.tryParse(forge);
  if (base == null || !(base.isScheme('http') || base.isScheme('https')) || base.host.isEmpty) return null;
  final repository = project.repositoryStates.where((each) => each.name == request.repository).firstOrNull;
  if (repository == null) return null;
  final address = repository.upstream.trim().replaceFirst(RegExp(r'/+$'), '').replaceFirst(RegExp(r'\.git$'), '');
  final cut = address.lastIndexOf('/') > address.lastIndexOf(':') ? address.lastIndexOf('/') : address.lastIndexOf(':');
  final name = address.substring(cut + 1);
  if (!_segment.hasMatch(project.name) || !_segment.hasMatch(name)) return null;
  return base.replace(pathSegments: <String>[project.name, name, 'pulls', '${request.number}']);
}

/// What one project's watch has said.
class _Watched {
  StreamSubscription<PullRequestsSeen>? listening;
  Timer? again;

  /// Open pull requests by [HostPullRequest.key].
  final open = <String, HostPullRequest>{};

  /// Those the machine left out of a list without saying they ended: kept, as not confirmed.
  final unconfirmed = <String>{};

  /// Whether the watch has answered since it was last asked.
  bool answered = false;

  /// Whether what it said may be out of date.
  bool stale = false;

  /// What the machine refused with, or null.
  Object? refusal;

  void stop() {
    unawaited(listening?.cancel());
    listening = null;
    again?.cancel();
    again = null;
  }
}

/// The pull requests open on a machine's host forge, per project it carries, as its watches say them.
///
/// **Only the watch's own word ends a row**: one the machine confirms merged or closed. A watch that ends with an
/// error never closes anything; what it said stays, marked stale, and it is asked again.
class HostPullRequests extends ChangeNotifier {
  /// How long after a watch ended it is asked again. Injectable, so a test need not wait.
  static Duration askAgainAfter = const Duration(seconds: 30);

  /// Whether this machine can say at all; false for one older than the watch.
  bool supported = true;

  final _projects = <String, _Watched>{};
  FleetBackend? _backend;
  bool _anew = false;
  bool _disposed = false;

  /// Every open pull request, per project, in the order the machine listed them.
  List<({String project, HostPullRequest request, bool stale})> get open =>
      <({String project, HostPullRequest request, bool stale})>[
        for (final MapEntry(key: project, value: watched) in _projects.entries)
          for (final request in watched.open.values)
            (project: project, request: request, stale: watched.stale || watched.unconfirmed.contains(request.key)),
      ];

  /// Every project whose pull requests the machine refused to read, with its answer.
  List<({String project, Object refusal})> get refused => <({String project, Object refusal})>[
    for (final MapEntry(key: project, value: watched) in _projects.entries)
      if (watched.refusal case final refusal?) (project: project, refusal: refusal),
  ];

  /// Watches [projects] on [backend]: those already watched go on, those no longer named stop. After
  /// [reconnected] every watch starts again, keeping what it last said as stale until it answers.
  void follow(FleetBackend backend, Iterable<String> projects) {
    if (_disposed) return;
    final wanted = projects.toSet();
    final anew = _anew || !identical(backend, _backend);
    _anew = false;
    _backend = backend;
    if (anew) supported = true;
    var changed = anew;
    for (final gone in _projects.keys.where((project) => !wanted.contains(project)).toList()) {
      _projects.remove(gone)!.stop();
      changed = true;
    }
    for (final project in wanted) {
      final watched = _projects[project];
      if (watched == null) {
        _start(project, _projects[project] = _Watched());
        changed = true;
      } else if (anew) {
        watched
          ..stop()
          ..stale = watched.stale || watched.open.isNotEmpty;
        _start(project, watched);
      }
    }
    if (changed) _notify();
  }

  /// What every watch last said is kept, as stale: contact with the machine was lost.
  void lostContact() {
    for (final watched in _projects.values) {
      watched
        ..stop()
        ..stale = true;
    }
    _notify();
  }

  /// The machine answers again: the next [follow] starts every watch anew.
  void reconnected() => _anew = true;

  void _start(String project, _Watched watched) {
    final backend = _backend;
    if (backend == null || _disposed) return;
    watched.answered = false;
    watched.listening = backend
        .watchPullRequests(project)
        .listen(
          (seen) => _take(watched, seen),
          onError: (Object error) => _ended(project, watched, error),
          onDone: () => _ended(project, watched, null),
          cancelOnError: true,
        );
  }

  void _take(_Watched watched, PullRequestsSeen seen) {
    final ended = {for (final each in seen.ended) each.key};
    final now = {for (final each in seen.open) each.key: each};
    // The first answer of a watch is the whole list as it stands; later ones are changes, where only an end the
    // machine confirms takes a row away.
    final kept = watched.answered
        ? <String, HostPullRequest>{
            for (final MapEntry(:key, :value) in watched.open.entries)
              if (!now.containsKey(key) && !ended.contains(key)) key: value,
          }
        : const <String, HostPullRequest>{};
    watched
      ..answered = true
      ..open.clear()
      ..open.addAll(now)
      ..open.addAll(kept)
      ..unconfirmed.clear()
      ..unconfirmed.addAll(kept.keys)
      ..stale = false
      ..refusal = null;
    _notify();
  }

  void _ended(String project, _Watched watched, Object? error) {
    if (_disposed || !identical(_projects[project], watched)) return;
    watched.listening = null;
    if (error is FeatureNotSupported) {
      // An older machine: it says nothing about pull requests, which is not that none are open.
      supported = false;
      _notify();
      return;
    }
    watched.stale = true;
    if (error is MissingHostForgeToken || error is HostPullRequestsRefused) watched.refusal = error;
    // A lost machine comes back through its own connection, which starts every watch anew.
    if (error is! VarlinkDisconnected) {
      watched.again?.cancel();
      watched.again = Timer(askAgainAfter, () {
        watched.again = null;
        if (!_disposed && identical(_projects[project], watched)) _start(project, watched);
      });
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final watched in _projects.values) {
      watched.stop();
    }
    super.dispose();
  }
}
