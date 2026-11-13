import 'package:porelo_host/porelo_host.dart'
    show HostCardSsh, pinnedHostSshOptions, poreloHostKnownHosts, poreloHostSshConfig;

import 'connection_trial.dart';
import 'connections.dart';
import 'desk.dart';

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';

import 'fleet_backend.dart';
import 'fleet_model.dart';
import 'host_keys.dart';
import 'machine_setup.dart';
import 'tunnel.dart';
import 'wsl.dart';
import 'settings.dart';

/// Uses Windows' OpenSSH tools so PATH cannot select another installation and agent.
String windowsOpenSsh(String program, Map<String, String> environment) {
  final root = environment['SystemRoot'] ?? '';
  final systemRoot = RegExp(r'^[A-Za-z]:\\').hasMatch(root) ? root : r'C:\Windows';
  return '$systemRoot\\System32\\OpenSSH\\$program.exe';
}

/// Selects the same OpenSSH installation for every command on this desktop.
String openSsh(String program, {Desk? on}) {
  final here = on ?? desk;
  return here.isWindows ? windowsOpenSsh(program, here.environment) : program;
}

/// One machine this interface can reach.
///
/// A name and a socket path — and, when the interface raises the way in itself, where that
/// machine is. **Both kinds must keep working.** A socket somebody else forwarded is the path
/// with no credential handling in it at all, so a machine described by a path is opened exactly
/// as it always was: nothing raised, nothing supervised, nothing taken down.
@immutable
class Machine {
  /// Constructor taking what to call it and where its socket is.
  ///
  /// [host] and [remoteSocket] are given only for a machine this interface reaches itself. With
  /// no [host] it is a socket somebody else forwarded, and stays untouched.
  const Machine({
    required this.name,
    required this.socketPath,
    this.host = '',
    this.remoteSocket = '',
    this.kind = '',
    this.distribution = '',
    this.identity = '',
    this.hostProject = '',
    this.hostCard,
    this.sshConfig = '',
    this.unknownFields = const <String, Object?>{},
    this.disconnected = false,
  });

  /// Uses another local socket endpoint without changing the destination or its trust policy.
  Machine withSocketPath(String path) => Machine(
    name: name,
    socketPath: path,
    host: host,
    remoteSocket: remoteSocket,
    kind: kind,
    distribution: distribution,
    identity: identity,
    hostProject: hostProject,
    hostCard: hostCard,
    sshConfig: sshConfig,
    unknownFields: unknownFields,
    disconnected: disconnected,
  );

  /// The same entry, marked as a person's decision to stay away from it or not.
  Machine withDisconnected(bool value) => Machine(
    name: name,
    socketPath: socketPath,
    host: host,
    remoteSocket: remoteSocket,
    kind: kind,
    distribution: distribution,
    identity: identity,
    hostProject: hostProject,
    hostCard: hostCard,
    sshConfig: sshConfig,
    unknownFields: unknownFields,
    disconnected: value,
  );

  /// The machine to open when nothing has been stored yet.
  ///
  /// The local daemon, unless `PORELO_SOCKET` names another socket — a forwarded one, or the mock
  /// while the interface is being worked on. [environment] is injectable so this can be held to
  /// that: it was quietly dropped once during the rework that made several machines possible, and
  /// nothing noticed until the window said it could not connect to a daemon nobody was running.
  ///
  /// On Windows this computer is the person's WSL distribution, reached through `wsl.exe`
  /// ([thisComputersDistribution]); until it is found, an entry of the kind `wsl` naming none, which says so.
  factory Machine.local({Map<String, String>? environment}) {
    if (desk.isWindows) {
      final distribution = thisComputersDistribution ?? '';
      return Machine(
        name: distribution.isEmpty ? 'this computer' : distribution,
        socketPath: '',
        kind: 'wsl',
        distribution: distribution,
      );
    }
    final socket = (environment ?? Platform.environment)['PORELO_SOCKET'];
    if (socket == null || socket.isEmpty) {
      return Machine(name: 'this machine', socketPath: Backend.local().socketPath);
    }
    return Machine(name: socket.split('/').last, socketPath: socket);
  }

  /// On Windows, the WSL distribution that is this computer once it was found; null before, and on Linux.
  static String? thisComputersDistribution;

  /// The mock, when somebody is working on the interface: where `PORELO_SOCKET` points, or where
  /// `tool/mock_daemon.dart` puts its socket by default.
  factory Machine.mock({Map<String, String>? environment}) {
    final socket = (environment ?? Platform.environment)['PORELO_SOCKET'] ?? '';
    if (socket.isEmpty || socket == defaultMockSocket) {
      return const Machine(name: 'mock', socketPath: defaultMockSocket);
    }
    return Machine(name: socket.split('/').last, socketPath: socket);
  }

  /// Where `tool/mock_daemon.dart` puts its socket unless told otherwise.
  static const String defaultMockSocket = '/tmp/porelo-mock.sock';

