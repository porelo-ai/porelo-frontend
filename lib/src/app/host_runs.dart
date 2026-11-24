import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:porelo_host/porelo_host.dart';

import '../client/host_identity.dart';
import 'fleet_backend.dart' show KeepsHostIdentities;
import 'host_identity_export.dart';
import 'host_session.dart';
import 'host_access.dart';
import 'machines.dart';
import 'settings.dart';
import 'tunnel.dart' show Tunnel;
import '../wire/limit_factors.dart';

/// The confirmed stages of signed-state server setup.
enum HostPreparationPhase {
  /// The host command is running, stopped, or refused.
  preparing,

  /// The server supplied its checked SSH completion record.
  reachable,
}

/// One project's setup, retained independently of any dialog watching it.
class HostPreparation {
  /// Keeps only the public setup record, its running command and public tunnel settings.
  HostPreparation({
    required this.project,
    required this.session,
    required this.record,
    this.settings,
    this.providerMachine,
    this.interrupted = false,
  });

  /// The verified account connection used only for supported provider sign-ins.
  final Machine? providerMachine;

  /// Project identity, never a path.
  final String project;

  /// The command and its immutable arguments, reused for every resume.
  final HostSession session;

  /// The nonsecret setup answers, with the host key the server answers with now.
  HostUpRecord record;

  /// Persists public completion settings independently of the setup dialog's lifetime.
  final Settings? settings;

  /// The machine's name even before a daemon exists.
  String get name => record.hostName.isEmpty ? '$project server' : record.hostName;

  /// Whether the server completion was checked and kept.
  bool get ready => phase == HostPreparationPhase.reachable;

  /// The phase confirmed by the server completion.
  HostPreparationPhase phase = HostPreparationPhase.preparing;

  /// Whether only recovery is allowed for this rental.

  /// Whether the interface closed before setup could finish.
  bool interrupted;

  /// Whether the provider confirmed that the server was given back.
  bool givenBack = false;

  /// Completes once the latest protocol update has reached settings.
  Future<void> get saved => _saved ?? Future.value();
  Future<void>? _saved;
  String? _lastProtocol;
  VoidCallback? _listener;
  bool _saveFailed = false;

  bool _upActive = false;
  Future<void>? _probe;
  Timer? _poll;
  bool _lockFailed = false;

  /// Why recovery must wait for a fresh lock check on restart.
  String? get lockProblem => _lockFailed ? problem : null;

  /// The pending lock check, completed before recovery can start a command.
  Future<void> get checked => _probe ?? Future.value();

  /// Whether setup owns an active attempt, including persistence and machine confirmation.
  bool get running => _upActive || session.state == HostRunState.running || session.state == HostRunState.busy;

  /// A local refusal, such as an unusable completion destination.
  String? problem;

  /// The current attempt, including its confirmed machine addition.
  Future<void> finished = Future.value();

  /// Whether this run goes on and its command has said no line yet.
  bool get waitsForFirstLine {
    if (!_upActive && session.state != HostRunState.running) return false;
    // Until up adds this start's attempt, the last one shown is an earlier start's.
    final attempts = session.attempts;
    return attempts.length <= _attemptsBefore || attempts.last.entries.isEmpty;
  }

  int _attemptsBefore = 0;

  /// Whether the command has stopped for the person.
  bool get waiting => session.state == HostRunState.waiting;

  /// Whether a supported provider sign-in still needs a person.
  bool get needsYou => waiting;
}

/// Owns host setup just as Operations owns other long actions; views only observe it.
class HostRuns extends ChangeNotifier {
  /// Adds successful runs through the ordinary Machines path.
  HostRuns(
    this.machines, {
    this.environment,
    this.hostAccess,
    this.onReady,
    this.say,
    this.identities,
    this.exportIdentity,
    this.startExport,
  }) {
    for (final entry in machines.settings.hostUps.entries) {
      if (!entry.value.preparing) continue;
      final session = sessionFor(entry.key, entry.value)..restoreProtocol(entry.value.protocol);
      final run = HostPreparation(
        project: entry.key,
        session: session,
        record: entry.value,
        settings: machines.settings,
        interrupted: false,
      );
      _runs[entry.key] = run;
      _listen(run);
      session.state = HostRunState.busy;
      _check(run);
    }
  }

