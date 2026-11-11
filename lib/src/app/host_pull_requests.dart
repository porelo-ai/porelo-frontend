import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';

import 'connections.dart' show quoteForAShell;
import 'fleet_backend.dart';
import 'machines.dart';
import 'organization_source.dart' show HostConnections;

/// One open pull request on a host's forge, as a row of *Needs you* shows it.
@immutable
class PullRequestRow {
  /// Constructor taking what the row is about.
  const PullRequestRow({
    required this.machine,
    required this.project,
    required this.request,
    required this.stale,
    this.ended,
  });

  /// How the machine said it ended, `merged` or `closed`, once it has; null while it is open.
  final String? ended;

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
            '${credential.isEmpty ? '' : ' under $credential'}. '
            '${storeCommand == null ? "Store it there with Porelo's own command for it, in a terminal on ${machine.name}; the machine named none that can be shown here" : 'Store it there with the command below, in a terminal on ${machine.name}'}'
            '; until then no pull request waiting for you there is shown.',
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

  /// What the person does about it, and where: the row's action lies on the machine, not in this window.
  String get action {
    final on = machine.name;
    return switch (refusal) {
      MissingHostForgeToken() => 'Store your forge token on $on; Open details shows how.',
      HostPullRequestsRefused(reason: 'vault-unreadable') => 'Unlock the vault on $on.',
      HostPullRequestsRefused(reason: 'settings') => "Put the forge settings of $on in order there.",
      HostPullRequestsRefused(reason: 'not-carried') => 'Ask an admin of $on to carry $project for you.',
      _ => 'If this stays, look at the forge of $on; the window asks again by itself.',
    };
  }

  /// The command that stores the missing token, to be run on the machine by the person; null where none is named.
  String? get storeCommand => switch (refusal) {
    MissingHostForgeToken(:final storeCommand) when storeCommand.isNotEmpty =>
      storeCommand.map(quoteForAShell).join(' '),
    _ => null,
  };
}

/// Why [row] cannot be opened now, or null where it can: [connections] where the window holds them.
String? whyPullRequestCannotOpen(PullRequestRow row, HostConnections? connections) {
  final host = row.machine.hostCard?.name;
  return switch (host) {
    null => 'this computer reaches no forge of ${row.machine.name}',
    _ when row.machine.hostCard?.forgeUrl == null => 'this computer reaches no forge of ${row.machine.name}',
    _ when row.address == null => 'the machine does not say where its forge keeps ${row.request.repository}',
    final host when connections != null && !connections.up(host) =>
      "Connect first: $host's forge is reached through the connection",
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
  final name = _repositoryName(repository.upstream);
  if (name == null) return null;
  if (!_segment.hasMatch(project.name) || !_segment.hasMatch(name)) return null;
  return base.replace(pathSegments: <String>[project.name, name, 'pulls', '${request.number}']);
}

/// The last part of a repository's [upstream] address, without `.git`: of a URL's path, or of an scp-like
/// `host:path`; null where it names no repository, as a bare host or a bare word.
String? _repositoryName(String upstream) {
  final address = upstream.trim();
  final String path;
  if (address.contains('://')) {
    final url = Uri.tryParse(address);
    if (url == null || url.host.isEmpty) return null;
    path = url.path;
  } else {
    final colon = address.indexOf(':');
    if (colon <= 0 || address.substring(0, colon).contains('/')) return null;
    path = address.substring(colon + 1);
  }
  final segments = path.split('/').where((each) => each.isNotEmpty).toList();
  if (segments.isEmpty) return null;
  final name = segments.last.replaceFirst(RegExp(r'\.git$'), '');
  return name.isEmpty ? null : name;
}

/// What one project's watch has said.
class _Watched {
  _Watched(this.project);

  /// The project, as the machine last listed it.
  Project project;

  /// Whether the machine still carries it: one it no longer does keeps what it said, stale, and is not asked.
  bool wanted = true;

  StreamSubscription<PullRequestsSeen>? listening;
  Timer? again;

  /// Open pull requests by [HostPullRequest.key].
  final open = <String, HostPullRequest>{};

  /// Those the machine left out of a list without saying they ended: kept, as not confirmed.
  final unconfirmed = <String>{};

  /// How those the machine confirmed ended did, by [HostPullRequest.key].
  final ended = <String, String>{};

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
  List<({Project project, HostPullRequest request, bool stale})> get open =>
      <({Project project, HostPullRequest request, bool stale})>[
        for (final watched in _projects.values)
          for (final request in watched.open.values)
            (
              project: watched.project,
              request: request,
              stale: watched.stale || watched.unconfirmed.contains(request.key),
            ),
      ];

  /// How the pull request [key] of [project] ended, as the machine confirmed it; null where it has not.
  String? endedAs(String project, String key) => _projects[project]?.ended[key];

  /// Every project whose pull requests the machine refused to read, with its answer.
  List<({String project, Object refusal})> get refused => <({String project, Object refusal})>[
    for (final MapEntry(key: project, value: watched) in _projects.entries)
      if (watched.refusal case final refusal?) (project: project, refusal: refusal),
  ];

  /// Watches [projects] on [backend]: those already watched go on. One no longer named stops being asked but keeps
  /// what it said, stale: a project not carried for a while is not its pull requests merged. After [reconnected]
  /// every watch starts again, keeping what it last said as stale until it answers.
  void follow(FleetBackend backend, Iterable<Project> projects) {
    if (_disposed) return;
    final wanted = {for (final project in projects) project.name: project};
    final anew = _anew || !identical(backend, _backend);
    _anew = false;
    _backend = backend;
    if (anew) supported = true;
    var changed = anew;
    for (final MapEntry(key: name, value: watched) in _projects.entries.toList()) {
      if (wanted.containsKey(name) || !watched.wanted) continue;
      watched
        ..stop()
        ..wanted = false
        ..stale = true
        ..refusal = null;
      if (watched.open.isEmpty) _projects.remove(name);
      changed = true;
    }
    for (final MapEntry(key: name, value: project) in wanted.entries) {
      final watched = _projects[name];
      if (watched == null) {
        _start(name, _projects[name] = _Watched(project));
        changed = true;
        continue;
      }
      watched.project = project;
      if (anew || !watched.wanted) {
        watched
          ..stop()
          ..wanted = true
          ..stale = watched.stale || watched.open.isNotEmpty;
        _start(name, watched);
        changed = true;
      }
    }
    if (changed) _notify();
  }

  /// Asks again at once every watch that is waiting to be asked: after a refusal, or one that ended.
  void askAgain() {
    if (_disposed || !supported || _backend == null) return;
    for (final MapEntry(key: name, value: watched) in _projects.entries) {
      if (!watched.wanted || watched.listening != null) continue;
      watched.again?.cancel();
      watched.again = null;
      _start(name, watched);
    }
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
    watched.ended
      ..removeWhere((key, _) => seen.open.any((each) => each.key == key))
      ..addAll({for (final each in seen.ended) each.key: each.state});
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
    // A watch that ends, with a refusal, without a word, or with its own connection lost, is said and asked again;
    // a machine lost as a whole is said by [lostContact], which stops this.
    watched
      ..stale = true
      ..refusal = error ?? StateError('the watch ended without a word');
    watched.again?.cancel();
    watched.again = Timer(askAgainAfter, () {
      watched.again = null;
      if (!_disposed && identical(_projects[project], watched) && watched.wanted) _start(project, watched);
    });
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