  /// Reads one back from what was stored.
  ///
  /// **Every field is checked rather than cast.** That file is a person's own JSON, editable by
  /// hand and written by older versions of this program; a number where a path belongs used to
  /// throw during the load, and the load runs where nobody is waiting for it — so the symptom was
  /// an interface that opened with the machine list silently reduced to the local daemon, which
  /// is indistinguishable from having lost the list.
  ///
  /// **An entry of a kind this build does not know is kept, every field of it.** The file is also
  /// read by `porelo-intellij`, and written by later versions of this program: dropping what is not
  /// understood here would lose a machine somebody set up elsewhere, the next time this list is
  /// saved.
  factory Machine.fromStored(Map<String, Object?> stored) {
    final card = stored.containsKey('hostCard') ? HostCardSsh.fromStored(stored['hostCard']) : null;
    // A card's daemon is the login's socket on its host, whatever an older build saved: one with the account's uid or
    // return socket named it by the uid, and an earlier layout put it elsewhere.
    final older = card != null && _text(stored['remoteSocket']) != card.daemonSocket;
    return Machine(
      name: _text(stored['name']),
      socketPath: _text(stored['socket']),
      host: _text(stored['host']),
      remoteSocket: older ? card.daemonSocket : _text(stored['remoteSocket']),
      // A card host is stored without its kind, so the plugin, which reads this file, takes it as a machine.
      kind: card != null && _text(stored['kind']).isEmpty ? 'host' : _text(stored['kind']),
      distribution: _text(stored['distribution']),
      identity: _text(stored['identity']),
      hostProject: _text(stored['hostProject']),
      hostCard: card,
      sshConfig: _text(stored['sshConfig']),
      disconnected: stored['disconnected'] == true,
      unknownFields: <String, Object?>{
        for (final entry in stored.entries)
          if (!_knownFields.contains(entry.key)) entry.key: entry.value,
      },
    );
  }

  static const Set<String> _knownFields = <String>{
    'name',
    'socket',
    'host',
    'remoteSocket',
    'kind',
    'distribution',
    'identity',
    'hostProject',
    'hostCard',
    'sshConfig',
    'disconnected', //
  };

  static String _text(Object? value) => value is String ? value : '';

  /// Whether the person disconnected it: it stays listed, nothing connects to it until they say so, also after a
  /// restart. `frontend.json` says so with `disconnected: true`.
  final bool disconnected;

  /// What to call it. Shown wherever an action could be ambiguous about where it lands.
  final String name;

  /// The unix socket to open. For a managed machine, the local end this interface creates.
  final String socketPath;

  /// Where the machine is, as `ssh` would be given it. Empty when somebody else forwards it.
  final String host;

  /// The socket on that machine. Empty when somebody else forwards it.
  final String remoteSocket;

  /// Which way in this is, when it is neither a socket nor a machine behind ssh: `wsl` for a WSL
  /// distribution, reached from Windows through `wsl.exe -d <distribution> -- porelo daemon connect`.
  /// A managed server has kind `host` and uses its verified host-card SSH configuration.
  final String kind;

  /// The WSL distribution, for a machine of the kind `wsl`.
  final String distribution;

  /// The legacy private key path retained only to recognize obsolete host entries.
  final String identity;

  /// The project whose kept host setup rented this machine, empty for older entries.
  final String hostProject;

  /// The verified public card and admitted account transport values, when imported.
  final HostCardSsh? hostCard;

  /// The public OpenSSH configuration shared with Core and plugins.
  final String sshConfig;

  /// Makes a watched host from Core's verified values without a private identity.
  factory Machine.fromHostCard(
    HostCardSsh card, {
    required String socketPath,
    String? sshConfig,
    String hostProject = '',
  }) => Machine(
    name: card.name,
    kind: 'host',
    host: card.name,
    hostProject: hostProject,
    socketPath: socketPath,
    remoteSocket: card.daemonSocket,
    hostCard: card,
    sshConfig: sshConfig ?? card.configPath(environment: desk.environment, windows: desk.isWindows),
  );

  /// What an entry held beyond the fields this build knows, kept so that saving loses nothing.
  final Map<String, Object?> unknownFields;

  /// Why this build cannot reach it, or null when it can.
  String? get whyNotReachableHere => whyNotReachableOn(windows: desk.isWindows);

  /// Why it cannot be reached from Linux, or from Windows when [windows] is true, or null when it can.
  ///
  /// A WSL distribution is reached from Windows only. On Windows, a socket entry names a path on a
  /// Linux computer. A machine over ssh uses a byte relay. An entry of
  /// a kind this version does not know is left exactly as it is. Each is said, never tried as a path.
  String? whyNotReachableOn({required bool windows}) => switch (kind) {
    'host' when hostCard == null && identity.isNotEmpty =>
      'This entry is from an older version: remove it and connect again.',
    'host'
        when hostCard != null &&
            (sshConfig.isEmpty || host != hostCard!.name || remoteSocket != hostCard!.daemonSocket) =>
      'The imported machine needs its matching public SSH configuration and daemon endpoint.',
    'host' when hostCard != null => null,
    'host' when remoteSocket.isEmpty && socketPath.isEmpty =>
      'This server is prepared with no project account or daemon.',
    'host' when hostProject.isEmpty => 'This machine has no verified SSH configuration.',
    '' || 'host' when needsATunnel && host.startsWith('-') => 'A machine’s ssh address must not start with a dash.',
    '' || 'host' when windows && needsATunnel && !_plainRemoteSocket =>
      "The remote socket must be a plain path: letters, digits, '.', '_', '-' and '/'.",
    '' || 'host' when windows && needsATunnel => null,
    '' || 'host' when windows => 'This entry names a socket on a Linux computer, which Windows cannot open.',
    '' || 'host' => null,
    'wsl' when windows && distribution.isEmpty =>
      'Porelo runs in a WSL distribution on Windows, and none was found. Install one with wsl --install, or '
          'choose one under Add a machine, WSL.',
    'wsl' when windows => null,
    'wsl' =>
      'The WSL distribution ${distribution.isEmpty ? '' : '$distribution '}is reached from '
          'Windows, through wsl.exe, and this build of the interface cannot do that.',
    _ =>
      'This version of the interface does not know machines of the kind "$kind", so it '
          'leaves this one as it is.',
  };

  /// The process carrying the daemon's bytes on Windows, or null for a socket.
  ({String kind, List<String> command})? get relay => relayOn(windows: desk.isWindows, environment: desk.environment);