  /// Builds an idle command from the saved identity without starting a process.
  HostSession sessionFor(String project, HostUpRecord record) =>
      HostSession(executable: poreloHost(), arguments: hostArguments(record, project));

  /// Who may prepare a host, and what goes to the organization, supplied by the app composition.
  final HostAccess? hostAccess;

  /// Called once a host stands on its card, to give it the host admin's central token.
  final Future<void> Function(String host)? onReady;

  /// This computer's vault, opened, where a given server's identity is kept: a server set up anew under a host name it
  /// keeps one for gets that identity's keys, which the central forge knows.
  final Future<KeepsHostIdentities> Function()? identities;

  /// Reads a host's identity from the host itself; by default as root through the machine's pinned connection.
  final Future<HostIdentity> Function(String host)? exportIdentity;

  /// Starts the default export's ssh; [Process.start] where null.
  final StartHostCommand? startExport;

  final _keeping = <String, IdentityKeeping>{};
  final _keepingNow = <String, Future<IdentityKeeping>>{};

  /// How keeping [host]'s identity in this computer's vault last went, or null where it was never tried.
  IdentityKeeping? keepingOf(String host) => _keeping[host];

  /// The hosts whose identity is not kept, as the last try left it: each a row in *Needs you*.
  List<IdentityKeeping> get identitiesNotKept => [
    for (final keeping in _keeping.values)
      if (keeping.state == IdentityKeepingState.conflict || keeping.state == IdentityKeepingState.refused) keeping,
  ];

  /// The hosts whose identity is being kept right now; leaving waits for them.
  List<String> get keepingIdentities => _keepingNow.keys.toList();

  List<String>? _identitiesHere;
  String? _identitiesHereProblem;

  /// The hosts whose identity this computer's vault keeps, as last read; null before the first read, or where it
  /// could not be read.
  List<String>? get identitiesHere => _identitiesHere;

  /// Why the hosts whose identity the vault keeps could not be read, where they could not.
  String? get identitiesHereProblem => _identitiesHereProblem;

  /// Counts the reads of the kept identities, so only the newest one's answer is taken.
  int _identitiesRead = 0;

  /// Reads afresh which hosts' identities this computer's vault keeps. Where reads overlap, the one asked last is
  /// taken, whichever answers last.
  Future<void> readIdentitiesHere() async {
    final source = identities;
    if (source == null) return;
    final generation = ++_identitiesRead;
    bool stale() => generation != _identitiesRead;
    try {
      final hosts = await (await source()).hostIdentities();
      if (stale()) return;
      _identitiesHere = [...hosts]..sort();
      _identitiesHereProblem = null;
    } on HostIdentityVaultShut {
      if (stale()) return;
      _identitiesHere = null;
      _identitiesHereProblem = 'your Porelo-Vault is shut';
    } on HostIdentityFailure catch (failure) {
      if (stale()) return;
      _identitiesHere = null;
      _identitiesHereProblem = failure.words;
    } on Exception catch (error) {
      if (stale()) return;
      _identitiesHere = null;
      _identitiesHereProblem = "this computer's Porelo did not answer: $error";
    } on StateError catch (error) {
      if (stale()) return;
      _identitiesHere = null;
      _identitiesHereProblem = "this computer's Porelo did not answer: ${error.message}";
    }
    if (!_disposed) _changed();
  }

  /// Why [host] cannot be given up for good now, or null where it can: a setup or a keeping of it would write the
  /// identity anew while it goes.
  String? whyNotGiveUp(String host) {
    if (identities == null) return 'this window keeps no host identities';
    if (_givingUp.contains(host)) return 'it is being given up now';
    if (_runs.values.any((run) => run.record.hostName == host && run.running)) return 'its setup is running';
    if (_keepingNow.containsKey(host)) return 'its identity is being kept now';
    if (_identitiesHereProblem case final problem?) return problem;
    final here = _identitiesHere;
    if (here == null) return 'the identities your Porelo-Vault keeps are not read yet';
    if (!here.contains(host)) return 'your Porelo-Vault keeps no identity of $host';
    return null;
  }

