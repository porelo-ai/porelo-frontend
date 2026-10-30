import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:porelo_host/porelo_host.dart' show HostCardSsh, HostFileWriter, HostFilesRefused;

import 'connections.dart';
import 'machines.dart';
import 'host_keys.dart';
import 'fleet_backend.dart';
import 'owned_process.dart';

/// What an attempt to start a daemon came back with.
@immutable
class Started {
  /// Constructor taking whether it ran and what it said.
  const Started({required this.went, required this.words});

  /// Whether ssh ran the line and it came back without complaint.
  ///
  /// **Not whether a daemon is now serving.** Only connecting says that, which is why a start is
  /// always followed by a trial: a line that ran cleanly and left nothing listening is exactly
  /// what a missing binary or a socket already taken looks like from here.
  final bool went;

  /// What came back, as it came.
  final String words;
}

/// Where a managed forward has got to.
enum TunnelState {
  /// Nothing has been asked of it yet.
  idle,

  /// `ssh` has been started and the socket is not there yet.
  raising,

  /// The owned transport answers, independently of the remote daemon's readiness.
  up,

  /// It could not be raised, or it went away and could not be raised again. [Tunnel.problem]
  /// carries what the transport said.
  down,

  /// The local key is absent from the agent, or Core explicitly needs it unlocked.
  waitingForKey,
}

/// One supervised SSH connection this interface raised and owns.
///
/// Imported cards use a private master shared by the host's services and commands.
/// Other SSH machines retain their independent daemon forward. Batch mode prevents
/// prompts; no private key or secret enters this transport. Only owned processes
/// and endpoints are removed when the window closes.
class Tunnel {
  /// Constructor taking which machine to reach.
  ///
  /// [start] is injectable so this can be proven without a remote host: a stand-in that creates
  /// the socket and stays up, or one that fails the way `ssh` fails, exercises every path here.
  Tunnel(
    this.machine, {
    Future<Process> Function(List<String> command)? start,
    Future<ProcessResult> Function(List<String> command)? run,
    Duration appears = const Duration(seconds: 10),
    Duration explains = const Duration(seconds: 5),
    this.onChanged,
    this.keyAvailable,
    HostUnlocker? unlocker,
    this.portsAvailable,
    this.messengerSocket,
    this.writer,
    this.configEnvironment,
  }) : _launch = start ?? _runIt,
       _tighten = run ?? _runAndWait,
       _untilItBinds = appears,
       _untilExplained = explains,
       _unlocker = unlocker ?? CoreHostUnlocker(environment: configEnvironment);

  /// The local public-key availability check, without agent forwarding.
  final Future<bool> Function(HostCardSsh)? keyAvailable;

  /// The fixed-port preflight, injectable without changing endpoint selection.
  final Future<void> Function(HostCardSsh)? portsAvailable;

  /// The local messenger socket, present only while the messenger needs a return path.
  final String? messengerSocket;

  /// The private public-file publisher.
  final HostFileWriter? writer;

  /// The platform config environment, injectable for isolated tests.
  final Map<String, String>? configEnvironment;
  final HostUnlocker _unlocker;

  /// The vault refusal beside an SSH-reached host, independent of daemon readiness.
  String? vaultProblem;

  /// Core's last public vault result, separate from SSH readiness.
  HostUnlockState? vaultState;
  bool _ownsEndpoints = false;

  /// The machine this forwards to.
  final Machine machine;

  final Future<Process> Function(List<String> command) _launch;
  final Future<ProcessResult> Function(List<String> command) _tighten;
  final Duration _untilItBinds;
  final Duration _untilExplained;

  /// Lets the owner show a dropped forward and any later refusal explanation.
  final VoidCallback? onChanged;
  int _generation = 0;

  Process? _process;
  bool _wanted = false;

  /// Where it has got to.
  TunnelState state = TunnelState.idle;

  /// What the transport said, when it could not be raised. Null when nothing is wrong.
  ///
  /// Explained where [whySshRefused] can tell, else **`ssh`'s own words**: *"Host key verification
  /// failed"* and *"Connection refused"* send somebody to different places.
  String? problem;

  /// How many times it has been raised, so a re-raise is observable.
  int raised = 0;

  /// The command that raises it.
  ///
  /// `-N` because nothing is run at the far end; `ExitOnForwardFailure` so a forward that cannot
  /// bind fails the process rather than leaving `ssh` up with no socket under it, which would
  /// read as connected.
  List<String> get command => machine.hostCard != null
      ? _cardCommand
      : machine.host.startsWith('-')
      ? throw ArgumentError('An ssh host must not start with a dash.')
      : <String>[
          openSsh('ssh'),
          ...machine.loginSshOptions,
          '-N',
          if (machine.kind != 'host') ...<String>['-o', 'BatchMode=yes'],
          '-o', 'ExitOnForwardFailure=yes',
          '-o', 'ServerAliveInterval=15',
          // A connection of its own, whatever the person's ssh config says: through their master the
          // forward would live in the master, and letting go of this process would leave it running.
          if (machine.kind != 'host') ...<String>['-o', 'ControlMaster=no', '-o', 'ControlPath=none'],
          '-L', '${machine.socketPath}:${machine.remoteSocket}',
          machine.host,
        ];

  List<String> get _cardCommand {
    final card = machine.hostCard!;
    return [
      openSsh('ssh'),
      '-F',
      machine.sshConfig,
      '-M',
      '-N',
      '-o',
      'ExitOnForwardFailure=yes',
      '-o',
      'ServerAliveInterval=15',
      '-o',
      'ServerAliveCountMax=2',
      for (var i = 0; i < card.ports.length; i++) ...[
        '-L',
        '127.0.0.1:${card.ports[i]}:${HostCardSsh.serviceSockets[i]}',
      ],
      '-L',
      '${machine.socketPath}:${card.daemonSocket}',
      if (messengerSocket != null) ...['-R', '${card.returnSocket}:$messengerSocket'],
      card.name,
    ];
  }