  /// Builds the relay without consulting the test machine's platform or environment.
  ({String kind, List<String> command})? relayOn({required bool windows, required Map<String, String> environment}) {
    if (!windows) return null;
    if (kind == 'wsl') return distribution.isEmpty ? null : (kind: 'wsl', command: Wsl.relayTo(distribution));
    if ((kind.isNotEmpty && kind != 'host') || !needsATunnel) return null;
    if (kind == 'host' && whyNotReachableOn(windows: windows) != null) return null;
    if (host.startsWith('-') || !_plainRemoteSocket) return null;
    return (
      kind: 'ssh',
      command: <String>[
        windowsOpenSsh('ssh', environment),
        ...loginSshOptionsOn(environment: environment, windows: windows),
        '-T',
        if (kind != 'host') ...<String>['-o', 'BatchMode=yes'],
        '-o',
        'ServerAliveInterval=15',
        if (kind != 'host') ...<String>['-o', 'ControlMaster=no', '-o', 'ControlPath=none'],
        '--',
        host,
        inTheLoginShell("porelo daemon connect --socket '$remoteSocket'"),
      ],
    );
  }

  bool get _plainRemoteSocket => RegExp(r'^/[A-Za-z0-9._/-]+$').hasMatch(remoteSocket);

  /// Where it is, in a word or two: the host, the WSL distribution, or the socket.
  String get where => switch (kind) {
    '' || 'host' => needsATunnel ? host : socketPath,
    'wsl' => 'WSL: $distribution',
    _ => 'kind "$kind"',
  };

  /// SSH options shared by all access to this account.
  List<String> get loginSshOptions => loginSshOptionsOn(environment: desk.environment, windows: desk.isWindows);

  /// Builds account options using the supplied desktop's config and pinned host key.
  List<String> loginSshOptionsOn({required Map<String, String> environment, required bool windows}) {
    if (hostCard != null) {
      // The card config pins trust and identity. On Linux a command goes only through the card's master; Windows'
      // OpenSSH holds none, so there each command opens a connection of its own.
      return windows ? ['-F', sshConfig] : ['-F', sshConfig, '-o', 'ControlMaster=no', '-o', 'ProxyCommand=false'];
    }
    if (kind != 'host') return const [];
    if (identity.isNotEmpty) {
      return pinnedHostSshOptions(poreloHostKnownHosts(environment: environment, windows: windows), identity);
    }
    final config = poreloHostSshConfig(hostProject, environment: environment, windows: windows);
    final knownHosts = '$config.known_hosts'.replaceAll('%', '%%');
    return [...pinnedHostSshOptions(knownHosts, ''), '-F', config];
  }

  /// Whether this interface raises the way in to it.
  ///
  /// The one question a person needs answered about a machine in the list, because it decides
  /// what happens when it stops answering — and what happens when the window closes.
  bool get needsATunnel => host.isNotEmpty && remoteSocket.isNotEmpty;

  /// Whether this is this computer's own daemon, at the place this user's Porelo puts its socket:
  /// one the interface can start here, as it starts one it logs into. **Never a WSL distribution**,
  /// nor a machine with no socket: on Windows there is no local daemon, and its socket reads as `''`.
  bool get isThisComputer =>
      kind.isEmpty && !needsATunnel && socketPath.isNotEmpty && socketPath == Backend.local().socketPath;

  /// Whether it is the entry this computer always has, listed always and never forgotten: [Machine.local], or on
  /// Windows the WSL distribution that is this computer, whatever name it was added under.
  bool get isAlwaysListed {
    final local = Machine.local();
    return desk.isWindows
        ? kind == 'wsl' && distribution == local.distribution
        : name == local.name && socketPath == local.socketPath;
  }

  /// Whether this interface can start the daemon itself: over its own login, or here.
  bool get canBeStartedHere => whyNotReachableHere == null && (needsATunnel || isThisComputer);

  /// How it is stored between runs.
  ///
  /// Only legacy hosts retain a private identity path; one-click hosts use their written configuration.
  ///
  /// A WSL entry carries no `socket`: the plugin, which reads this file too, drops an entry
  /// without one, rather than opening a Linux path on Windows.
  Map<String, Object?> get stored => <String, Object?>{
    'name': name,
    if (kind.isEmpty || socketPath.isNotEmpty) 'socket': socketPath,
    if (host.isNotEmpty) 'host': host,
    if (remoteSocket.isNotEmpty) 'remoteSocket': remoteSocket,
    if (kind.isNotEmpty && hostCard == null) 'kind': kind,
    if (distribution.isNotEmpty) 'distribution': distribution,
    if (identity.isNotEmpty && hostCard == null) 'identity': identity,
    if (hostCard != null) 'hostCard': hostCard!.stored,
    if (sshConfig.isNotEmpty) 'sshConfig': sshConfig,
    if (hostProject.isNotEmpty) 'hostProject': hostProject,
    if (disconnected) 'disconnected': true,
    ...unknownFields,
  };

  /// Where Porelo serves the daemon of the account with [uid], on its machine.
  static String porelodSocketFor(int uid) => '/run/user/$uid/porelo/porelod.sock';

  /// What [name] becomes in a path. Two names that differ only in what this replaces share a forward.
  static String slug(String name) => name.replaceAll(RegExp('[^A-Za-z0-9_-]'), '-');

  /// Where the local end of a managed forward goes.
  ///
  /// Under the runtime directory, which is the one place already owner-only — the criterion that
  /// the endpoint is readable by nobody else is answered by where it is put, not by what is done
  /// to it afterwards.
  static String endpointFor(String name, {Map<String, String>? environment}) {
    final env = environment ?? Platform.environment;
    final runtime =
        env['XDG_RUNTIME_DIR'] ?? '/run/user/${Process.runSync('id', const <String>['-u']).stdout.toString().trim()}';
    return '$runtime/porelo-tunnel-${slug(name)}.sock';
  }