  final _givingUp = <String>{};

  /// Marks [host] as being given up, from the person's confirmation to its result; false where it is already.
  bool beginGiveUp(String host) {
    if (!_givingUp.add(host)) return false;
    _changed();
    return true;
  }

  /// Ends [host]'s give-up: one that left nothing at the forge and no identity in the vault leaves no row offering to
  /// keep it. The kept identities are read afresh either way.
  Future<void> endGiveUp(String host, {required bool allGone}) async {
    _givingUp.remove(host);
    if (allGone && !_keepingNow.containsKey(host)) _keeping.remove(host);
    _changed();
    await readIdentitiesHere();
  }

  /// Ends once no keeping runs.
  Future<void> get keepingSettled async {
    while (_keepingNow.isNotEmpty) {
      await Future.wait(_keepingNow.values);
    }
  }

  /// Reads [host]'s identity from the host and keeps it in this computer's vault: after an up, a token's hand-on and
  /// before a give-back. [replace] alone overwrites another identity kept for it, and only the person asks for it.
  ///
  /// Null where this window keeps no identities. One keeping of a host at a time: a second ask gets the running one.
  Future<IdentityKeeping?> keepIdentity(String host, {bool replace = false}) {
    final source = identities;
    // A window that closes starts none: it would be cut off, or outlive the window.
    if (source == null || host.isEmpty || _leaving || _disposed) return Future.value();
    if (_keepingNow[host] case final running?) {
      // A replace is the person's own ask: it follows the running keeping, never merges into it.
      return replace ? running.then((_) => keepIdentity(host, replace: true)) : running;
    }
    // How the last try went stays until this one ends: a row not kept stays, marked busy, and resolves only once kept.
    _keeping.putIfAbsent(host, () => IdentityKeeping(host, IdentityKeepingState.keeping));
    late final Future<IdentityKeeping> keeping;
    keeping = _keep(source, host, replace: replace).whenComplete(() {
      if (identical(_keepingNow[host], keeping)) _keepingNow.remove(host);
      _changed();
    });
    _keepingNow[host] = keeping;
    _changed();
    return keeping;
  }

  Future<IdentityKeeping> _keep(
    Future<KeepsHostIdentities> Function() source,
    String host, {
    required bool replace,
  }) async {
    IdentityKeeping done;
    try {
      final identity = await (exportIdentity ?? _exportFromItsMachine)(host);
      final vault = await source();
      await vault.hostIdentityKeep(host, identity, replace: replace);
      done = IdentityKeeping(host, IdentityKeepingState.kept);
    } on HostIdentityExists catch (failure) {
      done = IdentityKeeping(host, IdentityKeepingState.conflict, why: failure.words);
    } on HostIdentityFailure catch (failure) {
      done = IdentityKeeping(host, IdentityKeepingState.refused, why: failure.words);
    } on HostIdentityExportRefused catch (refused) {
      done = IdentityKeeping(host, IdentityKeepingState.refused, why: refused.words);
    } on Exception catch (error) {
      done = IdentityKeeping(host, IdentityKeepingState.refused, why: "This computer's Porelo did not answer: $error");
    } on StateError catch (error) {
      done = IdentityKeeping(
        host,
        IdentityKeepingState.refused,
        why: "This computer's Porelo did not answer: ${error.message}",
      );
    }
    if (!_disposed) _keeping[host] = done;
    if (done.state == IdentityKeepingState.kept) unawaited(readIdentitiesHere());
    return done;
  }