  /// Raises it, and waits until the socket is there or the transport says why not.
  Future<void> raise() async {
    if (machine.hostCard != null) return _raiseCard();
    final generation = ++_generation;
    _wanted = true;
    state = TunnelState.raising;
    problem = null;

    // Our own previous process first. A re-raise while the old `ssh` is still alive would
    // otherwise meet its socket below and refuse it as somebody else's.
    await _stopWhatWeStarted();
    if (generation != _generation) return;

    // **A socket that answers belongs to somebody.** It may be another program of this user that
    // happens to sit at that path, and taking its endpoint away to put ours there would break it
    // silently. Refused instead, and said. Told apart by connecting, exactly as
    // [OneInstance.take] tells its own leftover from a running interface.
    final alreadyServing = await _somebodyIsServing();
    if (generation != _generation) return;
    if (alreadyServing) {
      state = TunnelState.down;
      problem = 'something is already serving ${machine.socketPath}, and it was left alone';
      return;
    }

    // ssh refuses to bind a path that already exists. A socket left by a run that died answers
    // nothing, so it is a leftover, and the alternative is a machine that can never be opened
    // again without somebody knowing to delete a file they have never heard of.
    _clearTheWay();

    final stopped = Completer<void>();
    try {
      final process = await _launch(command);
      if (generation != _generation) {
        process.kill();
        return;
      }
      _process = process;
      raised++;
      // Collected as one future rather than read line by line, because **the process can exit
      // before a subscription has delivered anything**: `ssh` prints one line and dies, and the
      // first version of this reported "exit code 255" with the sentence still in the pipe.
      final saying = process.stderr.transform(utf8.decoder).transform(const LineSplitter()).toList();
      unawaited(
        process.exitCode.then((code) async {
          await _itEnded(code, saying, generation);
          if (!stopped.isCompleted) stopped.complete();
        }),
      );
    } on ProcessException catch (ex) {
      if (generation != _generation) return;
      state = TunnelState.down;
      problem = ex.message;
      return;
    }

    final by = DateTime.now().add(_untilItBinds);
    while (DateTime.now().isBefore(by)) {
      // The state and the words are both set before this completes, so there is nothing to race.
      if (generation != _generation || stopped.isCompleted) return;
      if (state == TunnelState.down) {
        await stopped.future;
        return;
      }
      // A *socket*, not merely a file. Anything left at that path would otherwise read as a
      // working forward — which is exactly what a leftover from a run that died looks like.
      if (FileSystemEntity.typeSync(machine.socketPath) == FileSystemEntityType.unixDomainSock) {
        final ownerOnly = await _ownerOnly();
        if (generation != _generation) return;
        if (!ownerOnly) {
          // The one property of the transport that can be checked from here, and it is the one
          // the requirement names. A forward anybody on the machine can read is not the thing
          // that was asked for, so it is taken down rather than reported as working.
          await _stopWhatWeStarted();
          _clearTheWay();
          state = TunnelState.down;
          problem = 'the endpoint could not be made readable by nobody but you';
          return;
        }
        state = TunnelState.up;
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    // Up, and nothing bound. Said as a wait rather than as a refusal, because it is neither a
    // rejection by the far end nor a fault anybody can name.
    if (generation != _generation) return;
    if (state == TunnelState.down) {
      await stopped.future;
      return;
    }
    state = TunnelState.down;
    problem = 'the forward did not appear within ${_untilItBinds.inSeconds} seconds';
  }

  Future<void> _raiseCard() async {
    final generation = ++_generation;
    final card = machine.hostCard!;
    _wanted = true;
    state = TunnelState.raising;
    problem = null;
    vaultProblem = null;
    vaultState = null;
    try {
      await _stopWhatWeStarted();
      await _unlocker.cancel(card.name);
      if (generation != _generation) return;
      _clearOwnedCardEndpoints();
      HostCardSsh.checkLocalSocket(machine.socketPath);
      HostCardSsh.checkLocalSocket(card.controlSocket(machine.sshConfig));
      if (messengerSocket != null) HostCardSsh.checkMessengerSocket(messengerSocket!);
      for (final endpoint in [machine.socketPath, card.controlSocket(machine.sshConfig)]) {
        if (FileSystemEntity.typeSync(endpoint, followLinks: false) != FileSystemEntityType.notFound) {
          state = TunnelState.down;
          problem = 'Host ${card.name} cannot start: an endpoint already exists and was left alone.';
          return;
        }
      }
      await (portsAvailable?.call(card) ?? card.checkPortsAvailable());
      final available = await (keyAvailable?.call(card) ?? _agentHasKey(card));
      if (generation != _generation) return;
      if (!available) {
        state = TunnelState.waitingForKey;
        problem = 'Waiting for your key. Unlock KeePassXC with your selected key available.';
        return;
      }
      await card.publish(machine.sshConfig, writer: writer, environment: configEnvironment);
      if (generation != _generation) return;
      final process = await _launch(command);
      if (generation != _generation) {
        await stopOwnedProcess(process);
        _ownsEndpoints = true;
        _clearOwnedCardEndpoints();
        return;
      }
      _process = process;
      _ownsEndpoints = true;
      raised++;
      unawaited(process.stdout.drain<void>());
      final saying = process.stderr.transform(utf8.decoder).transform(const LineSplitter()).toList();
      unawaited(process.exitCode.then((code) => _itEnded(code, saying, generation)));
      final by = DateTime.now().add(_untilItBinds);
      while (generation == _generation && state == TunnelState.raising && DateTime.now().isBefore(by)) {
        final check = await _tighten([openSsh('ssh'), '-F', machine.sshConfig, '-O', 'check', card.name])
            .timeout(_untilExplained);
        if (generation != _generation || state != TunnelState.raising) return;
        if (check.exitCode == 0) {
          state = TunnelState.up;
          await unlockVault();
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      if (generation != _generation || state == TunnelState.down) return;
      await _stopWhatWeStarted();
      _clearOwnedCardEndpoints();
      state = TunnelState.down;
      problem = 'The SSH master did not answer within ${_untilItBinds.inSeconds} seconds.';
    } on TimeoutException {
      if (generation != _generation) return;
      state = TunnelState.down;
      problem = 'The host transport check timed out.';
    } on HostFilesRefused catch (refused) {
      if (generation != _generation) return;
      state = TunnelState.down;
      problem = refused.message;
    } on ProcessException {
      if (generation != _generation) return;
      state = TunnelState.down;
      problem = 'The required host transport command is unavailable.';
    } on FileSystemException {
      if (generation != _generation) return;
      state = TunnelState.down;
      problem = 'The host transport files could not be prepared or cleaned up.';
    } finally {
      if (generation == _generation && state == TunnelState.down) {
        await _stopWhatWeStarted();
        _clearOwnedCardEndpoints();
      }
    }
  }

  /// Retries Core unlock on the existing master without changing fixed endpoints.
  Future<void> unlockVault() async {
    if (machine.hostCard == null || state != TunnelState.up) return;
    final generation = _generation;
    final unlocked = await _unlocker.unlock(machine.hostCard!.name, machine.sshConfig);
    if (generation != _generation || state != TunnelState.up) return;
    vaultState = unlocked.state;
    vaultProblem = switch (unlocked.state) {
      HostUnlockState.unlocked => null,
      HostUnlockState.waitingForKey => 'Waiting for your key. Unlock KeePassXC to open the host vault.',
      _ => unlocked.words ?? 'Core could not unlock the host vault.',
    };
  }

  Future<void> _cancelRaise() async {
    _generation++;
    _wanted = false;
    state = TunnelState.down;
    if (machine.hostCard != null) await _unlocker.cancel(machine.hostCard!.name);
  }

  Future<bool> _agentHasKey(HostCardSsh card) async {
    final result = await _tighten([openSsh('ssh-add'), '-L']).timeout(_untilExplained);
    if (result.exitCode != 0) return false;
    return '${result.stdout}'.split('\n').any((line) => line.split(' ').take(2).join(' ') == card.publicKey);
  }

  void _clearOwnedCardEndpoints() {
    if (!_ownsEndpoints) return;
    FileSystemException? failure;
    for (final endpoint in [machine.socketPath, machine.hostCard!.controlSocket(machine.sshConfig)]) {
      try {
        if (FileSystemEntity.typeSync(endpoint, followLinks: false) == FileSystemEntityType.unixDomainSock) {
          File(endpoint).deleteSync();
        }
      } on FileSystemException catch (error) {
        if (error.osError?.errorCode != 2) failure ??= error;
      }
    }
    if (failure != null) throw failure;
    _ownsEndpoints = false;
  }

  /// Takes it down and removes what it left.
  ///
  /// Safe to call on a tunnel that was never raised, which is what makes closing the window able
  /// to call it on everything without asking which is which.
  Future<void> drop() async {
    _generation++;
    final wasWanted = _wanted;
    _wanted = false;
    if (machine.hostCard != null && wasWanted) await _unlocker.cancel(machine.hostCard!.name);
    await _stopWhatWeStarted();
    if (machine.hostCard == null) {
      _clearTheWay();
    } else {
      _clearOwnedCardEndpoints();
    }
    state = TunnelState.idle;
  }

  /// Takes down the process this tunnel started, if it is still there.
  Future<void> _stopWhatWeStarted() async {
    final process = _process;
    _process = null;
    if (process == null) return;
    await stopOwnedProcess(process);
  }

  /// Whether something answers at the endpoint. A leftover socket does not.
  Future<bool> _somebodyIsServing() async {
    try {
      final socket = await Socket.connect(
        InternetAddress(machine.socketPath, type: InternetAddressType.unix),
        0,
        timeout: const Duration(seconds: 1),
      );
      socket.destroy();
      return true;
    } on SocketException {
      return false;
    }
  }

  /// What is worth saying about it, or null when there is nothing.
  String? get words => switch (state) {
    TunnelState.raising => 'raising the forward…',
    TunnelState.down => problem,
    TunnelState.waitingForKey => problem,
    _ => null,
  };

  Future<void> _itEnded(int code, Future<List<String>> saying, int generation) async {
    // Everything ssh printed, in order. It says one useful sentence and several unhelpful ones,
    // and which is which depends on the failure — so all of it is kept and shown.
    final said = await saying;
    if (!_wanted || generation != _generation) return;
    final words = said.join(' ');
    state = TunnelState.down;
    if (machine.hostCard != null) {
      problem =
          words.contains('Host key verification failed') || words.contains('REMOTE HOST IDENTIFICATION HAS CHANGED')
          ? hostKeyPinRefusal
          : words.contains('Permission denied')
          ? 'The host refused this admitted account or its selected key.'
          : words.contains('forwarding failed') || words.contains('Address already in use')
          ? 'The host tunnel could not bind its fixed port or socket.'
          : 'The SSH connection stopped (exit $code).';
      await _unlocker.cancel(machine.hostCard!.name);
      if (!_wanted || generation != _generation) return;
      onChanged?.call();
      return;
    }
    problem = said.isEmpty ? 'the forward stopped, exit code $code' : words;
    onChanged?.call();
    if (said.isEmpty) return;
    try {
      final explained = await _explainSshRefusal(
        words,
        machine.host,
        _tighten,
        options: machine.loginSshOptions,
      ).timeout(_untilExplained);
      // An older refusal must not replace the result of a newer raise.
      if (!_wanted || generation != _generation || explained == null) return;
      problem = explained;
      onChanged?.call();
    } on TimeoutException {
      // The transport already said why it stopped; a stalled explanation adds nothing.
    }
  }

  void _clearTheWay() {
    try {
      final left = File(machine.socketPath);
      if (left.existsSync()) left.deleteSync();
    } on FileSystemException {
      // Something else owns it. Raising will fail and say so, which is better than deciding here.
    }
  }

  /// Makes the endpoint owner-only and says whether it now is.
  ///
  /// `ssh` already creates it that way — it binds under a `0177` umask — so the `chmod` is belt
  /// and braces. **What is returned is the state of the socket, not the exit code of the
  /// command.** A `chmod` that failed on a socket ssh had already made private is nothing to
  /// report, and a `chmod` that succeeded on one that is still group-readable would be a claim
  /// contradicted by the thing itself.
  Future<bool> _ownerOnly() async {
    try {
      await _tighten(<String>['chmod', '600', machine.socketPath]);
    } on ProcessException {
      // Judged below, by looking at the socket.
    }
    return !machine.readableByOthers;
  }

  static Future<Process> _runIt(List<String> command) => Process.start(command.first, command.sublist(1));

  static Future<ProcessResult> _runAndWait(List<String> command) => Process.run(command.first, command.sublist(1));
}

/// Every forward this interface owns.
///
/// **It owns only what it raised.** A machine described by a socket path somebody else forwarded
/// is opened exactly as it always was: nothing is raised, nothing is supervised, and nothing is
/// taken down. That path has no credential handling in it at all, which is why it must keep
/// working untouched.
class Tunnels extends ChangeNotifier {
  /// Constructor taking how to start a forward, injectable for tests.
  Tunnels({
    Future<Process> Function(List<String> command)? start,
    Future<ProcessResult> Function(List<String> command)? run,
    Duration appears = const Duration(seconds: 10),
    this.keyAvailable,
    this.portsAvailable,
    HostUnlocker? unlocker,
    this.messengerSocket,
    this.writer,
    this.configEnvironment,
  }) : _launch = start,
       _run = run ?? _runIt,
       _untilItBinds = appears,
       _unlocker = unlocker ?? CoreHostUnlocker(environment: configEnvironment);

  /// The public-key availability boundary, without guessing from remote refusals.
  final Future<bool> Function(HostCardSsh)? keyAvailable;

  /// The fixed-port availability boundary.
  final Future<void> Function(HostCardSsh)? portsAvailable;

  /// The local messenger return endpoint, if needed.
  final String? messengerSocket;

  /// The private public-file publisher.
  final HostFileWriter? writer;

  /// The platform config environment, injectable for isolated tests.
  final Map<String, String>? configEnvironment;
  final HostUnlocker _unlocker;
  final Map<String, HostCardSsh> _cards = {};
  final Map<String, Machine> _cardOwners = {};
  final _serial = _TunnelSteps();
  final Set<_TunnelRequest> _requests = {};
  final Map<Machine, int> _trials = {};
  final Map<Machine, Completer<void>> _trialsDone = {};
  final Set<Machine> _retained = {};
  bool _closing = false;

  static Machine _key(Machine machine) => machine;

  static Object _queueKey(Machine machine) => machine.hostCard?.name ?? machine;

  /// Validates a complete imported set without reserving any of its ports.
  void checkCards(Iterable<Machine> machines) {
    final cards = <HostCardSsh>[];
    for (final machine in machines) {
      final card = machine.hostCard;
      if (card == null) continue;
      card.checkAgainst(cards);
      cards.add(card);
    }
  }

  /// Replaces reservations after the previous watched tunnels have been dropped.
  ///
  /// Completes synchronously when the affected queues are idle; otherwise waits
  /// for their preceding work. Active probes keep their reservations.
  FutureOr<void> replaceCards(Iterable<Machine> machines) {
    final replacing = machines.toList();
    checkCards(replacing);
    final affected = {..._serial.keys, ...replacing.map(_queueKey)};
    return _serial.run<void>(affected, () {
      final owners = {..._cardOwners};
      final cards = {..._cards};
      for (final name in affected.whereType<String>()) {
        final owner = owners[name];
        if (owner != null && (_mine.containsKey(owner) || _retained.contains(owner) || _trials.containsKey(owner))) {
          continue;
        }
        owners.remove(name);
        cards.remove(name);
      }
      for (final machine in replacing) {
        final card = machine.hostCard;
        if (card == null) continue;
        if (owners[card.name] != null && owners[card.name] != machine) {
          throw HostFilesRefused('Host ${card.name} already has a different managed endpoint.');
        }
        card.checkAgainst(cards.values);
        cards[card.name] = card;
        owners[card.name] = machine;
      }
      for (final name in affected.whereType<String>()) {
        if (cards[name] case final card?) {
          _cards[name] = card;
          _cardOwners[name] = owners[name]!;
        } else {
          _cards.remove(name);
          _cardOwners.remove(name);
        }
      }
    });
  }

  /// Reserves every imported card's ports before any asynchronous publication.
  ///
  /// Completes synchronously when its host queues are idle; otherwise waits for
  /// their preceding work. Validation failures leave existing reservations intact.
  FutureOr<void> registerCards(Iterable<Machine> machines) {
    final registering = machines.toList();
    return _serial.run<void>(registering.map(_queueKey), () => _registerCards(registering));
  }

  void _registerCards(Iterable<Machine> machines) {
    final candidates = <String, HostCardSsh>{..._cards};
    for (final machine in machines) {
      final card = machine.hostCard;
      if (card == null) continue;
      card.checkAgainst(candidates.values);
      candidates[card.name] = card;
    }
    _cards.addAll(candidates);
    for (final machine in machines) {
      final card = machine.hostCard;
      if (card != null) _cardOwners.putIfAbsent(card.name, () => machine);
    }
  }

  final Future<Process> Function(List<String> command)? _launch;
  final Future<ProcessResult> Function(List<String> command) _run;

  static Future<ProcessResult> _runIt(List<String> command) => Process.run(command.first, command.sublist(1));

  /// How long a forward is given to bind before it is called down.
  final Duration _untilItBinds;
  final Map<Machine, Tunnel> _mine = <Machine, Tunnel>{};

  /// The forward for one machine, or null when this interface did not raise it.
  Tunnel? of(Machine machine) => _mine[_key(machine)];

  /// Whether this interface raised the way in to [machine].
  bool manages(Machine machine) => _mine.containsKey(_key(machine));

  /// Raises the forward for [machine], if it is one this interface manages.
  ///
  /// A machine that names no host is left alone and answers true: it is already reachable, by
  /// somebody else's forward, and there is nothing to do.
  Future<bool> raiseFor(Machine machine) {
    final request = _TunnelRequest(machine);
    _requests.add(request);
    return Future<bool>.sync(
      () => _serial.run<bool>([_queueKey(machine)], () async {
        try {
          if (_closing || request.canceled) return false;
          request.started = true;
          if (machine.hostCard != null) _retained.add(_key(machine));
          return await _raiseShared(machine, request);
        } finally {
          _requests.remove(request);
        }
      }),
    );
  }

  /// Holds a card master for a probe, releasing it only after its last consumer.
  HostTunnelTrial holdForTrial(Machine machine) {
    if (machine.hostCard == null) throw ArgumentError('A shared trial needs a host card.');
    final request = _TunnelRequest(machine, trial: true);
    _requests.add(request);
    final ready = Future<bool>.sync(
      () => _serial.run<bool>([_queueKey(machine)], () async {
        if (_closing || request.canceled) return false;
        request.started = true;
        _trials.update(_key(machine), (count) => count + 1, ifAbsent: () => 1);
        try {
          return await _raiseShared(machine, request);
        } finally {
          request.interrupt = null;
        }
      }),
    );
    return HostTunnelTrial._(ready, () {
      request.canceled = true;
      return Future<void>.sync(
        () => _serial.run<void>([_queueKey(machine)], () async {
          _requests.remove(request);
          if (request.started) {
            await _releaseTrial(machine);
          } else if (!_trials.containsKey(_key(machine)) &&
              !_retained.contains(_key(machine)) &&
              !_hasQueuedConsumer(machine) &&
              _mine.containsKey(_key(machine))) {
            await _finishDrop(machine);
          }
        }),
      );
    });
  }

  Future<void> _releaseTrial(Machine machine) async {
    final key = _key(machine);
    final count = _trials[key];
    if (count == null) return;
    if (count > 1) {
      _trials[key] = count - 1;
      return;
    }
    _trials.remove(key);
    final done = _trialsDone.remove(key);
    try {
      if (!_retained.contains(key) && !_hasQueuedConsumer(machine)) await _finishDrop(machine);
    } finally {
      done?.complete();
    }
  }

  bool _hasQueuedConsumer(Machine machine) =>
      _requests.any((request) => request.machine == machine && !request.started && !request.canceled);

  Future<bool> _raiseShared(Machine machine, _TunnelRequest request) async {
    if (_closing) return false;
    try {
      final card = machine.hostCard;
      if (card != null && _cardOwners[card.name] != null && _cardOwners[card.name] != machine) {
        throw HostFilesRefused('Host ${card.name} already has a different managed endpoint.');
      }
      _registerCards([machine]);
      if (card != null) _cardOwners[card.name] = machine;
    } on HostFilesRefused catch (refused) {
      final tunnel = _mine.putIfAbsent(_key(machine), () => _newTunnel(machine));
      tunnel.state = TunnelState.down;
      tunnel.problem = refused.message;
      return false;
    }
    return _raiseFor(machine, request);
  }

  Future<bool> _raiseFor(Machine machine, _TunnelRequest request) async {
    // A machine this build cannot reach is said so where it is opened, never forwarded.
    if (machine.hostCard != null && machine.whyNotReachableHere != null) return false;
    if (!machine.needsATunnel || machine.whyNotReachableHere != null || machine.relay != null) return true;
    final tunnel = _mine.putIfAbsent(_key(machine), () => _newTunnel(machine));
    request.interrupt = tunnel._cancelRaise;
    if (tunnel.state == TunnelState.up) {
      if (machine.hostCard != null && tunnel.vaultState != HostUnlockState.unlocked) await tunnel.unlockVault();
      return tunnel.state == TunnelState.up;
    }
    await tunnel.raise();
    notifyListeners();
    return tunnel.state == TunnelState.up;
  }

  Tunnel _newTunnel(Machine machine) => Tunnel(
    machine,
    start: _launch,
    run: _run,
    appears: _untilItBinds,
    onChanged: notifyListeners,
    keyAvailable: keyAvailable,
    portsAvailable: portsAvailable,
    unlocker: _unlocker,
    messengerSocket: messengerSocket,
    writer: writer,
    configEnvironment: configEnvironment,
  );

  /// Raises a forward for a trial, owned by the caller and never listed here.
  ///
  /// Kept out of [of]: a trial is not a machine being watched, and the caller takes it down.
  Future<Tunnel> trial(Machine machine) async {
    if (machine.hostCard != null) throw const HostFilesRefused('Use the shared host tunnel for card hosts.');
    final tunnel = Tunnel(machine, start: _launch, run: _run, appears: _untilItBinds);
    await tunnel.raise();
    return tunnel;
  }

  /// Raises it again after it dropped.
  ///
  /// Without being asked, because a forward that goes away is not a decision anybody made — but
  /// only for one this interface raised, and only while it is still wanted.
  Future<void> raiseAgainIfItDropped(Machine machine) {
    final request = _TunnelRequest(machine);
    _requests.add(request);
    return Future<void>.sync(
      () => _serial.run<void>([_queueKey(machine)], () async {
        try {
          final tunnel = _mine[_key(machine)];
          if (_closing ||
              request.canceled ||
              tunnel == null ||
              (tunnel.state != TunnelState.down && tunnel.state != TunnelState.waitingForKey)) {
            return;
          }
          request.started = true;
          if (machine.hostCard != null) _retained.add(_key(machine));
          await _raiseShared(machine, request);
        } finally {
          _requests.remove(request);
        }
      }),
    );
  }

  /// The line that would start a daemon on [machine].
  ///
  /// Shown to somebody before they agree to it and run unchanged afterwards, so that what was
  /// agreed to is what happens.
  ///
  /// **A unit first, the binary only if there is none.** Socket activation is supervised, comes
  /// back after a reboot and owns its socket; `setsid` is none of those and is here because the
  /// package ships no unit yet. The fallback is deliberately loud about which one ran.
  static List<String> startCommandFor(Machine machine) => machine.host.startsWith('-')
      ? throw ArgumentError('An ssh host must not start with a dash.')
      : machine.isThisComputer
      // This computer's own daemon: the same lines, in this user's login shell, with no login.
      ? <String>['sh', '-c', inTheLoginShell(startsIt)]
      : <String>[
          openSsh('ssh'),
          ...machine.loginSshOptions,
          '-n',
          if (machine.kind != 'host') ...<String>['-o', 'BatchMode=yes'],
          '-o',
          'ConnectTimeout=10',
          machine.host,
          inTheLoginShell(startsIt),
        ];

  /// What is run at the far end. Held apart so a scenario can say what was asked of the machine.
  ///
  /// `porelod.service` is a user unit the package installs and does not enable, so starting it is
  /// one call and a daemon that is restarted on failure. **Not `porelod.socket`**: there is none,
  /// and there will not be one — the JDK offers no way to adopt a listening descriptor systemd
  /// bound, which is Porelo's own note rather than a guess from here.
  ///
  /// The last line says nothing and changes nothing; it reports. A user service lives as long as
  /// that user has a session on the machine, and with no lingering the daemon goes when the last
  /// one ends. The forward this interface holds *is* such a session, so a machine being watched
  /// keeps it alive — but only for as long as it is watched, which is worth saying rather than
  /// finding out.
  ///
  /// **A unit that refuses is a failure, never a reason to run the binary behind systemd's back**,
  /// and what systemd said is what the person reads. Only with no unit loaded does it start the
  /// binary itself, and then it looks two seconds later: a daemon that ended at once is reported with
  /// its exit code and the last it wrote, rather than as started. Two seconds is enough for one that
  /// cannot read its configuration and short enough not to hold every start.
  static const String startsIt =
      'command -v porelod >/dev/null 2>&1 || { echo "no porelod is installed there" >&2; exit 127; }; '
      r'if [ "$(systemctl --user show porelod -p LoadState --value 2>/dev/null)" = loaded ]; then '
      r'said=$(systemctl --user start porelod 2>&1) || { rc=$?; '
      r'echo "systemd refused to start porelod (exit $rc): $said" >&2; exit $rc; }; '
      'echo "started by systemd"; '
      r'else out=$(mktemp) || exit 1; setsid porelod >"$out" 2>&1 </dev/null & pid=$!; sleep 2; '
      r'if kill -0 "$pid" 2>/dev/null; then rm -f "$out"; '
      'echo "started porelod itself: there is no systemd unit for it"; '
      r'else wait "$pid"; rc=$?; '
      r'echo "porelod ended as soon as it started (exit $rc): $(tail -n 5 "$out")" >&2; '
      r'rm -f "$out"; exit 1; fi; fi; '
      r'loginctl show-user "$(id -un)" -p Linger --value 2>/dev/null | grep -qx yes || '
      r'echo "(it stops when the last session there ends: loginctl enable-linger $(id -un))"';

  /// The line that would stop the daemon on [machine]: shown before anybody agrees, run unchanged
  /// after, like the start.
  static List<String> stopCommandFor(Machine machine) => machine.host.startsWith('-')
      ? throw ArgumentError('An ssh host must not start with a dash.')
      : <String>[
          openSsh('ssh'),
          ...machine.loginSshOptions,
          '-n',
          if (machine.kind != 'host') ...<String>['-o', 'BatchMode=yes'],
          '-o',
          'ConnectTimeout=10',
          machine.host,
          inTheLoginShell(stopsIt),
        ];

  /// What is run at the far end to stop it: the mirror of [startsIt].
  ///
  /// **The unit first**, stopped through systemd, which is what started it. A daemon started
  /// without a unit is stopped by its own pid, and only one of this account's. A machine where none
  /// runs says so, and that is not a failure: what was asked for is true.
  static const String stopsIt =
      r'if systemctl --user is-active --quiet porelod 2>/dev/null; then '
      r'said=$(systemctl --user stop porelod 2>&1) || { rc=$?; '
      r'echo "systemd refused to stop porelod (exit $rc): $said" >&2; exit $rc; }; '
      'echo "stopped by systemd"; '
      r'elif pids=$(pgrep -u "$(id -u)" -x porelod); then kill $pids && '
      'echo "stopped porelod itself: no systemd unit was running it"; '
      'else echo "no porelod was running there"; fi';

  /// Stops the daemon on [machine], for somebody who has been asked and said yes.
  ///
  /// **Only for a machine this interface forwards**, for the same reason as a start.
  Future<Started> stopPoreloOn(Machine machine) async {
    final why = machine.whyNotReachableHere;
    if (why != null) return Started(went: false, words: why);
    if (!machine.needsATunnel) {
      return const Started(
        went: false,
        words: 'This machine names no host to log into: its socket is forwarded by somebody else.',
      );
    }
    return _said(stopCommandFor(machine));
  }

  /// Starts a daemon on [machine], over the same transport that forwards it.
  ///
  /// **Only for a machine this interface forwards.** A socket somebody else forwarded names no
  /// host to log into, and running something on a machine described by nothing but a path is not a
  /// thing this can guess at.
  ///
  /// Running a line at the far end is further into somebody else's machine than forwarding a
  /// socket goes, and the caller asks first — which is why this takes no decision of its own.
  Future<Started> startPoreloOn(Machine machine) async {
    final why = machine.whyNotReachableHere;
    if (why != null) return Started(went: false, words: why);
    if (!machine.canBeStartedHere) {
      return const Started(
        went: false,
        words: 'This machine names no host to log into: its socket is forwarded by somebody else.',
      );
    }
    return _said(startCommandFor(machine));
  }

  /// Runs [line] and answers whether it went and what it said.
  Future<Started> _said(List<String> line) async {
    try {
      final result = await _run(line);
      // ssh's own words, whichever stream they came on: the useful sentence is on stderr when the
      // far end refused and on stdout when it did something.
      final said = <String>[
        '${result.stdout}'.trim(),
        '${result.stderr}'.trim(),
      ].where((each) => each.isNotEmpty).join(' ');
      final went = result.exitCode == 0;
      return Started(
        went: went,
        words: said.isNotEmpty
            ? said
            : went
            ? 'It ran and said nothing.'
            : 'ssh gave up, exit code ${result.exitCode}.',
      );
    } on ProcessException catch (ex) {
      return Started(went: false, words: ex.message);
    }
  }

  /// The line that asks a machine which uid its login account has.
  ///
  /// A constant, like the start line: the host travels as its own argument and nothing of the
  /// machine reaches the command run there.
  static List<String> loginUidCommandFor(Machine machine) =>
      loginUidCommandAt(machine.host, options: machine.loginSshOptions);

  /// The same line for a login known only by where it is, before there is a machine to describe.
  static List<String> loginUidCommandAt(String host, {List<String> options = const <String>[]}) => host.startsWith('-')
      ? throw ArgumentError('An ssh host must not start with a dash.')
      : <String>[
          openSsh('ssh'),
          ...options,
          '-n',
          if (options.isEmpty) ...<String>['-o', 'BatchMode=yes'],
          '-o',
          'ConnectTimeout=10',
          host,
          'id -u',
        ];

  /// The uid of the account this interface logs in as on [machine], or null when it cannot say.
  ///
  /// **Read-only, and asked without a question**. `id -u`
  /// reports the caller's own uid, needs no privilege and changes nothing, and it is only ever run
  /// as part of a trial somebody asked for. **Every failure is null**: a trial that cannot learn the
  /// uid says what it said before rather than guessing one.
  Future<int?> loginUidOn(Machine machine) async {
    if (!machine.needsATunnel) return null;
    if (machine.kind != 'host') return loginUidAt(machine.host);
    return _loginUidAt(machine.host, options: machine.loginSshOptions);
  }

  /// Why the last login [loginUidAt] tried was refused, in words a person can act on; null where it
  /// was not refused or ssh said nothing that tells.
  String? lastLoginRefusal;

  /// The uid of the account [host] logs in as, or null when it cannot say: what the wizard asks
  /// when a person knows only how they log in, and not where Porelo's socket is there.
  Future<int?> loginUidAt(String host) => _loginUidAt(host);

  Future<int?> _loginUidAt(String host, {List<String> options = const <String>[]}) async {
    lastLoginRefusal = null;
    try {
      final result = await _run(loginUidCommandAt(host, options: options));
      if (result.exitCode != 0) {
        lastLoginRefusal = await _explainSshRefusal('${result.stderr}', host, _run, options: options);
        return null;
      }
      return int.tryParse('${result.stdout}'.trim());
    } on ProcessException {
      return null;
    }
  }

  /// Explains ssh's own failure using the configuration of the same login.
  Future<String?> explainRefusal(String said, String host, {List<String> options = const <String>[]}) =>
      _explainSshRefusal(said, host, _run, options: options);

  /// Takes down the forward for one machine, if this interface raised it.
  Future<void> dropFor(Machine machine) async {
    for (final request in _requests) {
      if (request.machine == machine && !request.trial && !request.started) request.canceled = true;
    }
    final dropped = await _serial.run<_TrialDrain>([_queueKey(machine)], () async {
      final key = _key(machine);
      _retained.remove(key);
      if (_trials.containsKey(key)) {
        return _TrialDrain(_trialsDone.putIfAbsent(key, Completer<void>.new).future);
      }
      await _finishDrop(machine);
      return const _TrialDrain(null);
    });
    await dropped.done;
  }

  Future<void> _finishDrop(Machine machine) async {
    final tunnel = _mine.remove(_key(machine));
    try {
      if (tunnel != null) {
        await tunnel.drop();
        notifyListeners();
      }
    } finally {
      final card = machine.hostCard;
      if (card != null && _cardOwners[card.name] == machine) {
        _cardOwners.remove(card.name);
        _cards.remove(card.name);
      }
    }
  }

  /// Takes down everything this interface raised.
  ///
  /// Called when the window closes. **Only what is in here** — a forward somebody else raised is
  /// not in this map and is therefore untouchable, which is the whole of that criterion.
  Future<void> dropEverything() async {
    _closing = true;
    Object? failure;
    StackTrace? trace;
    Future<void> attempt(Future<void> Function() work) async {
      try {
        await work();
      } catch (error, stack) {
        failure ??= error;
        trace ??= stack;
      }
    }

    // Interrupt current I/O without changing ownership ahead of its queued cleanup.
    final interrupting = attempt(
      () async => Future.wait([
        for (final request in _requests)
          if (request.interrupt case final interrupt?) Future<void>.sync(interrupt),
      ]),
    );
    final settling = attempt(() async => Future.wait(_serial.pending));
    await _serial.run<void>(_serial.keys, () async {
      await interrupting;
      await settling;
      for (final machine in _mine.keys.toList()) {
        await attempt(() => _finishDrop(machine));
      }
      _cards.clear();
      _cardOwners.clear();
      _trials.clear();
      for (final waiting in _trialsDone.values) {
        waiting.complete();
      }
      _trialsDone.clear();
      _retained.clear();
      notifyListeners();
    });
    if (failure != null) Error.throwWithStackTrace(failure!, trace!);
  }
}

class _TunnelRequest {
  _TunnelRequest(this.machine, {this.trial = false});

  final Machine machine;
  final bool trial;
  bool started = false;
  bool canceled = false;
  Future<void> Function()? interrupt;
}

class _TrialDrain {
  const _TrialDrain(this.done);

  final Future<void>? done;
}

class _TunnelSteps {
  final keys = <Object>{};
  final pending = <Future<dynamic>>{};
  final _tails = <Object, Future<void>>{};

  FutureOr<T> run<T>(Iterable<Object> names, FutureOr<T> Function() work) {
    final affected = names.toSet();
    keys.addAll(affected);
    final preceding = <Future<void>>{for (final key in affected) ?_tails[key]};
    final completed = Completer<void>();
    for (final key in affected) {
      _tails[key] = completed.future;
    }
    void finish() {
      for (final key in affected) {
        if (identical(_tails[key], completed.future)) _tails.remove(key);
      }
      // The caller receives the error; the next step only waits for completion.
      completed.complete();
    }

    FutureOr<T> start() {
      try {
        final result = work();
        if (result is Future<T>) return result.whenComplete(finish);
        finish();
        return result;
      } catch (_) {
        finish();
        rethrow;
      }
    }

    final result = preceding.isEmpty ? start() : Future.wait(preceding).then((_) => start());
    if (result is Future<T>) {
      pending.add(result);
      unawaited(
        result.then<void>(
          (_) => pending.remove(result),
          onError: (Object error, StackTrace stack) {
            pending.remove(result);
          },
        ),
      );
    }
    return result;
  }
}

/// One temporary consumer of a shared host-card master.
class HostTunnelTrial {
  HostTunnelTrial._(this.ready, this._release);

  /// Whether the shared transport reached its host.
  final Future<bool> ready;
  final Future<void> Function() _release;
  Future<void>? _released;

  /// Releases this consumer once, preserving watched masters and other probes.
  Future<void> release() => _released ??= _release();
}

/// [said] explained for [host], naming the key ssh would use where it refused every key offered.
Future<String?> _explainSshRefusal(
  String said,
  String host,
  Future<ProcessResult> Function(List<String> command) run, {
  List<String> options = const <String>[],
}) async {
  if (options.isNotEmpty && said.contains('Host key verification failed')) return hostKeyPinRefusal;
  final needKey = said.contains('Permission denied') && said.contains('publickey');
  final config = needKey ? await _sshConfigFor(host, run, options: options) : null;
  return whySshRefused(said, host, sshConfig: config);
}

/// What `ssh -G` resolves for [host], or null where it cannot say: an empty answer would read as
/// "no key is named", which is not what a failed `ssh -G` knows.
Future<String?> _sshConfigFor(
  String host,
  Future<ProcessResult> Function(List<String> command) run, {
  List<String> options = const <String>[],
}) async {
  if (host.isEmpty || host.startsWith('-')) return null;
  try {
    final result = await run(<String>[openSsh('ssh'), ...options, '-G', host]);
    return result.exitCode == 0 ? '${result.stdout}' : null;
  } on ProcessException {
    return null;
  }
}

/// What ssh's refusal to log into [host] means for the person, from its own words on stderr; null
/// where they do not tell. Measured on the walk VM: an agent holding nine keys was cut
/// off with "Too many authentication failures" before it offered the right one.
String? whySshRefused(String said, String host, {String? sshConfig}) {
  if (said.contains('Too many authentication failures')) {
    return '$host stopped listening after the first few keys your ssh agent offered, before the one it '
        'accepts. Name that key for $host in ~/.ssh/config (IdentityFile …, and IdentitiesOnly yes), '
        'or hold fewer keys in the agent.';
  }
  if (said.contains('Permission denied') && said.contains('publickey')) {
    final key = sshConfig == null ? null : keySshWouldUse(sshConfig, host);
    return '$host accepted none of the keys your ssh agent offered. The account there needs your public '
        'key in its ~/.ssh/authorized_keys, or the account does not exist yet.'
        '${key == null ? '' : ' $key'}';
  }
  if (said.contains('Host key verification failed')) {
    return 'This computer does not know $host’s host key yet, or it changed. Log in once with ssh $host in a '
        'terminal and compare the key it shows.';
  }
  if (said.contains('Could not resolve hostname')) return '$host is not a name this computer can find.';
  if (said.contains('Connection refused') || said.contains('timed out') || said.contains('No route to host')) {
    return '$host does not answer on ssh’s port.';
  }
  return null;
}

/// The identity files ssh tries for every host, which `ssh -G` lists when nothing names one.
const Set<String> _defaultSshKeys = <String>{
  '~/.ssh/id_rsa',
  '~/.ssh/id_dsa',
  '~/.ssh/id_ecdsa',
  '~/.ssh/id_ecdsa_sk',
  '~/.ssh/id_ed25519',
  '~/.ssh/id_ed25519_sk',
  '~/.ssh/id_xmss',
};

/// The sentence naming the key `ssh -G` resolved in [sshConfig], or saying none is named when only
/// ssh's default identity files are listed.
String keySshWouldUse(String sshConfig, [String? host]) {
  for (final line in sshConfig.split('\n')) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('identityfile ')) continue;
    final file = trimmed.substring('identityfile '.length).trim().replaceFirst(RegExp(r'^.*/\.ssh/'), '~/.ssh/');
    if (file.isNotEmpty && !_defaultSshKeys.contains(file)) {
      return "It would log in with $file; that key's public half must be in the account's authorized_keys.";
    }
  }
  return host == null || host.isEmpty
      ? 'No key is named for the host in ~/.ssh/config.'
      : 'No key is named for $host in ~/.ssh/config.';
}
