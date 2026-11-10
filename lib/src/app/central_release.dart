import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';

import 'commands.dart';
import 'fleet_backend.dart';
import 'host_progress.dart';

/// One repository whose host `main` is ahead of central: its name, and by how many commits where that was said.
typedef AheadOfCentral = ({String repository, int? commits});

/// The repositories of a project whose host `main` is ahead of central, in the order [listed] names them: as the
/// machine's daemon lists them, or, of one it says nothing of at central, as the host itself said in [progress] of one
/// it has taken. Never one the machine does not carry, the host's placement [carriedAlone] leaves out, or the host has
/// not taken; nor one [atCentral] names, as this window saw it reach central, on the host's older word alone. Empty
/// where none is, or nothing was said.
List<AheadOfCentral> aheadOfCentral({
  required List<Repository> listed,
  HostProjectProgress? progress,
  List<String>? carriedAlone,
  Set<String> atCentral = const {},
}) {
  HostRepositoryCentral? hostSays(String repository) => progress?.repositories
      .where((each) => each.repository == repository && each.state == 'taken')
      .firstOrNull
      ?.central;
  final names = <String>[
    for (final each in listed) each.name,
    for (final each in progress?.repositories ?? const <HostRepositoryProgress>[])
      if (!listed.any((listed) => listed.name == each.repository)) each.repository,
  ];
  AheadOfCentral? ahead(String name) {
    final repository = listed.where((each) => each.name == name).firstOrNull;
    // A repository the machine does not carry has no copy there to bring.
    if (repository?.carriedHere == false) return null;
    final row = progress?.repositories.where((each) => each.repository == name).firstOrNull;
    final placed = carriedAlone == null || carriedAlone.contains(name);
    // Where the daemon does not say it carries it, the host's placement and its own word on it decide.
    if (repository?.carriedHere != true && (!placed || (row != null && row.state != 'taken'))) return null;
    final host = hostSays(name);
    final daemon = repository?.central;
    // The daemon's own word first, where it says one; the two may disagree, one older than the other, and up to date
    // never hides what the host says is ahead, as the repository's row says it, but for what this window just saw
    // reach central, of which the host's word is older.
    if (daemon == 'ahead') {
      final commits = repository!.ahead;
      return (repository: name, commits: commits != null && commits > 0 ? commits : null);
    }
    if (daemon != null && daemon != 'up-to-date') return null;
    if (atCentral.contains(name)) return null;
    return host?.state == 'ahead' ? (repository: name, commits: host!.commits) : null;
  }

  return [for (final name in names) ?ahead(name)];
}

/// Whether anything said of [listed] or [progress] stands against central at all: whether the machine is a host
/// of the project, where *Bring it to central…* has a place.
bool saysOfCentral({required List<Repository> listed, HostProjectProgress? progress}) =>
    listed.any((each) => each.carriedHere != false && each.central != null) ||
    (progress?.repositories.any((each) => each.state == 'taken' && each.central != null) ?? false);

/// The commits [ahead] brings, in words: "3 commits of payments-api and 1 commit of billing".
String commitsToBring(List<AheadOfCentral> ahead) {
  final each = [
    for (final (:repository, :commits) in ahead)
      switch (commits) {
        null => 'commits of $repository, how many not reported',
        1 => '1 commit of $repository',
        final n => '$n commits of $repository',
      },
  ];
  return switch (each.length) {
    0 => 'nothing',
    1 => each.single,
    _ => '${each.sublist(0, each.length - 1).join(', ')} and ${each.last}',
  };
}

/// *Bring it to central…* on a project's page on its host: brings the host's finished `main` of the repositories
/// [ahead] names to the central forge, after the person agreed. [hidden] where the machine is no host of the project;
/// [unavailable] why it cannot run now, before any reason of its own.
Command bringToCentralCommand({
  required List<AheadOfCentral> ahead,
  required VoidCallback run,
  bool hidden = false,
  bool running = false,
  String? unavailable,
}) => Command(
  id: 'project.bringToCentral',
  label: 'Bring it to central…',
  group: 'Project',
  home: Home.projectMenu,
  hidden: hidden,
  unavailable:
      unavailable ??
      (running
          ? 'It is being brought to central now; wait for the answer.'
          : ahead.isEmpty
          ? 'Nothing waits to reach central: the host says no repository of it is ahead there.'
          : null),
  run: run,
);

/// *Store the central token…*, offered once the machine said it holds no central token: runs the store command
/// the machine named, in a terminal on it, where the token is typed and never passes through this program.
Command storeCentralTokenCommand({required String credential, required VoidCallback run, String? unavailable}) =>
    Command(
      id: 'project.storeCentralToken',
      label: credential.isEmpty
          ? 'Store the central token in a terminal…'
          : 'Store the central token $credential in a terminal…',
      group: 'Project',
      home: Home.projectMenu,
      unavailable: unavailable,
      run: run,
    );

/// What the last bringing of one project to central said: its words for the page, whether it was refused, whether it
/// runs still, and the machine's refusal where it named one.
typedef CentralReleaseSaid = ({String words, bool refused, bool running, CentralPushRefusal? refusal});