  /// Reads [host]'s identity through the machine this window reaches it as; where it has none, through the host's
  /// verified card, or as porelo-host reached it, at the address and host key its setup record holds.
  Future<HostIdentity> _exportFromItsMachine(String host) async {
    final machine = machines.all
        .where(
          (machine) =>
              machine.kind == 'host' &&
              (machine.hostCard?.name == host ||
                  (machine.hostCard == null && machines.settings.hostUp(machine.hostProject)?.hostName == host)),
        )
        .firstOrNull;
    if (machine != null) {
      return exportHostIdentity(machine, hostName: host, start: startExport, cancelled: _ended.future);
    }
    final String config;
    try {
      config = poreloHostSshConfig(host, environment: environment);
    } on FormatException {
      throw HostIdentityExportRefused('$host is no host name this computer can reach.');
    }
    if (await File(config).exists()) {
      return exportHostIdentityByCard(config, hostName: host, start: startExport, cancelled: _ended.future);
    }
    final record = machines.settings.hostUps.values
        .where((record) => record.hostName == host && record.preparedHost != null)
        .firstOrNull;
    final values = record?.preparedHost?.values ?? const <String, Object?>{};
    if (values case {'address': final String address, 'ssh_host_key': final String hostKey}) {
      return exportHostIdentityPinned(
        hostName: host,
        address: address,
        hostKey: hostKey,
        port: switch (values['ssh_port']) {
          final int port => port,
          _ => 22,
        },
        start: startExport,
        cancelled: _ended.future,
      );
    }
    throw HostIdentityExportRefused('This computer does not reach $host: connect to it first.');
  }

  /// Says what the person must hear with no dialog open: a rental given back after a stop.
  final void Function(String words)? say;

  /// State directory overrides shared with an explicitly configured host command.
  final Map<String, String>? environment;
  bool _leaving = false;

  void _check(HostPreparation run) {
    final probe = _probe(run);
    run._probe = probe;
    unawaited(
      probe.whenComplete(() {
        if (identical(run._probe, probe)) run._probe = null;
      }),
    );
  }

  Future<void> _probe(HostPreparation run) async {
    if (_disposed || _leaving || run._upActive || run.session.state == HostRunState.running) return;
    try {
      final file = File(_lockPath(run.project, run.record));
      final held = await _serializeLock(file.path, () async {
        await file.parent.create(recursive: true);
        final handle = await openProjectLock(file);
        var held = false;
        try {
          try {
            await handle.lock(FileLock.exclusive);
          } on FileSystemException catch (error) {
            // Only contention proves another command is running; other failures need a refusal.
            if (![11, 13, 32, 33].contains(error.osError?.errorCode)) rethrow;
            held = true;
          }
        } finally {
          // Closing any descriptor can release this process's fcntl lock, so close before any action.
          await handle.close();
        }
        return held;
      });
      if (_disposed || _leaving || run.givenBack) return;
      run.session.state = held ? HostRunState.busy : HostRunState.idle;
      run.interrupted = !held;
      run.problem = null;
      run._lockFailed = false;
      if (held) {
        _poll(run);
      } else {
        run.session.interrupt();
        await run.saved;
      }
    } on Exception {
      if (_disposed || _leaving) return;
      run._lockFailed = true;
      run.session.state = HostRunState.refused;
      run.problem = 'The setup lock could not be checked. Close and reopen the interface to try again.';
    }
    _changed();
  }

  /// Opens the single probe descriptor; tests can delay its lock to exercise a concurrent resume.
  @visibleForTesting
  Future<RandomAccessFile> openProjectLock(File file) => file.open(mode: FileMode.append);

  void _poll(HostPreparation run) {
    run._poll?.cancel();
    run._poll = Timer(pollEvery(const Duration(seconds: 1)), () {
      if (_disposed || _leaving || run.givenBack || run._upActive || run.session.state != HostRunState.busy) return;
      _check(run);
    });
  }

  /// Ends only setup attempts that have not finished renting; later work survives the window.
  Future<void> leave() async {
    _leaving = true;
    try {
      // A keeping cut short leaves the server's keys out of the vault; each ends within its export's limit.
      await keepingSettled.timeout(keepingLimit, onTimeout: () {});
      await Future.wait([for (final run in preparing) run.session.leave()]);
      await Future.wait([for (final run in preparing) run.saved]);
      if (preparing.any((run) => run._saveFailed)) {
        throw const FileSystemException('The setup protocol could not be kept. Keep the interface open.');
      }
    } on Exception {
      _leaving = false;
      rethrow;
    }
  }

  /// The longest a keeping takes: its export's limit, and the vault's answer after it. Leaving waits at most this.
  static const keepingLimit = Duration(seconds: 45);

