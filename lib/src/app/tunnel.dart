import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart' show PoreloClient;
import 'package:porelo_host/porelo_host.dart' show HostCardSsh, HostFileWriter, HostFilesRefused;

import 'connections.dart';
import 'desk.dart';
import 'machines.dart';
import 'host_keys.dart';
import 'own_sockets.dart';
import 'fleet_backend.dart';
import 'forward_records.dart';
import 'loopback_carrier.dart';
import 'person_only_relay.dart';
import 'owned_process.dart';
import 'ssh_words.dart';

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
    this.awaitsAdmission,
    this.onTurnedAway,
    ForwardRecords? records,
    ConnectToSocket? connect,
    CarrierBudget? budget,
    this.bindLoopback,
  }) : _ownRecords = records,
       _connect = connect ?? connectToSocket,
       _launch = start ?? _runIt,
       _tighten = run ?? _runAndWait,
       _untilItBinds = appears,
       _untilExplained = explains,
       _unlocker = unlocker ?? CoreHostUnlocker(environment: configEnvironment),
       _budget = budget ?? CarrierBudget();

  /// The local public-key availability check, without agent forwarding.
  final Future<bool> Function(HostCardSsh)? keyAvailable;

  /// How the carrier binds a card's port on Windows, injectable for tests; null for the exclusive bind.
  final BindLoopback? bindLoopback;

  final ForwardRecords? _ownRecords;

  final ConnectToSocket _connect;

  // The socket file this tunnel's ssh made at the socket path, held since its process was seen listening through it:
  // only that one is removed, never a socket put there after it nor a file.
  HeldSocket? _made;

  // Read when it is used: the run's records exist only once it took charge of the window.
  ForwardRecords? get _records => _ownRecords ?? forwardRecords;

  /// The fixed-port preflight, injectable without changing endpoint selection.
  final Future<void> Function(HostCardSsh)? portsAvailable;

  /// The local messenger socket, present only while the messenger needs a return path.
  final String? messengerSocket;

  /// The private public-file publisher.
  final HostFileWriter? writer;

  /// The platform config environment, injectable for isolated tests.
  final Map<String, String>? configEnvironment;
  final HostUnlocker _unlocker;

  /// What the connections carried on Windows may spend, shared with every card of the window.
  final CarrierBudget _budget;

  /// On Windows, the card's ports the window holds itself, from the first raise until [drop].
  LoopbackCarrier? _carrier;

  /// On Linux, the card's ports the window holds itself, from the first raise until [drop], relaying only the person's
  /// own connections to the sockets its master listens on.
  PersonOnlyRelay? _relay;

  /// The vault refusal beside an SSH-reached host, independent of daemon readiness.
  String? vaultProblem;

  /// On Windows, why the last connection to one of the card's services was refused by the host, or null.
  String? serviceProblem;

  /// Core's last public vault result, separate from SSH readiness.
  HostUnlockState? vaultState;

  // The card's endpoints its master made, by path, seen listening through it once it answered: only these are removed.
  final Map<String, HeldSocket> _ownEndpoints = {};

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
  /// failed"* and *"Connection refused"* send somebody to different places. While [admitting], the words of waiting
  /// for the machine instead, and its refusal again once that wait has passed, whether or not it was asked since.
  String? get problem => admitting ? admissionWords : _problem;

  set problem(String? value) {
    _problem = value;
    _turnedAway = false;
  }

  String? _problem;

  /// Whether the machine's sshd turned this account or its key away at the last raise.
  bool get turnedAway => _turnedAway && state != TunnelState.up;
  bool _turnedAway = false;

  /// How long after Prepare the machine may take to make the person's account: its follow runs every five minutes.
  static const admissionWait = Duration(minutes: 5);

  /// The words while a machine just prepared has not yet made the person's account. It is not a refusal: the
  /// machine makes it on its first follow, which runs within five minutes of Prepare.
  static const admissionWords = 'Waiting for the machine to admit you (its first follow, up to 5 min)';

  /// Whether it was turned away while the machine may still not have made the person's account.
  bool get admitting => turnedAway && (awaitsAdmission?.call() ?? false);

  /// Whether the machine was prepared so lately that it may not yet have made the person's account.
  final bool Function()? awaitsAdmission;

  /// Told when the machine turned this account or its key away.
  final VoidCallback? onTurnedAway;

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
      ? throw ArgumentError('A machine’s ssh address must not start with a dash.')
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
          // Whatever the person's config says, ssh never removes what is at the socket path before it binds there.
          '-o', 'StreamLocalBindUnlink=no',
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
      for (final (port, socket) in card.forwards)
        if (PersonOnlyRelay.here) ...[
          '-L',
          '${card.relaySocket(machine.sshConfig, port)}:$socket',
        ] else
          for (final spec in HostCardSsh.listenSpecs(port, socket)) ...['-L', spec],
      // Whatever the card's config says, ssh never removes what is at the socket path before it binds there.
      '-o',
      'StreamLocalBindUnlink=no',
      '-L',
      '${machine.socketPath}:${card.daemonSocket}',
      if (messengerSocket != null) ...['-R', '${card.returnSocket}:$messengerSocket'],
      card.name,
    ];
  }

  /// The command that carries one connection of [role] to [machine]'s card host on Windows: an ssh of its own through
  /// the card's config, running the host's relay for that role alone. The host maps the role to its fixed socket and
  /// refuses any other word, a path, an option or a second argument.
  static List<String> carryCommand(Machine machine, CarriedRole role) => [
    openSsh('ssh'),
    '-F',
    machine.sshConfig,
    '-T',
    '--',
    machine.hostCard!.name,
    inTheLoginShell('porelo service connect ${role.word}'),
  ];

  /// Each port of [card] with the role it carries to.
  static Map<int, CarriedRole> _rolesOf(HostCardSsh card) => {
    ?card.webPort: CarriedRole.forgeWeb,
    ?card.gitPort: CarriedRole.forgeGit,
    ?card.matrixPort: CarriedRole.homeserver,
  };

  /// Raises it, and waits until the socket is there or the transport says why not.
  Future<void> raise() async {
    if (machine.hostCard != null) return _raiseCard();
    final generation = ++_generation;
    _wanted = true;
    if (state != TunnelState.down && state != TunnelState.waitingForKey) problem = null;
    state = TunnelState.raising;

    // Our own previous process first. A re-raise while the old `ssh` is still alive would
    // otherwise meet its socket below and refuse it as somebody else's.
    await _stopWhatWeStarted();
    if (generation != _generation) return;
    _removeWhatWeMade();

    // **A socket that answers belongs to somebody.** It may be another program of this user that
    // happens to sit at that path, and taking its endpoint away to put ours there would break it
    // silently. Refused instead, and said. Told apart by connecting, exactly as
    // [OneInstance.take] tells its own leftover from a running interface.
    var found = await probeSocket(machine.socketPath, _connect);
    if (generation != _generation) return;
    // Unless it is the very forward a run of this interface left behind when it ended without asking.
    if (found != SocketProbe.nobody &&
        (_records?.endLeftovers((line) => forwardsSocket(line, machine.socketPath)) ?? false)) {
      // A monotonic deadline, each probe capped by what is left of it: a probe that hangs cannot stretch the wait.
      final waited = Stopwatch()..start();
      // The last probe may have only milliseconds left: one that ran out of them does not unsay an answer seen.
      var answered = found == SocketProbe.answers;
      while (found != SocketProbe.nobody && waited.elapsed < leftoverEnds) {
        found = await probeSocket(machine.socketPath, _connect, within: _leftOf(waited, const Duration(seconds: 1)));
        if (found == SocketProbe.answers) answered = true;
        if (found != SocketProbe.nobody) {
          await Future<void>.delayed(_leftOf(waited, const Duration(milliseconds: 100)));
        }
      }
      if (generation != _generation) return;
      if (found == SocketProbe.unknown && answered) found = SocketProbe.answers;
    }
    if (found != SocketProbe.nobody) {
      state = TunnelState.down;
      problem = found == SocketProbe.answers
          ? 'something is already serving ${machine.socketPath}, and it was left alone'
          : 'whether something serves ${machine.socketPath} could not be told, and it was left alone';
      return;
    }

    // Only where nobody else can put a file is what is found there later told apart; anywhere else it is not raised.
    if (Platform.isLinux && !inOwnDirectory(machine.socketPath)) {
      state = TunnelState.down;
      problem = 'the folder of ${machine.socketPath} is not yours alone, so no endpoint is made there';
      return;
    }

    // ssh refuses to bind a path that already exists. A socket left by a run that died is a leftover nobody holds, and
    // the alternative is a machine that can never be opened again without somebody knowing to delete a file they have
    // never heard of. Anything else there - a file, a socket somebody still holds - is not this window's to remove.
    if (FileSystemEntity.typeSync(machine.socketPath, followLinks: false) != FileSystemEntityType.notFound) {
      await removeLeftover(machine.socketPath, connect: _connect);
      if (generation != _generation) return;
      if (FileSystemEntity.typeSync(machine.socketPath, followLinks: false) != FileSystemEntityType.notFound) {
        state = TunnelState.down;
        problem = 'something that is no leftover of this window is at ${machine.socketPath}, and it was left alone';
        return;
      }
    }

    final stopped = Completer<void>();
    try {
      final line = command;
      final process = await _launch(line);
      if (generation != _generation) {
        process.kill();
        return;
      }
      _process = process;
      raised++;
      // Recorded so that a run ended without asking leaves a forward the next one can prove was its own.
      final records = _records?..record(process.pid, line);
      // Collected as one future rather than read line by line, because **the process can exit
      // before a subscription has delivered anything**: `ssh` prints one line and dies, and the
      // first version of this reported "exit code 255" with the sentence still in the pipe.
      final saying = process.stderr.transform(utf8.decoder).transform(const LineSplitter()).toList();
      unawaited(
        process.exitCode.then((code) async {
          records?.forget(process.pid);
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
      // Ours only once its process is seen listening there: a socket somebody else put at the path is waited past.
      if (_process case final process?
          when _made == null &&
              FileSystemEntity.typeSync(machine.socketPath, followLinks: false) ==
                  FileSystemEntityType.unixDomainSock) {
        _made = madeBy(process.pid, machine.socketPath);
      }
      if (_made != null) {
        final ownerOnly = await _ownerOnly();
        if (generation != _generation) return;
        if (!ownerOnly) {
          // The one property of the transport that can be checked from here, and it is the one
          // the requirement names. A forward anybody on the machine can read is not the thing
          // that was asked for, so it is taken down rather than reported as working.
          await _stopWhatWeStarted();
          _removeWhatWeMade();
          state = TunnelState.down;
          problem = 'the endpoint could not be made readable by nobody but you';
          return;
        }
        problem = null;
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
    problem = 'The connection was not ready within ${_untilItBinds.inSeconds} seconds.';
  }

  Future<void> _raiseCard() async {
    final generation = ++_generation;
    final card = machine.hostCard!;
    final windows = desk.isWindows;
    _wanted = true;
    if (state != TunnelState.down && state != TunnelState.waitingForKey) problem = null;
    state = TunnelState.raising;
    // Nothing is carried while it is not up: what was carried before is closed, and what comes is closed at once.
    _carrier?.stopCarrying();
    serviceProblem = null;
    vaultProblem = null;
    vaultState = null;
    try {
      await _stopWhatWeStarted();
      await _unlocker.cancel(card.name);
      if (generation != _generation) return;
      _clearOwnedCardEndpoints();
      if (windows) return await _raiseOnWindows(generation, card);
      HostCardSsh.checkLocalSocket(machine.socketPath);
      HostCardSsh.checkLocalSocket(card.controlSocket(machine.sshConfig));
      if (messengerSocket != null) HostCardSsh.checkMessengerSocket(messengerSocket!);
      await _endOrphanedMaster(card);
      if (generation != _generation) return;
      for (final endpoint in _cardEndpoints(card)) {
        // A leftover nobody holds goes; anything else stays and is said.
        if (FileSystemEntity.typeSync(endpoint, followLinks: false) != FileSystemEntityType.notFound) {
          await removeLeftover(endpoint, connect: _connect);
        }
        if (generation != _generation) return;
        if (FileSystemEntity.typeSync(endpoint, followLinks: false) != FileSystemEntityType.notFound) {
          state = TunnelState.down;
          problem = 'Machine ${card.name} cannot connect: an endpoint already exists and was left alone.';
          return;
        }
      }
      if (!await _holdPorts(card, generation)) return;
      final available = await (keyAvailable?.call(card) ?? _agentHasKey(card));
      if (generation != _generation) return;
      if (!available) {
        state = TunnelState.waitingForKey;
        problem = 'Waiting for your key. Unlock KeePassXC with your selected key available.';
        return;
      }
      await card.publish(machine.sshConfig, writer: writer, environment: configEnvironment, windows: false);
      if (generation != _generation) return;
      // Only where nobody else can put a file is what is found there later told apart; anywhere else nothing is launched.
      for (final endpoint in _cardEndpoints(card)) {
        if (Platform.isLinux && !inOwnDirectory(endpoint)) {
          state = TunnelState.down;
          problem = 'Machine ${card.name} cannot connect: the folder of $endpoint is not yours alone.';
          return;
        }
      }
      final process = await _launch(command);
      if (generation != _generation) {
        await stopOwnedProcess(process);
        return;
      }
      _process = process;
      _mastersHere[card.controlSocket(machine.sshConfig)] = this;
      process.exitCode.then((_) {
        if (identical(_mastersHere[card.controlSocket(machine.sshConfig)], this) &&
            (_process == null || identical(_process, process))) {
          _mastersHere.remove(card.controlSocket(machine.sshConfig));
        }
      }).ignore();
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
          // Its endpoints, as bound by this master, once it answers: only these are ever removed by this tunnel.
          for (final endpoint in _cardEndpoints(card)) {
            if (FileSystemEntity.typeSync(endpoint, followLinks: false) != FileSystemEntityType.unixDomainSock) {
              continue;
            }
            if (madeBy(process.pid, endpoint) case final made?) _ownEndpoints[endpoint] = made;
          }
          problem = null;
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
      problem = 'The SSH connection did not answer within ${_untilItBinds.inSeconds} seconds.';
    } on TimeoutException {
      if (generation != _generation) return;
      state = TunnelState.down;
      problem = 'Checking the machine connection timed out.';
    } on HostFilesRefused catch (refused) {
      if (generation != _generation) return;
      state = TunnelState.down;
      problem = refused.message;
    } on ProcessException {
      if (generation != _generation) return;
      state = TunnelState.down;
      problem = 'The command needed to connect to this machine is unavailable.';
    } on FileSystemException {
      if (generation != _generation) return;
      state = TunnelState.down;
      problem = 'The files needed to connect to this machine could not be prepared or cleaned up.';
    } finally {
      if (generation == _generation && state == TunnelState.down) {
        await _stopWhatWeStarted();
        _clearOwnedCardEndpoints();
      }
    }
  }

  /// The card's endpoints its master makes here: the daemon's, the control socket and, where the window relays the
  /// card's ports, the socket of each.
  List<String> _cardEndpoints(HostCardSsh card) => [
    machine.socketPath,
    card.controlSocket(machine.sshConfig),
    if (PersonOnlyRelay.here)
      for (final (port, _) in card.forwards) card.relaySocket(machine.sshConfig, port),
  ];

  /// Holds the card's ports where the window relays them, once from the first raise until [drop]; false, with the
  /// problem said, where one is held by somebody else. Elsewhere only checks that they are free.
  Future<bool> _holdPorts(HostCardSsh card, int generation) async {
    if (!PersonOnlyRelay.here) {
      await (portsAvailable?.call(card) ?? card.checkPortsAvailable());
      return true;
    }
    if (_relay != null) return true;
    // Asked first for its words: who holds a port, where it can say.
    await (portsAvailable?.call(card) ?? card.checkPortsAvailable());
    final relay = _relay = PersonOnlyRelay(
      {for (final (port, _) in card.forwards) port: card.relaySocket(machine.sshConfig, port)},
      loopbacks: [InternetAddress.loopbackIPv4, if (HostCardSsh.ipv6Loopback) InternetAddress.loopbackIPv6],
    );
    // Only a socket its master was seen to make, while the card is up: anything else is closed at once.
    relay.relaysTo = (socket) => state == TunnelState.up && _ownEndpoints.containsKey(socket);
    try {
      await relay.hold();
    } on RelayRefused catch (refused) {
      if (identical(_relay, relay)) _relay = null;
      if (generation != _generation) return false;
      state = TunnelState.down;
      problem = 'Machine ${card.name} cannot connect: $refused.';
      return false;
    }
    return generation == _generation;
  }

  /// On Windows, whose OpenSSH holds no master and binds a `-L` port it cannot prove its own, the window holds the
  /// card's ports itself, on both families, from the first raise until [drop], through every reconnect; each
  /// connection goes over an ssh of its own. Up only once the daemon answered through the relay.
  Future<void> _raiseOnWindows(int generation, HostCardSsh card) async {
    var carrier = _carrier;
    if (carrier == null) {
      late final LoopbackCarrier made;
      made = carrier = LoopbackCarrier(
        _rolesOf(card),
        carry: (role) => _launch(carryCommand(machine, role)),
        budget: _budget,
        bind: bindLoopback,
        onExit: _carriedExited,
        onLost: (port, address) => _carrierLost(made, port, address),
      );
      _carrier = carrier;
      try {
        await carrier.hold();
      } on CarrierRefused catch (refused) {
        if (identical(_carrier, carrier)) _carrier = null;
        if (generation != _generation) return;
        state = TunnelState.down;
        problem = 'Machine ${card.name} cannot connect: ${refused.message}';
        return;
      }
      if (generation != _generation || !identical(_carrier, carrier)) return;
    }
    final available = await (keyAvailable?.call(card) ?? _agentHasKey(card));
    if (generation != _generation) return;
    if (!available) {
      state = TunnelState.waitingForKey;
      problem = 'Waiting for your key. Unlock KeePassXC with your selected key available.';
      return;
    }
    await card.publish(machine.sshConfig, writer: writer, environment: configEnvironment, windows: true);
    if (generation != _generation) return;
    final refused = await _askTheDaemon(generation);
    if (generation != _generation || state != TunnelState.raising) return;
    if (refused != null) {
      state = TunnelState.down;
      problem = refused.words;
      _turnedAway = refused.turnedAway;
      if (_turnedAway) onTurnedAway?.call();
      return;
    }
    carrier.carrying = true;
    problem = null;
    state = TunnelState.up;
    await unlockVault();
  }

  /// The system closed one of [carrier]'s listeners, so its port is anyone's: the card is down, nothing of it is held
  /// any more, and the next raise binds every port anew, refusing where another program took one meanwhile.
  void _carrierLost(LoopbackCarrier carrier, int port, InternetAddress address) {
    if (!identical(_carrier, carrier)) return;
    _carrier = null;
    // A raise under way stops where it is: what it would set is no longer true.
    _generation++;
    state = TunnelState.down;
    problem =
        'Machine ${machine.hostCard!.name} lost hold of its port $port on ${address.address}, so nothing of it is held '
        'any more. Connect again.';
    onChanged?.call();
  }

  /// Says why the host's relay ended a carried connection, by Core's exits of `porelo service connect`: 64, a role the
  /// host's porelo does not know; 69, a service the host serves none of, whose socket refuses, or whose socket it
  /// refused; 70, a connection that failed while carried. Any other end, such as the client leaving, says nothing.
  void _carriedExited(CarriedRole role, int code) {
    final service = switch (role) {
      CarriedRole.forgeWeb => "forge's web interface",
      CarriedRole.forgeGit => "forge's Git service",
      CarriedRole.homeserver => 'homeserver',
    };
    final name = machine.hostCard!.name;
    final said = switch (code) {
      64 =>
        'Machine $name does not offer its $service: the porelo there is older than this window and does not know it.',
      69 =>
        'Machine $name serves no $service, or it does not answer there: it is down or still starting, or the host '
            'refused its socket.',
      70 => "Machine $name's $service broke off a connection while carrying it.",
      _ => null,
    };
    if (said == null || said == serviceProblem) return;
    serviceProblem = said;
    onChanged?.call();
  }

  /// Asks the daemon what it is through the relay's own ssh, the card's config pinning its host key and key: null once
  /// it answered as a Porelo daemon this window speaks to, else why not. Nothing ssh says on its own is believed.
  Future<({String words, bool turnedAway})?> _askTheDaemon(int generation) async {
    final relay = machine.relay?.command;
    if (relay == null) return (words: 'This computer has no way to reach the machine\'s daemon.', turnedAway: false);
    // The probe's ssh uses the person's key like a carried connection's, so it counts under the same cap of all.
    if (!_budget.take()) {
      return (
        words:
            'This computer already holds as many connections to machines as it allows; Connect again once some '
            'have ended.',
        turnedAway: false,
      );
    }
    final Process process;
    try {
      process = await _launch(relay);
    } on Object {
      _budget.giveBack();
      rethrow;
    }
    // Its place is free only once it exited.
    unawaited(process.exitCode.then<void>((_) => _budget.giveBack(), onError: (Object _) => _budget.giveBack()));
    if (generation != _generation) {
      await stopOwnedProcess(process);
      return null;
    }
    _process = process;
    raised++;
    final said = <int>[];
    // Bounded, as a relay may print without end.
    final saying = process.stderr.forEach((bytes) {
      said.addAll(bytes);
      if (said.length > 8192) said.removeRange(0, said.length - 8192);
    });
    // A relay gone before it was asked fails here, unawaited otherwise.
    unawaited(process.stdin.done.then<void>((_) {}, onError: (Object _) {}));
    try {
      process.stdin.add(utf8.encode('{"method":"org.varlink.service.GetInfo","parameters":{}}\x00'));
      final frame = await _firstFrame(process.stdout).timeout(_untilItBinds);
      if (_isPoreloInfo(frame)) return null;
      return (
        words: 'Machine ${machine.hostCard!.name} answered, but not as a Porelo daemon this window speaks to.',
        turnedAway: false,
      );
    } on Object {
      if (generation != _generation) return null;
      final code = await process.exitCode.timeout(const Duration(seconds: 1), onTimeout: () => -1);
      await saying.timeout(const Duration(seconds: 1), onTimeout: () {}).catchError((Object _) {});
      final lines = const LineSplitter().convert(utf8.decode(said, allowMalformed: true));
      final words = lines.join(' ');
      return (
        words: code == -1 && lines.isEmpty
            ? 'The machine\'s daemon did not answer within ${_untilItBinds.inSeconds} seconds.'
            : _cardStopped(lines, code),
        turnedAway: words.contains('Permission denied'),
      );
    } finally {
      if (identical(_process, process)) await _stopWhatWeStarted();
    }
  }

  /// The first NUL-ended frame on [stdout], decoded; a frame past 64 KiB, or output that ends first, throws.
  static Future<Object?> _firstFrame(Stream<List<int>> stdout) async {
    final bytes = <int>[];
    await for (final chunk in stdout) {
      final end = chunk.indexOf(0);
      bytes.addAll(end < 0 ? chunk : chunk.take(end));
      if (bytes.length > 64 * 1024) throw const FormatException('The answer passed 64 KiB without ending.');
      if (end >= 0) return jsonDecode(utf8.decode(bytes));
    }
    throw const FormatException('The relay ended before an answer.');
  }

  /// Whether [frame] is a complete, final GetInfo answer of a daemon serving an interface this window speaks: no
  /// error, not one of several, and every field GetInfo promises.
  static bool _isPoreloInfo(Object? frame) {
    if (frame is! Map<String, dynamic> || frame.containsKey('error')) return false;
    if (frame['continues'] != null && frame['continues'] != false) return false;
    final info = frame['parameters'];
    if (info is! Map<String, dynamic>) return false;
    if (info['product'] is! String || info['version'] is! String || info['vendor'] is! String) return false;
    final interfaces = info['interfaces'];
    return interfaces is List &&
        interfaces.every((each) => each is String) &&
        interfaces.any(PoreloClient.supported.contains);
  }

  /// Why a card's ssh stopped, from its own words, for the person.
  static String _cardStopped(List<String> said, int code) {
    final words = said.join(' ');
    return words.contains('Host key verification failed') || words.contains('REMOTE HOST IDENTIFICATION HAS CHANGED')
        ? hostKeyPinRefusal
        : words.contains('Permission denied')
        ? 'The machine refused this account or its selected key. A machine makes your account only after it has read '
              'the organization, up to five minutes after your project is on it, and a machine still waiting for a '
              'token has made none yet.'
        : words.contains('forwarding failed') || words.contains('Address already in use')
        ? 'The machine connection could not use its required local port or socket.'
        : switch (sshLastWords(said)) {
            final reason? => 'The SSH connection stopped: $reason',
            null => 'The SSH connection stopped (exit $code).',
          };
  }

  /// Ends a master of this card that no tunnel of this program started, and the endpoints it left: its control socket
  /// lies where only this desktop's card puts one. One whose configuration is gone is no tunnel anybody can use or
  /// raise again; one whose configuration names this card's own login was left by an earlier run of this interface for
  /// the same person, such as before a restart. A master whose configuration names another login is another instance's
  /// live tunnel and is left alone, as is one a tunnel here runs.
  Future<void> _endOrphanedMaster(HostCardSsh card) async {
    final control = card.controlSocket(machine.sshConfig);
    if (FileSystemEntity.typeSync(control, followLinks: false) != FileSystemEntityType.unixDomainSock) return;
    if (_mastersHere.containsKey(control)) return;
    if (FileSystemEntity.typeSync(machine.sshConfig, followLinks: false) != FileSystemEntityType.notFound &&
        !_namesLogin(machine.sshConfig, card.login)) {
      return;
    }
    await _tighten([openSsh('ssh'), '-F', '/dev/null', '-o', 'ControlPath=$control', '-O', 'exit', card.name])
        .timeout(_untilExplained);
    // The master ends after it answered; its endpoints stop answering within a moment.
    for (var wait = 0; wait < 20 && await probeSocket(control, connectToSocket) != SocketProbe.nobody; wait++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    for (final endpoint in _cardEndpoints(card)) {
      await removeLeftover(endpoint);
    }
  }

  /// Whether the card configuration at [config] names [login] as its `User`.
  static bool _namesLogin(String config, String login) {
    try {
      return File(config).readAsLinesSync().any((line) => line.trim() == 'User $login');
    } on FileSystemException {
      return false;
    }
  }

  /// Retries Core unlock on the existing master without changing fixed endpoints.
  Future<void> unlockVault() async {
    if (machine.hostCard == null || state != TunnelState.up) return;
    final generation = _generation;
    final unlocked = await _unlocker.unlock(machine.hostCard!, machine.sshConfig);
    if (generation != _generation || state != TunnelState.up) return;
    vaultState = unlocked.state;
    vaultProblem = switch (unlocked.state) {
      HostUnlockState.unlocked => null,
      HostUnlockState.waitingForKey => 'Waiting for your key. Unlock KeePassXC to open the machine vault.',
      _ => unlocked.words ?? 'Core could not unlock the machine vault.',
    };
  }

  Future<void> _cancelRaise() async {
    _generation++;
    _wanted = false;
    state = TunnelState.down;
    _carrier?.stopCarrying();
    if (machine.hostCard != null) await _unlocker.cancel(machine.hostCard!.name);
  }

  Future<bool> _agentHasKey(HostCardSsh card) async {
    final result = await _tighten([openSsh('ssh-add'), '-L']).timeout(_untilExplained);
    if (result.exitCode != 0) return false;
    return '${result.stdout}'.split('\n').any((line) => line.split(' ').take(2).join(' ') == card.publicKey);
  }

  /// Removes the card's endpoints its master made, each only while it is still that socket.
  void _clearOwnedCardEndpoints() {
    for (final MapEntry(key: endpoint, value: made) in _ownEndpoints.entries) {
      removeSocketIfStill(endpoint, made);
      made.release();
    }
    _ownEndpoints.clear();
  }

  /// Removes the socket this tunnel's ssh made at the socket path, only while it is still that socket.
  void _removeWhatWeMade() {
    if (_made case final made?) {
      removeSocketIfStill(machine.socketPath, made);
      made.release();
    }
    _made = null;
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
    final carrier = _carrier;
    _carrier = null;
    await carrier?.release();
    final relay = _relay;
    _relay = null;
    await relay?.close();
    if (machine.hostCard == null) {
      // Only an endpoint this tunnel's ssh made: one refused as somebody else's stays where it is.
      _removeWhatWeMade();
    } else {
      _clearOwnedCardEndpoints();
    }
    state = TunnelState.idle;
  }

  /// Takes down the process this tunnel started, if it is still there.
  Future<void> _stopWhatWeStarted() async {
    final process = _process;
    _process = null;
    _mastersHere.removeWhere((_, tunnel) => identical(tunnel, this));
    if (process == null) return;
    await stopOwnedProcess(process);
  }

  // The card masters a tunnel of this program started and still runs, by control socket: a master on a control socket
  // not among them was left by an earlier run of this interface, or is another instance's.
  static final Map<String, Tunnel> _mastersHere = {};

  /// How long a forward left behind is given to stop answering once it was asked to end.
  static const leftoverEnds = Duration(seconds: 2);

  static Duration _leftOf(Stopwatch waited, Duration most) {
    final left = leftoverEnds - waited.elapsed;
    if (left <= Duration.zero) return const Duration(milliseconds: 1);
    return left < most ? left : most;
  }

  /// What is worth saying about it, or null when there is nothing.
  String? get words => switch (state) {
    TunnelState.raising => problem ?? 'Connecting…',
    TunnelState.down => problem,
    TunnelState.waitingForKey => problem,
    // Up, and the host vault not opened from here: why is said, since every project on it waits.
    TunnelState.up => vaultProblem ?? serviceProblem,
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
      problem = _cardStopped(said, code);
      _turnedAway = words.contains('Permission denied');
      if (_turnedAway) onTurnedAway?.call();
      await _unlocker.cancel(machine.hostCard!.name);
      if (!_wanted || generation != _generation) return;
      onChanged?.call();
      return;
    }
    problem = said.isEmpty ? 'The SSH connection stopped (exit $code).' : words;
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
    CarrierBudget? carrierBudget,
    this.carrierBind,
  }) : _budget = carrierBudget ?? CarrierBudget(),
       _launch = start,
       _run = run ?? _runIt,
       _untilItBinds = appears,
       _unlocker = unlocker ?? CoreHostUnlocker(environment: configEnvironment);

  /// The public-key availability boundary, without guessing from remote refusals.
  final Future<bool> Function(HostCardSsh)? keyAvailable;

  /// The fixed-port availability boundary.
  final Future<void> Function(HostCardSsh)? portsAvailable;

  /// The local messenger return endpoint, if needed.
  final String? messengerSocket;

  /// What every card's carried connections may spend together, on Windows.
  final CarrierBudget _budget;

  /// How a carrier binds a card's port on Windows, injectable for tests; null for the exclusive bind.
  final BindLoopback? carrierBind;

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
  /// for their preceding work, then reads [machines]. Registered owners keep
  /// their reservations until an explicit drop, including before their first raise.
  /// Hosts added while waiting also wait for their preceding queue steps.
  FutureOr<void> replaceCards(Iterable<Machine> machines) {
    final affected = {..._serial.keys, ...machines.map(_queueKey)};
    final replaced = _serial.run<bool>(affected, () {
      final replacing = machines.toList();
      if (!affected.containsAll(replacing.map(_queueKey))) return false;
      checkCards(replacing);
      for (final machine in replacing) {
        final card = machine.hostCard;
        if (card == null) continue;
        if (_cardOwners[card.name] != null && _cardOwners[card.name] != machine) {
          throw HostFilesRefused('Machine ${card.name} already has a different managed endpoint.');
        }
      }
      _registerCards(replacing);
      return true;
    });
    // Release this step before acquiring new queues to avoid cyclic waits.
    if (replaced is Future<bool>) {
      return replaced.then<void>((done) {
        if (!done) return replaceCards(machines);
      });
    }
    if (!replaced) return replaceCards(machines);
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
          _retained.add(_key(machine));
          return await _raiseShared(machine, request);
        } finally {
          _requests.remove(request);
        }
      }),
    );
  }

  /// Holds a card master for a probe, releasing it only after its last consumer.
  HostTunnelTrial holdForTrial(Machine machine) {
    if (machine.hostCard == null) throw ArgumentError('A shared trial needs a machine card.');
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
      if (!_retained.contains(key)) await _finishDrop(machine);
    } finally {
      done?.complete();
    }
  }

  Future<bool> _raiseShared(Machine machine, _TunnelRequest request) async {
    if (_closing) return false;
    try {
      final card = machine.hostCard;
      if (card != null && _cardOwners[card.name] != null && _cardOwners[card.name] != machine) {
        throw HostFilesRefused('Machine ${card.name} already has a different managed endpoint.');
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
    // A card's relay carries only the daemon; its services, the return path and Core's unlock still need the tunnel.
    if (!machine.needsATunnel ||
        machine.whyNotReachableHere != null ||
        (machine.relay != null && machine.hostCard == null)) {
      return true;
    }
    final tunnel = _mine.putIfAbsent(_key(machine), () => _newTunnel(machine));
    request.interrupt = tunnel._cancelRaise;
    if (tunnel.state == TunnelState.up && !request.asksAgain) {
      if (machine.hostCard != null && tunnel.vaultState != HostUnlockState.unlocked) await tunnel.unlockVault();
      return tunnel.state == TunnelState.up;
    }
    await tunnel.raise();
    notifyListeners();
    return tunnel.state == TunnelState.up;
  }

  /// Until when each machine just prepared may still turn the person away: it makes their account only on its first
  /// follow.
  final Map<String, DateTime> _admitting = {};

  /// Waits for [host] to admit the person until [by]: until then, its turning them away is waiting, not a refusal.
  void awaitAdmission(String host, {required DateTime by}) {
    _admitting[host] = by;
    _admissionEnds.remove(host)?.cancel();
    notifyListeners();
  }

  /// [host] turned the person away during its wait: when the wait ends, what it says turns into the refusal by
  /// itself, without another raise to say it, so whoever shows it hears then.
  void _turnedAwayWhileAdmitting(String host) {
    final by = _admitting[host];
    if (by == null || _admissionEnds.containsKey(host)) return;
    final left = by.difference(DateTime.now());
    if (left.isNegative) return;
    _admissionEnds[host] = Timer(left, () {
      _admissionEnds.remove(host);
      notifyListeners();
    });
  }

  final Map<String, Timer> _admissionEnds = {};

  @override
  void dispose() {
    for (final ends in _admissionEnds.values) {
      ends.cancel();
    }
    super.dispose();
  }

  /// Whether [host] was prepared so lately that it may not yet have made the person's account.
  bool awaitsAdmission(String host) => _admitting[host]?.isAfter(DateTime.now()) ?? false;

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
    budget: _budget,
    bindLoopback: carrierBind,
    configEnvironment: configEnvironment,
    awaitsAdmission: () => machine.hostCard != null && awaitsAdmission(machine.hostCard!.name),
    onTurnedAway: () {
      if (machine.hostCard case final card?) _turnedAwayWhileAdmitting(card.name);
    },
  );

  /// Raises a forward for a trial, owned by the caller and never listed here.
  ///
  /// Kept out of [of]: a trial is not a machine being watched, and the caller takes it down.
  Future<Tunnel> trial(Machine machine) async {
    if (machine.hostCard != null) {
      throw const HostFilesRefused('Use the shared machine connection for machines with a card.');
    }
    final tunnel = Tunnel(machine, start: _launch, run: _run, appears: _untilItBinds);
    await tunnel.raise();
    return tunnel;
  }

  /// Raises it again after it dropped.
  ///
  /// Without being asked, because a forward that goes away is not a decision anybody made — but
  /// only for one this interface raised, and only while it is still wanted.
  /// Only a machine [raiseFor] holds and no [dropFor] has let go, judged when its own step starts.
  Future<void> raiseAgainIfItDropped(Machine machine) {
    final request = _TunnelRequest(machine);
    _requests.add(request);
    return Future<void>.sync(
      () => _serial.run<void>([_queueKey(machine)], () async {
        try {
          final tunnel = _mine[_key(machine)];
          // A card carried on Windows has no ssh of its own whose end says it dropped: its daemon is asked again.
          final asksAgain = tunnel?._carrier != null && tunnel?.state == TunnelState.up;
          if (_closing ||
              request.canceled ||
              !_retained.contains(_key(machine)) ||
              (tunnel != null &&
                  !asksAgain &&
                  tunnel.state != TunnelState.down &&
                  tunnel.state != TunnelState.waitingForKey)) {
            return;
          }
          request
            ..started = true
            ..asksAgain = asksAgain;
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
      ? throw ArgumentError('A machine’s ssh address must not start with a dash.')
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
      ? throw ArgumentError('A machine’s ssh address must not start with a dash.')
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
        words: 'This machine has no SSH login configured; its connection is managed elsewhere.',
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
        words: 'This machine has no SSH login configured; its connection is managed elsewhere.',
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
      ? throw ArgumentError('A machine’s ssh address must not start with a dash.')
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

  /// Re-adds the forge's web forward of [machine]'s card on its live ssh master, leaving the master and every session
  /// over it - terminals, the daemon's link, the other forwards - as they are. Answers why it could not, or null.
  Future<String?> forwardTheForgeAnew(Machine machine) async {
    final card = machine.hostCard;
    final forward = card?.forwards.where((each) => each.$1 == card.webPort).firstOrNull;
    if (card == null || forward == null) return 'This machine has no forge to forward.';
    if (of(machine)?.state != TunnelState.up) return 'The connection to ${card.name} is not up.';
    // On Windows the window holds the forge's port itself and each connection opens its own ssh: nothing to raise anew.
    if (of(machine)?._carrier != null) return null;
    // On Linux the window holds it too, and relays each connection to the master's socket: nothing to raise anew.
    if (of(machine)?._relay != null) return null;
    final spec = [
      for (final listen in HostCardSsh.listenSpecs(forward.$1, forward.$2)) ...['-L', listen],
      card.name,
    ];
    // A forward that is gone already cannot be cancelled, which is no reason not to add it again.
    await _run([openSsh('ssh'), '-F', machine.sshConfig, '-O', 'cancel', ...spec]);
    final added = await _run([openSsh('ssh'), '-F', machine.sshConfig, '-O', 'forward', ...spec]);
    if (added.exitCode == 0) return null;
    // A master raises each listen on its own: one family may be up while another program took the port on the other.
    // Half a forward is none, or a browser trying that other family first hands that program the person's sign-in.
    await _run([openSsh('ssh'), '-F', machine.sshConfig, '-O', 'cancel', ...spec]);
    final said = '${added.stderr}'.trim();
    return said.isEmpty ? 'ssh did not add the forward again.' : said;
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

  /// Takes down the forward for one card machine and then, in its host's queue, removes the files published for its
  /// card, unless a raise queued meanwhile took the card again: a raise never loses the files it published.
  Future<void> dropAndUnpublish(Machine machine) async {
    await dropFor(machine);
    final card = machine.hostCard;
    if (card == null) return;
    await _serial.run<void>([_queueKey(machine)], () async {
      if (_cardOwners.containsKey(card.name) || _mine.containsKey(_key(machine))) return;
      await card.unpublish(machine.sshConfig, environment: configEnvironment, windows: desk.isWindows);
    });
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
      // Together, so each gets its end and its SIGKILL within the window's bound however many ignore the end.
      await Future.wait([for (final machine in _mine.keys.toList()) attempt(() => _finishDrop(machine))]);
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

  /// Whether a tunnel that is up is raised again all the same, to ask its daemon anew.
  bool asksAgain = false;
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
    return 'This computer does not know $host’s SSH host key yet, or it changed. Log in once with ssh $host in a '
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
      ? 'No key is named for the machine in ~/.ssh/config.'
      : 'No key is named for $host in ~/.ssh/config.';
}

/// What a connection to a unix socket found.
enum SocketProbe {
  /// Something accepted it.
  answers,

  /// Nothing listens there: the connection was refused, or there is no such path.
  nobody,

  /// It could not be told: no answer in time, or a failure that proves nothing about the endpoint (such as too many
  /// open files here). Counted as answering, so the endpoint is never removed on it.
  unknown,
}

/// Starts a connection to the unix socket at [path]. Injectable, so a test can make a probe fail or hang.
typedef ConnectToSocket = Future<ConnectionTask<Socket>> Function(String path);

/// Starts a real connection.
Future<ConnectionTask<Socket>> connectToSocket(String path) =>
    Socket.startConnect(InternetAddress(path, type: InternetAddressType.unix), 0);

/// Connects to [path] within [within], and cancels a connection that did not finish in time, so no probe is left
/// pending.
Future<SocketProbe> probeSocket(
  String path,
  ConnectToSocket connect, {
  Duration within = const Duration(seconds: 1),
}) async {
  ConnectionTask<Socket>? task;
  Future<ConnectionTask<Socket>>? pending;
  try {
    final waited = Stopwatch()..start();
    pending = connect(path);
    task = await pending.timeout(within);
    final left = within - waited.elapsed;
    (await task.socket.timeout(left > Duration.zero ? left : Duration.zero)).destroy();
    return SocketProbe.answers;
  } on TimeoutException {
    if (task != null) {
      task.cancel();
    } else {
      // A connection that starts after the probe gave up is cancelled once it does, never left pending.
      // Its socket fails once it is cancelled, and nothing else waits for it.
      pending?.then((late) {
        late.socket.ignore();
        late.cancel();
      }, onError: (Object _) {}).ignore();
    }
    return SocketProbe.unknown;
  } on SocketException catch (failure) {
    return _nobodyThere(failure.osError?.errorCode) ? SocketProbe.nobody : SocketProbe.unknown;
  } on OSError catch (failure) {
    return _nobodyThere(failure.errorCode) ? SocketProbe.nobody : SocketProbe.unknown;
  }
}

// ECONNREFUSED and ENOENT on Linux, WSAECONNREFUSED on Windows: the only answers that prove nothing listens there.
bool _nobodyThere(int? errno) => errno == 111 || errno == 2 || errno == 10061;