/// The bringing of host `main`s to central from this window, one at most per machine and project at a time, from the
/// question on, and what each said last, which the project's page shows until the next one.
class CentralReleases extends ChangeNotifier {
  final _said = <String, CentralReleaseSaid>{};
  final _atCentral = <String, Set<String>>{};
  final _asking = <String>{};
  final _running = <String, ({StreamSubscription<CentralPushProgress> push, Completer<void> done})>{};
  bool _disposed = false;

  static String _key(String machine, String project) => '$machine/$project';

  /// What the last one for [project] on [machine] said, or null where none ran since this window started.
  CentralReleaseSaid? said(String machine, String project) => _said[_key(machine, project)];

  /// The repositories of [project] on [machine] whose last answer here said they are at central, pushed or already;
  /// the host's older word does not offer them again.
  Set<String> atCentral(String machine, String project) => _atCentral[_key(machine, project)] ?? const {};

  /// Whether one for [project] on [machine] is asked about or runs now.
  bool running(String machine, String project) =>
      _asking.contains(_key(machine, project)) || _running.containsKey(_key(machine, project));

  /// Asks [agree], where given, then brings [repositories] of [project] to central through [backend], the daemon of
  /// [machine], and completes once the machine answered, the person said no, or it was cancelled. Nothing starts while
  /// one for the same project on the same machine is asked about or runs, nor for no repository at all: an empty list
  /// is every one the push configuration names. [host] fills a `<host>` the machine leaves in a command. Nothing is
  /// said to have reached central but what the machine's answer names.
  Future<void> bring(
    FleetBackend backend, {
    required String machine,
    required String project,
    required List<String> repositories,
    String? host,
    Future<bool> Function()? agree,
  }) async {
    final key = _key(machine, project);
    if (repositories.isEmpty || running(machine, project) || _disposed) return;
    _asking.add(key);
    notifyListeners();
    try {
      if (agree != null && !await agree()) return;
    } finally {
      _asking.remove(key);
      if (!_disposed) notifyListeners();
    }
    if (_disposed) return;
    final done = Completer<void>();
    void say(String words, {bool refused = false, bool running = false, CentralPushRefusal? refusal}) {
      if (_disposed) return;
      _said[key] = (words: words, refused: refused, running: running, refusal: refusal);
      notifyListeners();
    }

    void reached(List<String> pushed, List<String> upToDate) => _atCentral[key] = {...pushed, ...upToDate};

    void end() {
      _running.remove(key);
      if (!_disposed) notifyListeners();
      if (!done.isCompleted) done.complete();
    }

    var answered = false;
    say('Bringing ${repositories.join(', ')} to central…', running: true);
    final push = backend
        .pushToCentral(project, repositories: repositories)
        .listen(
          (reply) {
            if (reply.isFinal) {
              answered = true;
              final (pushed, upToDate) = (reply.pushed ?? const <String>[], reply.upToDate ?? const <String>[]);
              reached(pushed, upToDate);
              say(
                broughtWords(pushed: pushed, upToDate: upToDate),
                refused: pushed.isEmpty && upToDate.isEmpty,
              );
            } else if (reply.repository != null && reply.stage != null) {
              say('Bringing to central: ${reply.repository} ${_stageWords(reply.stage!)}', running: true);
            }
          },
          onError: (Object error) {
            answered = true;
            if (error is CentralPushRefusal) reached(error.pushed, error.upToDate);
            switch (error) {
              case CentralPushRefusal(kind: 'NothingToPush'):
                say(
                  broughtWords(pushed: error.pushed, upToDate: error.upToDate),
                  refused: error.pushed.isEmpty && error.upToDate.isEmpty,
                );
              case final CentralPushRefusal refusal:
                say(centralRefusalWords(refusal, host: host), refused: true, refusal: refusal);
              case FeatureNotSupported():
                say('This machine’s Porelo cannot bring work to central from here yet.', refused: true);
              case VarlinkDisconnected():
                say(
                  'The connection was lost while it was being brought to central: it may have reached central. '
                  'Look at central before trying again.',
                  refused: true,
                );
              case final VarlinkException refusal:
                say('The machine refused it: ${refusal.simpleName}.', refused: true);
              default:
                say('It could not be brought to central: $error', refused: true);
            }
            end();
          },
          onDone: () {
            if (!answered) {
              say(
                'The machine ended without saying what reached central. Look at central before trying again.',
                refused: true,
              );
            }
            end();
          },
          cancelOnError: true,
        );
    _running[key] = (push: push, done: done);
    return done.future;
  }

  /// Cancels the push of every machine but those named in [keep], as the machines this window still watches, and
  /// forgets what each said: nobody is left to say its answer to.
  void forget({required Set<String> keep}) {
    bool gone(String key) => !keep.contains(key.substring(0, key.lastIndexOf('/')));
    final cancelled = _running.keys.where(gone).toList();
    cancelled.forEach(_cancel);
    final before = _said.length + _atCentral.length;
    _said.removeWhere((key, _) => gone(key));
    _atCentral.removeWhere((key, _) => gone(key));
    if (!_disposed && (cancelled.isNotEmpty || _said.length + _atCentral.length != before)) notifyListeners();
  }