  /// Ends with this window's runs: an export still reading then stops, with its process and its timer.
  final _ended = Completer<void>();

  /// The fleet which receives a host after a successful up.
  final Machines machines;
  final Map<String, HostPreparation> _runs = {};
  bool _disposed = false;

  /// Every run still awaiting successful preparation, including refusals.
  List<HostPreparation> get preparing => _runs.values.where((run) => !run.ready && !run.givenBack).toList();

  /// The latest setup of a project, including its completed protocol.
  HostPreparation? of(String project) => _runs[project];

  /// Stops and interruptions needing a person, including setup run again on a ready server.
  List<HostPreparation> get needingYou =>
      _runs.values.where((run) => !run.givenBack && (run.needsYou || run.interrupted)).toList();

  /// Why a ready server cannot start another setup attempt now.
  String? againUnavailable(String project) {
    if (_disposed || _leaving) return 'the interface is closing';
    final record = machines.settings.hostUp(project);
    final run = _runs[project];
    if (run?.lockProblem case final problem?) return problem;
    if (run?.running == true) return 'the machine setup command is still running';
    if (run != null && (run.needsYou || run.interrupted)) return 'setup waits for you under Needs you';
    if (run != null && (!run.ready || run.givenBack)) return 'the server is not ready';
    if (record == null) return 'the setup arguments were not kept';
    if (record.preparing || !machines.all.any((machine) => machine.kind == 'host' && machine.hostProject == project)) {
      return 'the server is not ready';
    }
    return null;
  }

  static final _localLockOwners = <String, Future<void>>{};

  static Future<T> _serializeLock<T>(String path, Future<T> Function() action) async {
    final previous = _localLockOwners[path];
    final released = Completer<void>();
    _localLockOwners[path] = released.future;
    try {
      await previous;
      return await action();
    } finally {
      released.complete();
      if (identical(_localLockOwners[path], released.future)) _localLockOwners.remove(path);
    }
  }

  String _lockPath(String project, HostUpRecord record) =>
      poreloHostProjectLock(HostPlan.lockNameForTag(record.rentalTagFor(project)), environment: environment);

  /// Re-enters the verified setup flow for this same rental.
  Future<void> again(String project) {
    if (againUnavailable(project) != null) return _runs[project]?.finished ?? Future.value();
    var run = _runs[project];
    if (run == null) {
      final record = machines.settings.hostUp(project)!;
      run = HostPreparation(
        project: project,
        session: sessionFor(project, record)..restoreProtocol(record.protocol),
        record: record,
        settings: machines.settings,
      )..phase = HostPreparationPhase.reachable;
      _runs[project] = run;
      _listen(run);
    }
    return run.finished = _up(run);
  }

  /// Takes ownership before starting, so no command depends on the setup view's lifetime.
  ///
  /// [organizationReadJustNow] says the caller has just read the organization and written the machine file for this
  /// start, so `up` starts without reading it again; the admin is still required on that read.
  HostPreparation start({
    required String project,
    required HostSession session,
    required HostUpRecord record,
    Settings? settings,
    bool organizationReadJustNow = false,
  }) {
    if (hostAccess == null) throw const HostAccessRefused('The verified Machine Admins are unavailable.');
    hostAccess!.requireAdmin(record.hostName);
    final previous = _runs[project];
    if (_leaving || previous != null && (previous.running || previous.waiting)) {
      throw StateError('This project already has a machine setup run.');
    }
    previous?._poll?.cancel();
    if (previous?._listener case final listener?) previous!.session.removeListener(listener);
    previous?.session.dispose();
    final run = HostPreparation(
      project: project,
      session: session,
      record: record.withPreparation(record.startedAt ?? DateTime.now().toUtc()),
      settings: settings ?? machines.settings,
    );
    _runs[project] = run;
    _listen(run);
    run.finished = _up(run, newPreparation: true, organizationRead: organizationReadJustNow);
    _changed();
    return run;
  }