  /// Whether the socket is readable by anybody but its owner.
  ///
  /// `ssh` creates a forwarded endpoint owner-only, so this should never be true — but it is the
  /// one property of the transport that can be checked from here, and a forward somebody made by
  /// hand can be looser than the socket it forwards.
  bool get readableByOthers {
    try {
      final mode = FileStat.statSync(socketPath).mode;
      return mode & 0x3F != 0; // any group or other bit
    } on FileSystemException {
      return false;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Machine &&
      other.name == name &&
      other.socketPath == socketPath &&
      other.host == host &&
      other.remoteSocket == remoteSocket &&
      other.kind == kind &&
      other.distribution == distribution &&
      other.identity == identity &&
      other.hostProject == hostProject &&
      other.disconnected == disconnected &&
      other.hostCard == hostCard &&
      other.sshConfig == sshConfig &&
      mapEquals(other.unknownFields, unknownFields);

  @override
  int get hashCode =>
      Object.hash(name, socketPath, host, remoteSocket, kind, distribution, identity, hostProject, hostCard, sshConfig);
}

/// Every machine this interface is watching, and which one it is acting on.
///
/// **Connected to all of them, acting on one.** A clearance prompt has a deadline and does not
/// come again, so a machine nobody is connected to is a machine whose blocked work expires
/// unseen. Which one an action lands on is a separate question, and it is answered by [current]
/// — never by which one happens to be reachable.
class Machines extends ChangeNotifier {
  /// Constructor taking where the list is kept and how to reach a machine.
  ///
  /// One machine exists from the moment this does, before anything is read back from disk. The
  /// frame is drawn before [load] can finish, and a frame with no machine behind it has nothing
  /// to draw — which it did, as a crash on the first frame.
  ///
  /// `lookFor` is a machine shown besides the stored ones **only while something answers at its
  /// socket**, and never stored: the mock, so a person working on the interface does not have to
  /// add it to every list they keep. `answers` says whether something does.
  Machines(
    this._settings, {
    FleetBackend Function(Machine)? reach,
    Tunnels? tunnels,
    this._lookFor,
    Future<bool> Function(String socket)? answers,
    HostKeys? hostKeys,
    MachineSetup? setup,
    bool Function()? poreloIsInstalledHere,
    this._now = DateTime.now,
    this._retryAfter = const Duration(seconds: 2),
    this._relaysBySsh = _relaysBySshHere,
    Future<String?> Function()? thisComputersDistribution,
  }) : _findThisComputer = thisComputersDistribution ?? _defaultDistribution,
       _reach = reach ?? overSocket,
       _poreloHere = poreloIsInstalledHere ?? _porelodOnThePath,
       hostKeys = hostKeys ?? SshHostKeys(),
       setup = setup ?? MachineSetup(),
       _answers = answers ?? _answersAt,
       tunnels = tunnels ?? Tunnels() {
    // On Windows the distribution is found again by [load], for this list, whatever an earlier one found.
    if (desk.isWindows) Machine.thisComputersDistribution = null;
    final local = Machine.local();
    _machines.add(local);
    _selected = local.name;
    _open(local);
  }

  final Settings _settings;

  /// Which WSL distribution is this computer, on Windows.
  final Future<String?> Function() _findThisComputer;

  /// The distribution `wsl.exe` marks as the default, else the first it lists; null where it lists none.
  static Future<String?> _defaultDistribution() async {
    final all = await Wsl().distributions();
    for (final each in all) {
      if (each.isDefault) return each.name;
    }
    return all.isEmpty ? null : all.first.name;
  }

  /// The persisted interface choices shared with host preparation.
  Settings get settings => _settings;
  final bool Function() _poreloHere;

  /// Whether this computer has a Porelo of its own to run. **Most people's has none**: the work runs
  /// on a machine they reach, and a computer without Porelo is not a machine that went silent.
  bool get poreloIsInstalledHere => _poreloHere();

  /// Whether `porelod` is on this computer's path, or where an account's own install puts it.
  ///
  /// On Windows never: Porelo runs in a WSL distribution there, which is a machine of its own.
  static bool _porelodOnThePath() {
    if (desk.isWindows) return false;
    final environment = Platform.environment;
    final home = environment['HOME'] ?? '';
    final places = <String>[
      ...(environment['PATH'] ?? '').split(':').where((each) => each.isNotEmpty),
      if (home.isNotEmpty) '$home/.local/bin',
    ];
    return places.any((each) => File('$each/porelod').existsSync());
  }

  final FleetBackend Function(Machine) _reach;

  /// Confirms a machine's host key before the first login.
  final HostKeys hostKeys;

  /// Makes the key a new machine is reached with, and logs in to it as root.
  final MachineSetup setup;
  final Machine? _lookFor;
  final Future<bool> Function(String socket) _answers;

  /// Names shown but never stored.
  final Set<String> _passing = <String>{};

  /// The forwards this interface raised. **Only the ones it raised** — a socket somebody else
  /// forwarded is opened as it always was, and is not in here to be taken down.
  final Tunnels tunnels;
  final Map<String, FleetModel> _watching = <String, FleetModel>{};

  /// Which node each machine turned out to be, by machine name. **Only ever non-empty ids.**
  final Map<String, String> _nodes = <String, String>{};
  final List<Machine> _machines = <Machine>[];
  String? _selected;
  bool _disposed = false;
  Future<void> _changing = Future.value();

  Future<void> _change(Future<void> Function() work) {
    final next = _changing.then((_) => work());
    _changing = next.then<void>((_) {}, onError: (Object error, StackTrace stack) {});
    return next;
  }

  /// Whether something accepts a connection at [socket] within a second.
  static Future<bool> _answersAt(String socket) async {
    try {
      final connection = await Socket.connect(
        InternetAddress(socket, type: InternetAddressType.unix),
        0,
      ).timeout(const Duration(seconds: 1));
      connection.destroy();
      return true;
    } on Object {
      return false;
    }
  }

  /// How [machine] is spoken to over its socket: a start asks for a certificate unless it is this computer.
  static FleetBackend overSocket(Machine machine) =>
      PoreloBackend(backendFor(machine), asksToCertify: !machine.isThisComputer);

  /// Where [machine]'s daemon is: its socket, or the relay into its WSL distribution, which is
  /// asked before each connection whether the distribution runs.
  static Backend backendFor(Machine machine) => Backend(
    socketPath: machine.socketPath,
    label: machine.name,
    notReachable: machine.whyNotReachableHere,
    relay: machine.relay?.command,
    whyNotNow: machine.kind == 'wsl' && desk.isWindows ? () => Wsl().whyNotNow(machine.distribution) : null,
  );

  /// Where Porelo's socket is for the account `host` logs in as, asked of the machine, or null when
  /// it could not be asked.
  Future<String?> socketAt(String host) async {
    final uid = await tunnels.loginUidAt(host);
    return uid == null ? null : Machine.porelodSocketFor(uid);
  }

  /// Whether [machine]'s daemon answers within [within], asked over [open] or its own way in. **The
  /// connection is closed whatever came of it**: one that is not answered is a relay and a socket
  /// left open at every look.
  static Future<bool> daemonAnswers(
    Machine machine, {
    Duration within = const Duration(seconds: 10),
    Future<VarlinkConnection> Function()? open,
  }) async {
    VarlinkConnection? connection;
    try {
      connection = await (open ?? backendFor(machine).open)();
      await connection.call('org.varlink.service.GetInfo').timeout(within);
      return true;
    } on Object {
      return false;
    } finally {
      await connection?.close();
    }
  }

  /// Tries [machine] as watching it would, without watching it or leaving anything running.
  Future<Trial> tryMachine(Machine machine) => tryAMachine(machine, reach: _reach, tunnels: tunnels);

  /// How many ways into [machine]'s vault there are, or null when it could not be asked.
  Future<int?> keyslotsOn(Machine machine) => countKeyslots(machine, reach: _reach, tunnels: tunnels);

  /// Starts a daemon on [machine], for somebody who has been asked and said yes.
  Future<Started> startPoreloOn(Machine machine) => tunnels.startPoreloOn(machine);

  /// Stops the daemon on [machine], for somebody who has been told what it costs and said yes.
  Future<Started> stopPoreloOn(Machine machine) => tunnels.stopPoreloOn(machine);

  /// Every machine, in the order they were added.
  List<Machine> get all => List<Machine>.unmodifiable(_machines);

  /// What is said of stored machines whose host card did not read: they are kept in the file and not watched.
  String? get setAside => switch (_settings.machinesSetAside) {
    [] => null,
    final names =>
      'The saved machine card of ${names.join(', ')} does not read in this version, so it is not watched. '
          'It stays saved as it was.',
  };

  /// What is being acted on. There is always one.
  Machine get current => _machines.firstWhere((machine) => machine.name == _selected, orElse: () => _machines.first);

  /// The fleet of the machine being acted on.
  FleetModel get fleet => of(current);

  /// The fleet of one machine, whether or not it is the one being acted on: for a caller holding a machine it opened.
  FleetModel of(Machine machine) => _watching[machine.name]!;

  /// The fleet of [machine] while it is watched, else null. **For whoever walks [all]**: every stored machine is
  /// listed before the first is opened, and a card's opening speaks before the machines after it are opened.
  FleetModel? watching(Machine machine) => _watching[machine.name];

  bool _automaticRetriesPaused = false;

  /// Cancels reconnect timers without disposing the machine models.
  void pauseAutomaticRetries() {
    _automaticRetriesPaused = true;
    for (final fleet in _watching.values) {
      fleet.pauseAutomaticRetry();
    }
  }

  /// Restarts retry scheduling when a window is attached again.
  void resumeAutomaticRetries() {
    _automaticRetriesPaused = false;
    for (final fleet in _watching.values) {
      fleet.resumeAutomaticRetry();
    }
  }

  /// Which node [machine] turned out to be, or empty when it has not said.
  String nodeOf(Machine machine) => _nodes[machine.name] ?? '';

  /// The other machines in the list that are the same node as [machine].
  ///
  /// **Empty is never equal to empty.** A daemon older than the method says nothing, and treating
  /// that as a value would report every such machine as the same node — which is the same failure
  /// this exists to prevent, arriving from the other direction.
  List<Machine> sameNodeAs(Machine machine) {
    final id = nodeOf(machine);
    if (id.isEmpty) return const <Machine>[];
    return <Machine>[
      for (final other in _machines)
        if (other != machine && _nodes[other.name] == id) other,
    ];
  }

  /// How many machines are not answering.
  int get unreachable => _watching.values
      .where(
        (fleet) =>
            fleet.reachability == Reachability.unreachable &&
            (fleet.hostReachability == null || fleet.hostReachability == HostReachability.notReached),
      )
      .length;

  /// Reads the machines an earlier run stored and opens all of them.
  ///
  /// Nothing stored leaves the one this started with, which is the local daemon or whatever
  /// `PORELO_SOCKET` names. The machine to look for is added after either, when it answers.
  Future<void> load() => _change(_load);

  Future<void> _load() async {
    final found = desk.isWindows ? await _theDistribution() : null;
    final stored = await _settings.machines();
    final moved = desk.isWindows ? null : _thisMachineMoved(stored);
    if (moved != null) stored[moved] = Machine.local();
    if (stored.isNotEmpty) await _adopt(stored);
    if (desk.isWindows && !_disposed) _listThisComputer(found);
    if (moved != null && !_disposed) await _remember();
    // An older card is saved again without what it no longer holds, so the plugin reads today's endpoint too.
    if (_settings.olderMachines) await _remember();
    final extra = _lookFor;
    if (extra != null &&
        !_machines.any((each) => each.socketPath == extra.socketPath || each.name == extra.name) &&
        await _answers(extra.socketPath) &&
        !_disposed) {
      _machines.add(extra);
      _passing.add(extra.name);
      _open(extra);
    }
    _notify();
  }

  /// Where in [stored] this machine was saved at a socket that is no longer its own, as under a runtime folder that
  /// changed; null where none was. Only the entry the window itself names *this machine*: a plain socket, no kind, no
  /// host, no tunnel, and only while `PORELO_SOCKET` names no other daemon. Left as saved, the local daemon was listed
  /// again beside it under the same name, which names alone tell apart.
  int? _thisMachineMoved(List<Machine> stored) {
    if ((Platform.environment['PORELO_SOCKET'] ?? '').isNotEmpty) return null;
    final local = Machine.local();
    // Without a local daemon's socket, as on Windows, nothing here is this machine's to have moved.
    if (local.socketPath.isEmpty) return null;
    final at = stored.indexWhere(
      (each) =>
          each.name == local.name &&
          each.kind.isEmpty &&
          each.host.isEmpty &&
          !each.needsATunnel &&
          each.socketPath.isNotEmpty &&
          each.socketPath != local.socketPath,
    );
    return at < 0 ? null : at;
  }

  /// The WSL distribution `wsl.exe` names as this computer, or null where it names none or cannot be asked.
  Future<String?> _theDistribution() async {
    try {
      final found = await _findThisComputer();
      return found == null || found.isEmpty ? null : found;
    } on Object {
      return null;
    }
  }

  /// On Windows this computer is listed whatever was stored, as on Linux the local daemon is from the start: the
  /// distribution [found], else one stored, else the entry naming none, and each opened once.
  void _listThisComputer(String? found) {
    final stored = _machines.where((each) => each.kind == 'wsl' && each.distribution.isNotEmpty);
    Machine.thisComputersDistribution = found ?? (stored.isEmpty ? null : stored.first.distribution);
    _dropTheStandIn();
    if (_machines.any((each) => each.isAlwaysListed)) return;
    var local = Machine.local();
    // A machine of another kind may carry the distribution's name; names tell machines apart.
    if (_machines.any((each) => each.name == local.name)) {
      local = Machine(name: 'WSL ${local.distribution}', socketPath: '', kind: 'wsl', distribution: local.distribution);
    }
    _machines.insert(0, local);
    _open(local);
    if (!_machines.any((each) => each.name == _selected)) _selected = local.name;
  }

  /// Takes out the entry naming no distribution, once one is known, and what watched it.
  void _dropTheStandIn() {
    if (Machine.thisComputersDistribution == null) return;
    final standIns = _machines.where((each) => each.kind == 'wsl' && each.distribution.isEmpty).toList();
    for (final standIn in standIns) {
      _machines.remove(standIn);
      _watching.remove(standIn.name)?.dispose();
      if (_selected == standIn.name && _machines.isNotEmpty) _selected = _machines.first.name;
    }
  }

  /// Replaces the set of machines being watched, closing what watched the old ones.
  Future<void> _adopt(List<Machine> machines) async {
    tunnels.checkCards(machines);
    for (final fleet in _watching.values) {
      fleet.dispose();
    }
    _watching.clear();
    for (final machine in _machines) {
      await tunnels.dropFor(machine);
    }
    try {
      await tunnels.replaceCards(machines);
    } on Object {
      for (final machine in _machines) {
        _open(machine);
      }
      rethrow;
    }
    _nodes.clear();
    _machines
      ..clear()
      ..addAll(machines);
    _selected = _machines.first.name;
    for (final machine in _machines) {
      _open(machine);
    }
  }

  /// Adds a machine or replaces a same-name host. The selection stays where it is.
  Future<void> add(Machine machine) => _change(() => _add(machine));

  Future<void> _add(Machine machine) async {
    _raiseHolds.remove(machine.name);
    final at = _machines.indexWhere((each) => each.name == machine.name);
    if (at >= 0) {
      final old = _machines[at];
      if (old.kind != 'host' || machine.kind != 'host') return;
      tunnels.checkCards([..._machines]..[at] = machine);
      _watching.remove(old.name)?.dispose();
      await tunnels.dropFor(old);
      try {
        await tunnels.replaceCards(_machines.map((each) => each == old ? machine : each));
      } on Object {
        _open(old);
        rethrow;
      }
      _nodes.remove(old.name);
      _machines[at] = machine;
      _open(machine);
      await _remember();
      _notify();
      return;
    }
    if (desk.isWindows && machine.kind == 'wsl') {
      // A distribution is one machine, whatever name it was added under.
      if (_machines.any((each) => each.kind == 'wsl' && each.distribution == machine.distribution)) return;
      // With none found, the first one added is this computer, in place of the entry naming none.
      if (Machine.thisComputersDistribution == null) {
        Machine.thisComputersDistribution = machine.distribution;
        final selectedTheStandIn = _machines.any(
          (each) => each.name == _selected && each.kind == 'wsl' && each.distribution.isEmpty,
        );
        _dropTheStandIn();
        if (selectedTheStandIn || _machines.isEmpty) _selected = machine.name;
      }
    }
    await tunnels.registerCards([machine]);
    _machines.add(machine);
    _open(machine);
    await _remember();
    _notify();
  }

  /// Saves the watched machines again, after a save that failed once a machine was added.
  Future<void> remember() => _change(_remember);

  /// Forgets a machine, closing what was watching it and taking down any forward raised for it.
  ///
  /// Forgetting the one being acted on moves to another rather than leaving nothing selected: a
  /// frame with no machine behind it has nothing to say and no way to say why.
  Future<void> forget(Machine machine) => _change(() => _forget(machine));

  /// Ends this computer's connection and keeps the entry, marked, so that nothing raises it again.
  Future<void> disconnect(Machine machine) => _change(() => _mark(machine, disconnected: true));

  /// Connects to an entry that was disconnected.
  Future<void> reconnect(Machine machine) => _change(() => _mark(machine, disconnected: false));

  Future<void> _mark(Machine machine, {required bool disconnected}) async {
    final at = _machines.indexWhere((each) => each.name == machine.name);
    if (at < 0) return;
    final old = _machines[at];
    if (old.disconnected == disconnected || old.isThisComputer || old.isAlwaysListed) return;
    _raiseHolds.remove(machine.name);
    final next = _machines[at].withDisconnected(disconnected);
    _watching.remove(machine.name)?.dispose();
    await tunnels.dropAndUnpublish(_machines[at]);
    _machines[at] = next;
    _open(next);
    await _remember();
    _notify();
  }

  Future<void> _forget(Machine machine) async {
    // Only the entry as it was asked for: one changed meanwhile, as by a disconnect, stays, and so does what watches it.
    if (!_machines.contains(machine)) return;
    _raiseHolds.remove(machine.name);
    if (_machines.length == 1) {
      if (machine.kind != 'host') return;
      await _add(Machine.local());
    }
    _machines.remove(machine);
    _watching.remove(machine.name)?.dispose();
    unawaited(tunnels.dropFor(machine));
    if (_selected == machine.name) _selected = _machines.first.name;
    await _remember();
    _notify();
  }

  /// Chooses which machine actions land on.
  void select(Machine machine) {
    if (_selected == machine.name) return;
    _selected = machine.name;
    _notify();
  }

  final Set<String> _raisingAgain = <String>{};

  final DateTime Function() _now;
  final Duration _retryAfter;
  final bool Function(Machine) _relaysBySsh;

  static bool _relaysBySshHere(Machine machine) => machine.relay?.kind == 'ssh';

  /// How long a machine waits after an ssh connection of its own came to nothing.
  ///
  /// sshd counts each connection from an address that does not log in, and past a score refuses them
  /// all for a while. A window asking every few seconds keeps a machine shut that would have opened
  /// again by itself. What a person presses goes at once, whatever this says.
  static const firstRaiseWait = Duration(seconds: 30);

  /// The longest it waits.
  static const longestRaiseWait = Duration(minutes: 5);
  final Map<String, ({DateTime until, Duration wait})> _raiseHolds = {};

  /// The words to say while [machine] waits, or null if it may try now.
  String? _raiseHeld(Machine machine) {
    if (tunnels.of(machine)?.state == TunnelState.up) _raiseHolds.remove(machine.name);
    final hold = _raiseHolds[machine.name];
    final raising = _raisingAgain.contains(machine.name);
    if (!raising && (hold == null || !_now().isBefore(hold.until))) return null;
    final said = tunnels.of(machine)?.problem;
    return '${said ?? 'The machine did not answer.'} This computer tries again by itself, within five minutes, and Connect tries now.';
  }

  /// Notes how a raise of [machine] ended. Waiting for a key in the agent starts no connection.
  void _raiseEnded(Machine machine, {required bool up}) {
    final state = tunnels.of(machine)?.state;
    if (up || state == TunnelState.up || state == TunnelState.waitingForKey) {
      _raiseHolds.remove(machine.name);
    } else {
      final last = _raiseHolds[machine.name]?.wait;
      final wait = last == null
          ? firstRaiseWait
          : last * 2 > longestRaiseWait
          ? longestRaiseWait
          : last * 2;
      _raiseHolds[machine.name] = (until: _now().add(wait), wait: wait);
    }
  }

  void _open(Machine machine) {
    final fleet = FleetModel(
      _reach(machine),
      machine: machine.name,
      retryAfter: _retryAfter,
      onRemoved: (task) => unawaited(_settings.forgetRemovedTask(machine.name, task)),
      mayPrepareOnItsOwn: () {
        final relay = _relaysBySsh(machine);
        if (machine.hostCard == null && !relay) return null;
        final held = _raiseHeld(machine);
        // A relay's connection is the opening itself, so its try is counted before it goes.
        if (held == null && relay) _raiseEnded(machine, up: false);
        return held;
      },
      prepareConnection: machine.hostCard == null
          ? null
          : () async {
              final up = await tunnels.raiseFor(machine);
              _raiseEnded(machine, up: up);
              if (up) return null;
              return machine.whyNotReachableHere ?? tunnels.of(machine)?.problem ?? 'The machine could not be reached.';
            },
      hostConnection: machine.hostCard == null
          ? null
          : () => switch (tunnels.of(machine)?.state) {
              TunnelState.up =>
                tunnels.of(machine)?.vaultState == HostUnlockState.waitingForKey
                    ? HostReachability.waitingForKey
                    : HostReachability.reached,
              TunnelState.waitingForKey => HostReachability.waitingForKey,
              _ => HostReachability.notReached,
            },
      hostRefusal: machine.hostCard == null
          ? null
          : () => tunnels.of(machine)?.problem ?? tunnels.of(machine)?.vaultProblem,
    );
    // Not simply `_notify`: a managed machine that stops answering is a forward that dropped, and
    // nobody should have to ask for it to come back.
    fleet.addListener(() {
      _notify();
      if (fleet.reachability == Reachability.connected) _raiseHolds.remove(machine.name);
      if (fleet.reachability == Reachability.unreachable) {
        // A card's asked try has raised already, in its connect; a forward's raise is this one.
        final asked = fleet.takeAskedTry() && machine.hostCard == null;
        unawaited(raiseAgainIfNeeded(machine, asked: asked));
      }
    });
    _watching[machine.name] = fleet;
    if (_automaticRetriesPaused) fleet.pauseAutomaticRetry();
    unawaited(_openAndConnect(machine, fleet));
  }

  /// Raises the way in, if this interface owns it, and then connects.
  ///
  /// A machine somebody else forwarded goes straight to connecting: [Tunnels.raiseFor] answers
  /// true for it without starting anything.
  Future<void> _openAndConnect(Machine machine, FleetModel fleet) async {
    if (machine.disconnected) return;
    if (machine.kind == 'host' && machine.hostCard == null && machine.identity.isNotEmpty) {
      return;
    }
    if (machine.hostCard == null) _raiseEnded(machine, up: await tunnels.raiseFor(machine));
    // That was this opening's raise; a card's is in the connect, which goes as asked.
    await fleet.connect(onItsOwn: machine.hostCard == null);
    _notify();
    await _askWhichNode(machine, fleet);
  }

  /// Asks a machine which node it is, once it is answering.
  ///
  /// **Two entries can be one node and nothing else can tell.** A hostname has many spellings, and
  /// a socket somebody else forwarded looks nothing like a tunnel this interface raised to the
  /// same place — so this is asked rather than worked out. What it prevents is not cosmetic: the
  /// same node twice delivers every clearance question twice, and answering one leaves the other
  /// on screen until it expires.
  Future<void> _askWhichNode(Machine machine, FleetModel fleet) async {
    // **Only a machine that answered.** Asking one that never opened raises a state error rather
    // than a disconnection — it is a question about a socket that was never there, not a socket
    // that went away.
    if (_disposed || fleet.reachability != Reachability.connected) return;
    try {
      final id = await fleet.backend.node();
      if (_disposed) return;
      // Recorded as it came, empty included. **The rule that empty is not an identity lives in
      // one place** — the comparison, where it means something — because a second copy of it here
      // would cover for that one and leave both untested. Found by mutation: removing the guard
      // in `sameNodeAs` broke nothing while this one stood.
      _nodes[machine.name] = id;
      _notify();
    } on VarlinkException {
      // Refused by name: absence again, never an identity made up here.
    } on VarlinkDisconnected {
      // It stopped answering. Nothing to record, and nothing worth saying about it here: the
      // machine already reads as unreachable.
    } on FeatureNotSupported {
      // A daemon older than the method. Absence is the honest state, and the alternative — an
      // empty id kept as a value — would report every such machine as the same node.
    }
  }

  /// Raises a dropped forward again and reconnects over it.
  ///
  /// Without being asked: a forward that goes away is not a decision anybody made. Only for one
  /// this interface raised, and only for a machine that is not answering — a working connection
  /// is never disturbed to check on the thing underneath it.
  Future<void> raiseAgainIfNeeded(Machine machine, {bool asked = false}) async {
    if (machine.disconnected) return;
    if (!asked && _raiseHeld(machine) != null) return;
    if (machine.kind == 'host' && machine.hostCard == null && machine.identity.isNotEmpty) {
      return;
    }
    if (!tunnels.manages(machine)) return;
    final fleet = _watching[machine.name];
    if (fleet == null || fleet.reachability == Reachability.connected) return;
    // Reconnecting moves the fleet, which notifies, which lands back here. One at a time per
    // machine, or a forward that cannot be raised becomes a loop that never stops trying.
    if (!_raisingAgain.add(machine.name)) return;
    try {
      await tunnels.raiseAgainIfItDropped(machine);
      final up = tunnels.of(machine)?.state == TunnelState.up;
      _raiseEnded(machine, up: up);
      if (up) await fleet.connect();
    } finally {
      _raisingAgain.remove(machine.name);
    }
    _notify();
  }

  /// Takes down every forward this interface raised.
  ///
  /// Closing the window leaves nothing running and no socket behind — and touches nothing
  /// somebody else raised, because nothing of theirs is in [tunnels].
  Future<void> letGoOfTheTunnels() => tunnels.dropEverything();

  Future<void> _remember() => _settings.rememberMachines(<Machine>[
    for (final machine in _machines)
      // The entry naming no distribution is never stored: it stands only until one is found.
      if (!_passing.contains(machine.name) && !(machine.kind == 'wsl' && machine.distribution.isEmpty)) machine,
  ]);

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final fleet in _watching.values) {
      fleet.dispose();
    }
    _watching.clear();
    super.dispose();
  }
}

/// Every project on [machine], with its permanent default before the daemon's first answer.
List<ProjectOnScreen> projectsOnMachine(Machines machines, Machine machine) {
  final local = machines.all.contains(machine)
      ? machines.watching(machine)?.projects ?? <ProjectOnScreen>[]
      : <ProjectOnScreen>[];
  final projects = <String, ProjectOnScreen>{for (final project in local) project.name: project};
  projects.putIfAbsent(
    defaultProject,
    () => ProjectOnScreen(project: Project.from({'name': defaultProject}), tasks: const []),
  );
  return projects.values.toList();
}

/// The machines watched, with this computer always among them.
List<Machine> listedMachines(Machines machines) {
  final all = <Machine>[...machines.all];
  final local = Machine.local();
  if (desk.isWindows) {
    if (!all.any((machine) => machine.isAlwaysListed)) all.add(local);
  } else if (!all.any(
    // Names tell machines apart, in the side bar too: one already named so is not joined by a second.
    (machine) => machine.socketPath == local.socketPath && !machine.needsATunnel || machine.name == local.name,
  )) {
    all.add(local);
  }
  return all;
}