  void _cancel(String key) {
    final running = _running.remove(key);
    if (running == null) return;
    unawaited(running.push.cancel());
    if (!running.done.isCompleted) running.done.complete();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final key in _running.keys.toList()) {
      _cancel(key);
    }
    super.dispose();
  }
}

String _stageWords(String stage) => switch (stage) {
  'reading' => 'is being read',
  'pushing' => 'is being pushed',
  'pushed' => 'was pushed',
  'up-to-date' => 'was at central already',
  final stage => stage,
};

/// What reached central, in words: [pushed] newly, [upToDate] already there.
String broughtWords({required List<String> pushed, required List<String> upToDate}) => [
  if (pushed.isNotEmpty) 'Brought to central: ${pushed.join(', ')}.',
  if (upToDate.isNotEmpty)
    '${pushed.isEmpty ? 'Nothing to bring: central' : 'Central'} had ${upToDate.join(', ')} already.',
  if (pushed.isEmpty && upToDate.isEmpty) 'The machine named nothing it brought to central.',
].join(' ');

/// Why [refusal] brought nothing more to central, in words from what the machine named; [host] fills a `<host>` it
/// leaves in a command.
String centralRefusalWords(CentralPushRefusal refusal, {String? host}) {
  String named(String what, String fallback) => what.isEmpty ? fallback : what;
  final repository = named(refusal.repository, 'a repository');
  final before = [
    if (refusal.pushed.isNotEmpty) 'Brought to central before it stopped: ${refusal.pushed.join(', ')}.',
    if (refusal.upToDate.isNotEmpty) 'At central already: ${refusal.upToDate.join(', ')}.',
  ].join(' ');
  final filled = [
    for (final word in refusal.unlockCommand) word == '<host>' && host != null && host.isNotEmpty ? host : word,
  ];
  // A placeholder nothing here can fill is no command to run.
  final command = filled.contains('<host>') ? '' : filled.join(' ');
  final words = switch (refusal.kind) {
    'CentralVaultShut' => switch (refusal.unlock) {
      'init' => 'Nothing was pushed: the machine has no vault yet${command.isEmpty ? '' : '; make it with $command'}.',
      'device' => 'Nothing was pushed: the vault is shut; open it on the device enrolled for it, then try again.',
      _ => 'Nothing was pushed: the vault is shut${command.isEmpty ? '' : '; open it with $command'}, then try again.',
    },
    'MissingCentralToken' =>
      'Nothing was pushed: the machine holds no central token under ${named(refusal.credential, 'its entry')}. '
          'Store it there, then try again.',
    'CentralTokenRefused' =>
      'The central forge${refusal.forge.isEmpty ? '' : ' ${refusal.forge}'} refused the token '
          '${named(refusal.credential, 'stored for it')}${refusal.status == null ? '' : ' (HTTP ${refusal.status})'} '
          'at $repository: nothing more was pushed.',
    'HostPushTokenUnavailable' => switch (refusal.reason) {
      'busy' => 'Nothing was pushed: another push or token of this account runs on the host now; try again after it.',
      'issuer' =>
        'Nothing was pushed: the host could not issue its own forge token for the push. '
            'Its administrator checks the sudo rule of its token issuer.',
      final reason =>
        'Nothing was pushed: the host could not issue its own forge token (${named(reason, 'no reason given')}).',
    },
    'CentralPushRefused' => switch (refusal.reason) {
      'reconcile' =>
        'Central refused $repository: its main has commits the host lacks, now on '
            '${named(refusal.branch, 'central/main')} on the host. Merge and approve that in a task, then bring it again.',
      'central-refused' => 'Central refused the push of $repository.',
      final reason => 'Central refused the push of $repository (${named(reason, 'no reason given')}).',
    },
    'CentralPushUncertain' =>
      'The push of $repository was cut short, and may have reached central. Look at central before trying again.',
    'HostPushRefused' =>
      'The host refused the push${refusal.repository.isEmpty ? '' : ' at $repository'}: '
          '${_hostReasonWords(refusal.reason)}${refusal.code == null ? '' : ' (exit ${refusal.code})'}.',
    final kind => 'The machine refused it: $kind.',
  };
  return before.isEmpty ? words : '$words $before';
}

String _hostReasonWords(String reason) => switch (reason) {
  'selection' => 'its push configuration names no such repository',
  'account' => 'this account may not push from it',
  'settings' => 'its push configuration cannot be read',
  'program' => 'a program it runs is not the one it trusts',
  'configuration' => 'its push configuration is not as it must be',
  'authority' => 'the central forge’s certificate authority is not trusted',
  'vault' => 'the vault could not be read',
  'transfer' => 'the transfer failed',
  'unexpected' => 'something unexpected failed',
  '' => 'no reason given',
  final reason => reason,
};