  /// Checks the stop again using exactly the arguments the original command ran with.
  Future<void> resume(HostPreparation run) {
    if (_disposed ||
        _leaving ||
        run.ready && !run.needsYou && !run.interrupted ||
        run.givenBack ||
        run._upActive ||
        run.session.state == HostRunState.running ||
        run._lockFailed) {
      return run.finished;
    }
    return run.finished = _up(run);
  }

  Future<void> _up(HostPreparation run, {bool newPreparation = false, bool organizationRead = false}) async {
    final probe = run._probe;
    run._upActive = true;
    run._attemptsBefore = run.session.attempts.length;
    run._poll?.cancel();
    run.problem = null;
    _changed();
    try {
      await probe;
      if (_disposed || _leaving) return;
      if (run.session.state == HostRunState.busy) {
        _poll(run);
        return;
      }
      if (run.problem != null) return;
      // Each read may wait up to a minute on the forge while the protocol shows nothing, so a read made for this very
      // start stands, and writing the machine file is the check where there is one.
      if (run.record.hostName.isNotEmpty && !organizationRead) {
        if (hostAccess == null) throw const HostAccessRefused('The verified Machine Admins are unavailable.');
        if (run.record.machineFile.isNotEmpty) {
          // A run taken up again must not hand on the pin of its first start.
          await hostAccess!.machineFile(run.record.hostName);
        } else {
          await hostAccess!.check(run.record.hostName);
        }
      }
      // Decided before anything is kept: a start refused here leaves no setup under way to take up again.
      HostIdentity? identity;
      if (!run.record.isRental && run.record.hostName.isNotEmpty) {
        try {
          identity = await _identityOf(run.record.hostName);
        } on HostIdentityFailure catch (failure) {
          // A vault that could not say is never taken for one that keeps none: the run does not start.
          if (newPreparation) run.record = run.record.withPreparation(null);
          run.problem = 'Setup of ${run.name} did not start: ${failure.words}';
          run.session
            ..state = HostRunState.refused
            ..fix = failure.words;
          say?.call(run.problem!);
          return;
        }
        if (_disposed || _leaving) return;
      }
      final settings = run.settings;
      if (settings != null && !run.ready) {
        final kept = newPreparation ? run.record : settings.hostUp(run.project) ?? run.record;
        await settings.rememberHostUp(run.project, kept.withPreparation(run.record.startedAt));
      }
      if (_disposed || _leaving) return;
      run.interrupted = false;
      if (run.record.hostName.isNotEmpty) {
        if (hostAccess == null) throw const HostAccessRefused('The verified Machine Admins are unavailable.');
        hostAccess!.requireAdmin(run.record.hostName);
      }
      await run.session.up(identity: identity);
      await run.saved;
      if (run._saveFailed) throw const FileSystemException('The setup protocol could not be kept.');
      if (_disposed) return;
      if (run.session.state == HostRunState.done && !run.ready) {
        await _addHost(run, carried: identity == null ? null : HostIdentityPublic.read(identity.wire).ed25519);
      } else if (!run.ready && const [HostRunState.refused, HostRunState.unreachable].contains(run.session.state)) {
        final said = run.session.fix ?? run.session.stepText;
        final stop = 'Setup of ${run.name} stopped: ${said.endsWith('.') ? said : '$said.'}';
        // Nothing of a run refused at its first login stands on the machine, so there is no setup to remove.
        run.problem = stop;
        if (_stoppedAtItsFirstLogin(run)) {
          say?.call(stop);
        } else {
          _stopped(run, stop);
        }
      }
      if (run.session.state == HostRunState.busy) _poll(run);
      // The server holds its identity now, a new one or the one carried in: the vault keeps it as it stands.
      if (run.session.state == HostRunState.done && run.ready && !run.record.isRental) {
        unawaited(keepIdentity(run.record.hostName));
      }
    } on Exception {
      if (!_disposed) {
        run.session.state = HostRunState.refused;
        run.problem ??= 'The machine setup command could not complete. Your machines have been kept.';
      }
    } finally {
      run._upActive = false;
      _changed();
    }
  }

  /// The identity this computer's vault keeps for [host], or null where it keeps none; any other answer fails.
  Future<HostIdentity?> _identityOf(String host) async {
    final source = identities;
    if (source == null) return null;
    final KeepsHostIdentities vault;
    try {
      vault = await source();
    } on HostIdentityFailure {
      rethrow;
    } on Exception catch (ex) {
      throw HostIdentityUnreached('$ex');
    } on StateError catch (error) {
      // A connection that cannot open, or is closed, says so as a StateError.
      throw HostIdentityUnreached(error.message);
    }
    try {
      await vault.hostIdentityPublic(host);
    } on HostIdentityUnknown {
      return null;
    }
    return vault.hostIdentityRead(host);
  }

  /// [carried] is the ed25519 key of the identity this up carried in, which the server answers with now.
  Future<void> _addHost(HostPreparation run, {String? carried}) async {
    final host = run.session.preparedHost;
    if (host == null ||
        host.values['address'] != run.session.address ||
        host.values['name'] != run.record.hostName ||
        !run.session.steps.any((step) => step.step == 'up' && step.state == StepState.done) ||
        run.session.steps.any((step) => step.state == StepState.refused)) {
      _stopped(run, 'The server did not confirm its SSH completion record.');
      return;
    }
    final access = hostAccess;
    final refused = access == null ? 'The verified Machine Admins are unavailable.' : await access.writeCard(host);
    if (refused != null) {
      _stopped(run, "${run.name}'s card could not be written to the organization: $refused");
      return;
    }
    final settings = run.settings ?? machines.settings;
    var kept = (settings.hostUp(run.project) ?? run.record).withPreparedHost(host).withPreparation(null);
    // A given server set up with its identity answers with the identity's key now; the CLI checked it and pinned it.
    final key = host.values['ssh_host_key'];
    if (kept.givenAddress.isNotEmpty && key is String && key == carried && key != kept.givenHostKey) {
      kept = kept.withGivenHostKey(key);
      run.record = run.record.withGivenHostKey(key);
      run.session.repinHostKey(key);
    }
    await settings.rememberHostUp(run.project, kept);
    await machines.add(
      Machine(
        name: run.name,
        kind: 'host',
        socketPath: '',
        host: '${host.values['address']}',
        hostProject: run.project,
      ),
    );
    run.phase = HostPreparationPhase.reachable;
    // Its first follow makes the person's account, within five minutes: until then a turn-away is waited for.
    machines.tunnels.awaitAdmission(run.record.hostName, by: DateTime.now().add(Tunnel.admissionWait));
    await onReady?.call(run.record.hostName);
  }

  /// Says a stop. Nothing is given back unasked: this attempt rented nothing, since `up` only takes a server given to it.
  void _stopped(HostPreparation run, String why) {
    final action = run.record.isRental ? 'Return this rental…' : 'Take Porelo off this machine…';
    final words = '$why The machine stays as it is: "$action" on its row removes its setup.';
    run.problem = words;
    say?.call(words);
  }

  /// Whether [run] stopped at its first login on a machine one already has, with no try ever past it, so
  /// nothing of it stands on the machine and its answers can be given again.
  bool mayStartOver(HostPreparation run) => !run.running && _stoppedAtItsFirstLogin(run);

  bool _stoppedAtItsFirstLogin(HostPreparation run) =>
      !run.record.isRental &&
      run.record.preparedHost == null &&
      (run.problem ?? '').contains(hostKeyNotFiled) &&
      !run.session.attempts.any((attempt) => attempt.entries.any(_passedTheLogin));

  static bool _passedTheLogin(Object entry) =>
      entry is HostStepRecord && entry.step.step == 'ssh' && entry.step.state == StepState.done;

  /// Lets go of such a run: its saved answers would only be refused the same way.
  Future<void> startOver(HostPreparation run) async {
    if (!mayStartOver(run)) return;
    await run.saved;
    run._poll?.cancel();
    if (run._listener case final listener?) run.session.removeListener(listener);
    run._listener = null;
    _runs.remove(run.project);
    await (run.settings ?? machines.settings).forgetHostUp(run.project);
    _changed();
  }

  /// Removes recovery only after the provider confirmed give-back and the command succeeded.
  Future<String?> confirmDown(String project, HostSession session) async {
    if (!hostGivenBack(session)) return null;
    final pending = _runs[project];
    await pending?.saved;
    final left = hostAccess?.cardLeftBehind(project);
    final kept = machines.settings.hostUp(project);
    if (kept != null) {
      await machines.settings.forgetHostUp(project);
    }
    // Its identity can no longer be kept: no row offers it.
    for (final host in {kept?.hostName, pending?.record.hostName}) {
      if (host != null && host.isNotEmpty && !_keepingNow.containsKey(host)) _keeping.remove(host);
    }
    final run = _runs[project];
    if (run != null) {
      run._poll?.cancel();
      run.givenBack = true;
      run.interrupted = false;
      run.problem = left;
    }
    _changed();
    return left;
  }

  /// Drops what was said of [project]'s card still naming it, once the organization removed it.
  void forgetLeftBehind(String project) {
    final run = _runs[project];
    if (run == null || run.problem == null) return;
    run.problem = null;
    _changed();
  }

  void _listen(HostPreparation run) {
    run._lastProtocol = jsonEncode([for (final entry in run.session.keptProtocol) entry.stored]);
    void changed() {
      final protocol = run.session.keptProtocol;
      final encoded = jsonEncode([for (final entry in protocol) entry.stored]);
      if (!run.givenBack && run._lastProtocol != encoded) {
        run._lastProtocol = encoded;
        Future<void> keep() async {
          final settings = run.settings;
          if (settings == null || run.givenBack) return;
          final kept = settings.hostUp(run.project) ?? run.record;
          await settings.rememberHostUp(run.project, kept.withProtocol(protocol));
          run._saveFailed = false;
        }

        late final Future<void> saving;
        saving = (run._saved?.then((_) => keep()) ?? keep()).then(
          (_) {
            if (identical(run._saved, saving)) run._saved = null;
          },
          onError: (Object _, StackTrace _) {
            if (identical(run._saved, saving)) run._saved = null;
            run._saveFailed = true;
            run.problem = 'The setup protocol could not be kept. Keep the interface open and check the settings file.';
            _changed();
          },
        );
        run._saved = saving;
      }
      _changed();
    }

    run._listener = changed;
    run.session.addListener(changed);
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    if (!_ended.isCompleted) _ended.complete();
    for (final run in _runs.values) {
      run._poll?.cancel();
      if (run._listener case final listener?) run.session.removeListener(listener);
      run.session.dispose();
    }
    super.dispose();
  }
}

/// The facts shown for a stop, frozen so Recently resolved does not change on resume.
@immutable
class HostStop {
  /// Captures a run's stop and its source text without deriving new step words.
  HostStop(HostPreparation run)
    : project = run.project,
      interrupted = run.interrupted,
      text = run.interrupted
          ? 'Setup of ${run.name} was interrupted — the server is rented and billed'
          : run.session.stepText,
      needs = List.unmodifiable(run.session.needs);

  /// Project to find when the stop's action is opened.
  final String project;

  /// Whether this row offers recovery rather than a terminal for a host stop.
  final bool interrupted;

  /// Words sent on the stop line, or its task name if none were sent.
  final String text;

  /// Requirements named by the host.
  final List<String> needs;
}

/// Whether teardown confirmed give-back or the absence of a rented project host.
bool hostGivenBack(HostSession session) =>
    session.state == HostRunState.done &&
    !session.steps.any((step) => step.state == StepState.refused) &&
    session.steps.any((step) => step.step == 'give-back' && step.state == StepState.done);

/// How keeping a host's identity in this computer's vault stands.
enum IdentityKeepingState {
  /// It is being read from the host and kept.
  keeping,

  /// The vault keeps it as the host holds it.
  kept,

  /// The vault keeps another identity for the host; only the person may replace it.
  conflict,

  /// It could not be read from the host, or the vault refused it.
  refused,
}

/// How keeping one host's identity last went.
final class IdentityKeeping {
  /// Takes the host, how it went and why where it did not.
  const IdentityKeeping(this.host, this.state, {this.why});

  /// The host, as its card names it.
  final String host;

  /// How it went.
  final IdentityKeepingState state;

  /// Why it was not kept, for a person; never part of a key.
  final String? why;
}
