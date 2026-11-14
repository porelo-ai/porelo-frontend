import 'dart:async';
import 'dart:io';

import 'package:porelo_host/porelo_host.dart' show HostCardSsh, HostFiles, HostFilesRefused;

import 'ssh_words.dart';
import 'desk.dart';
import 'fleet_model.dart' show Reachability;
import 'host_follow.dart';
import 'host_progress.dart';
import 'machines.dart';
import 'organization_source.dart';
import 'tunnel.dart';

/// One connection per host, written from the organization's card as a host card always was: `frontend.json`'s machine
/// and `porelo/ssh/<host>.conf`, `.known_hosts` and `.pub` beside it. No credential is kept or shown.
class CardHostConnections extends HostConnections {
  /// Reads hosts from [organization] and connects through [machines]; [publicKey] is the person's own public key, whose
  /// private half stays in their agent, and [hostProgress] asks a connected host how it stands.
  CardHostConnections({
    required this.organization,
    required this.machines,
    required this.publicKey,
    SshHostProgress? hostProgress,
    SshHostFollow? hostFollow,
    String Function(String host)? endpoint,
    Future<bool> Function(int port, String host)? forgeProbe,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       _progress = hostProgress ?? SshHostProgress(),
       _follow = hostFollow ?? SshHostFollow(),
       _endpoint = endpoint ?? Machine.endpointFor,
       _forgeProbe = forgeProbe ?? ((port, host) => forgeAnswersAt(port, hostName: '$host.localhost')) {
    machines.addListener(notifyListeners);
    machines.addListener(_turnedAway);
    machines.tunnels.addListener(_turnedAway);
  }

  /// The hosts turned away while this computer raised their connection by itself, asked once each whether they wait
  /// for a first token, until the connection comes up or is let go.
  final Set<String> _askedWhenTurnedAway = <String>{};

  /// A connection raised again by itself, not by *Connect*, and turned away: the machine may wait for its first token,
  /// which only its host admin can give, and the row says so rather than a refusal or a wait that never ends.
  void _turnedAway() {
    if (_disposed) return;
    final me = organization.view?.me;
    for (final machine in machines.all) {
      final card = machine.hostCard;
      if (card == null || card.login != me) continue;
      final turned = machines.tunnels.of(machine)?.turnedAway ?? false;
      if (!turned) {
        _askedWhenTurnedAway.remove(card.name);
        continue;
      }
      if (_waiting.contains(card.name) || _running.containsKey(card.name)) continue;
      if (!_askedWhenTurnedAway.add(card.name)) continue;
      unawaited(
        _waitsForToken(machine, card.name).then((waits) {
          if (!waits || _disposed || _waiting.contains(card.name)) return;
          _waiting.add(card.name);
          notifyListeners();
        }),
      );
    }
  }

  /// Where hosts are read.
  final Organization organization;

  /// The machines this computer watches.
  final Machines machines;

  /// The person's own public key.
  final Future<String> Function() publicKey;

  final SshHostProgress _progress;

  final SshHostFollow _follow;

  final String Function(String host) _endpoint;

  final Future<bool> Function(int port, String host) _forgeProbe;

  final DateTime Function() _now;

  /// When each host's forge forward was last raised anew: not again within [_raiseAgainAfter].
  final _raisedAt = <String, DateTime>{};

  static const _raiseAgainAfter = Duration(seconds: 30);

  /// This person's machine of [host], or null. A machine of the same name that is no card of theirs is not one.
  Machine? _machine(String host) {
    final me = organization.view?.me;
    return machines.all.where((machine) => machine.hostCard?.name == host && machine.hostCard?.login == me).firstOrNull;
  }

  @override
  bool connected(String host) {
    final machine = _machine(host);
    final card = machine?.hostCard;
    return card != null && !machine!.disconnected && !_movedPast(card);
  }

  @override
  String? forgeUrl(String host) => connected(host) ? _machine(host)?.hostCard?.forgeUrl : null;

  @override
  Future<bool?> forgeAnswers(String host) async {
    final port = up(host) ? _machine(host)?.hostCard?.webPort : null;
    if (port == null) return null;
    return _forgeProbe(port, host);
  }

  @override
  Future<void> raiseForwardAnew(String host) async {
    final machine = _machine(host);
    if (machine == null || !connected(host)) {
      throw OrganizationRefused('This computer is not connected to $host, so it has no forward to raise anew.');
    }
    if (!up(host)) {
      throw OrganizationRefused('The connection to $host is down; Connect brings it back, with its forge.');
    }
    final last = _raisedAt[host];
    if (last != null && _now().difference(last) < _raiseAgainAfter) {
      throw OrganizationRefused(
        "The forward to $host's forge was raised anew moments ago and it still gives no answer: its cause is on the "
        'host.',
      );
    }
    _raisedAt[host] = _now();
    // Only the forge's forward, on the master as it is: the person's terminals and the daemon's link stay.
    final why = await machines.tunnels.forwardTheForgeAnew(machine);
    if (!_disposed) notifyListeners();
    if (why != null) throw OrganizationRefused("The forward to $host's forge could not be raised anew: $why");
  }

  /// The hosts the last *Connect* found waiting for a first token.
  final Set<String> _waiting = <String>{};

  @override
  bool waitsForToken(String host) => _waiting.contains(host) && connected(host) && !up(host);

  /// What the machine now says of the token is what stands, whoever gave it and from where.
  HostProgress _heard(String host, HostProgress progress) {
    if (!progress.waitsForToken) _waiting.remove(host);
    // Kept for every page that shows it, which hears of it so.
    return keepHeard(host, progress);
  }

  @override
  bool waitsForAdmission(String host) {
    final machine = _machine(host);
    return connected(host) && !up(host) && (machines.tunnels.of(machine!)?.admitting ?? false);
  }

  @override
  bool up(String host) {
    final machine = _machine(host);
    return connected(host) && machines.tunnels.of(machine!)?.state == TunnelState.up;
  }

  /// Whether the organization now names another address, host key, port or key of mine than [card] was written from:
  /// then it is a connection to replace, which only *Connect* does. What the answer leaves out says nothing.
  bool _movedPast(HostCardSsh card) {
    final view = organization.view;
    final entry = view?.hosts.where((each) => each.name == card.name).firstOrNull;
    if (view == null) return false;
    if (entry == null) return true;
    final mine = view.persons.where((person) => person.login == view.me).firstOrNull?.key;
    return (entry.address != null && entry.address != card.address) ||
        (entry.port != null && entry.port != card.sshPort) ||
        (entry.hostKey != null && entry.hostKey != card.hostKey) ||
        (mine != null && mine != HostFiles.signingFingerprint(card.publicKey));
  }

  final _attempts = <String, ConnectAttempt>{};

  @override
  ConnectAttempt? lastAttempt(String host) => _attempts[host];

  /// The *Connect* running for each host: a second press joins it, as two would raise one tunnel twice.
  final _running = <String, Future<void>>{};
  bool _disposed = false;

  @override
  Future<void> connect(String host) => _running[host] ??= _attempt(host).whenComplete(() {
    // In a block: a callback answering this very future would wait for itself.
    _running.remove(host);
  });

  Future<void> _attempt(String host) async {
    final lines = <String>[];
    _attempts[host] = ConnectAttempt(DateTime.now(), lines);
    try {
      await _connect(host, lines);
    } on OrganizationRefused catch (refused) {
      lines.add('It ended unconnected: ${refused.words}');
      rethrow;
    } on Exception catch (error) {
      lines.add('It ended unconnected: $error');
      throw OrganizationRefused('The connection to $host could not be set up: $error');
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _connect(String host, List<String> lines) async {
    final card = await _card(host);
    lines.add('The organization names ${card.name} at ${card.address}, ssh port ${card.sshPort}.');
    final known = _machine(host);
    _forgetFollow(card.name);
    final letGo = (count: _letGo[card.name] ?? 0, off: _disconnected(card.name));
    // Connected already with what the organization names: nothing to do, whatever number of projects it carries.
    if (known?.hostCard == card && machines.tunnels.of(known!)?.state == TunnelState.up) {
      _waiting.remove(card.name);
      lines.add('This computer is connected already with what the organization names.');
      return;
    }
    final machine = Machine.fromHostCard(
      card,
      // On Windows the daemon goes through the relay: there is no local socket, nor a runtime folder for one.
      socketPath: desk.isWindows ? '' : _endpoint(card.name),
      // A server this computer prepared stays one it can give back.
      hostProject: machines.settings.hostUp(card.name) == null ? '' : card.name,
      sshConfig: card.configPath(
        environment: machines.tunnels.configEnvironment ?? desk.environment,
        windows: desk.isWindows,
      ),
    );
    // The same connection is raised where it stands: listed, its files kept, as a machine just prepared waits for its
    // follow or its token. Another is taken down and made anew.
    final again = known != null && known == machine;
    if (known != null && !again) {
      lines.add('A connection kept here is taken down and made anew.');
      await machines.tunnels.dropAndUnpublish(known);
      await machines.forget(known);
    }
    // A new host makes no account before it has a token, and a host admin gives it that as root: the connection's
    // files stay for that, and *Connect* is asked again after it.
    lines.add('Opening the connection.');
    final raised = await machines.tunnels.raiseFor(machine);
    if (await _letGoMeanwhile(card.name, letGo, machine, again: again)) return;
    if (raised) {
      _waiting.remove(card.name);
      // It makes the account that let this person in only once it had its token.
      hearTokenWait(card.name, waits: false);
      lines.add('The connection is up.');
    } else {
      if (machines.tunnels.of(machine)?.problem case final problem?) lines.add('ssh said: $problem');
      // The token first: a machine waiting for it makes no account however long one waits for its follow.
      final waits = await _waitsForToken(machine, card.name);
      if (await _letGoMeanwhile(card.name, letGo, machine, again: again)) return;
      if (waits) {
        _waiting.add(card.name);
        lines.add('${card.name} says it waits for its first token, and makes no account before it has one.');
      } else if (machines.tunnels.of(machine)?.admitting ?? false) {
        _waiting.remove(card.name);
        // Kept, as for the token: the machine makes the account on its first follow, and this computer tries again.
        lines.add(
          '${card.name} was prepared moments ago and has not yet made your account; it does on its first '
          'follow, within five minutes.',
        );
      } else {
        _waiting.remove(card.name);
        final why =
            machine.whyNotReachableHere ??
            sshRefusalWords(machines.tunnels.of(machine)?.problem) ??
            'The connection to ${card.name} could not be opened.';
        // What watched the entry goes first, so nothing raises it again once its files are taken down.
        if (again) await machines.forget(known);
        await machines.tunnels.dropAndUnpublish(machine);
        throw OrganizationRefused(why);
      }
    }
    // Listed and saved as it stands.
    if (again) return;
    var saved = false;
    try {
      await machines.add(machine);
      saved = await machines.settings.holdsMachine(machine);
    } on Exception {
      // Said below.
    }
    if (!saved) {
      // Nothing is left up that this computer does not know of, and the row offers *Connect* again.
      await machines.tunnels.dropAndUnpublish(machine);
      try {
        await machines.forget(machine);
      } on Exception {
        // The save failing again: the machine is out of the list, which is what this asked.
      }
      throw OrganizationRefused('This computer could not save the connection to ${card.name}, so it was closed.');
    }
  }

  bool _disconnected(String host) => machines.all.any((each) => each.name == host && each.disconnected);

  /// Each host's connection let go, counted: a *Connect* still on its way then adds and takes off nothing.
  final _letGo = <String, int>{};

  /// Whether [host]'s connection was let go since a *Connect* began at [letGo], here or on its row; then the
  /// connection that *Connect* raised is taken down again, unless it is the entry [again] kept, which the disconnect
  /// took down itself.
  Future<bool> _letGoMeanwhile(
    String host,
    ({int count, bool off}) letGo,
    Machine machine, {
    required bool again,
  }) async {
    if (!_disposed && (_letGo[host] ?? 0) == letGo.count && (letGo.off || !_disconnected(host))) return false;
    if (!again) await machines.tunnels.dropAndUnpublish(machine);
    return true;
  }

  /// Whether [host] says, to its host admin as root, that it waits for its first token.
  Future<bool> _waitsForToken(Machine machine, String host) async {
    final view = organization.view;
    final entry = view?.hosts.where((each) => each.name == host).firstOrNull;
    if (view == null || entry == null || !entry.admins.contains(view.me)) return false;
    try {
      final waits = (await _progress.status(machine.sshConfig, host)).waitsForToken;
      // The last word of the token for the machine's page, kept while this computer is not connected.
      hearTokenWait(host, waits: waits);
      return waits;
    } on OrganizationRefused {
      return false;
    }
  }

  /// The card [host]'s connection is written from, or the words of what is missing.
  Future<HostCardSsh> _card(String host) async {
    // The state Porelo kept is shown while its check runs: a connection waits for the check rather than refuse.
    if ((organization.view?.stale ?? false) && organization.reading) await organization.newestRead();
    final view = organization.view;
    final entry = view?.hosts.where((each) => each.name == host).firstOrNull;
    if (view == null || entry == null) throw OrganizationRefused('The organization names no machine $host.');
    if (view.stale) {
      throw OrganizationRefused(
        'The Porelo organization could not be read just now, so no connection to $host was made.',
      );
    }
    final (address, port, hostKey) = (entry.address, entry.port, entry.hostKey);
    final (web, git, matrix) = (entry.webPort, entry.gitPort, entry.matrixPort);
    if (address == null || port == null || hostKey == null) {
      throw OrganizationRefused('The Machine Admin of $host has not entered its address and SSH host key yet.');
    }
    final String key;
    try {
      key = await publicKey();
    } on Exception {
      throw const OrganizationRefused(
        'Your own key could not be read from your identity, so no machine was connected.',
      );
    }
    try {
      return HostCardSsh(
        name: host,
        address: address,
        sshPort: port,
        hostKey: hostKey,
        login: view.me,
        publicKey: key,
        webPort: web,
        gitPort: git,
        matrixPort: matrix,
      );
    } on HostFilesRefused catch (refused) {
      throw OrganizationRefused(refused.message);
    } on FormatException catch (refused) {
      throw OrganizationRefused(refused.message);
    }
  }

  @override
  Future<void> disconnect(String host) async {
    final machine = _machine(host);
    _letGo[host] = (_letGo[host] ?? 0) + 1;
    _waiting.remove(host);
    _attempts.remove(host);
    _forgetFollow(host);
    if (machine == null) return;
    await machines.disconnect(machine);
    notifyListeners();
  }

  @override
  Future<HostProgress> refresh(String host) async => _heard(host, await _progress.refresh(_config(host), host));

  @override
  Future<HostProgress> progress(String host) async => _heard(host, await _progress.status(_config(host), host));

  /// Whether each host offers the start of its read of the organization, as asked once per connection: the reason it
  /// does not, or null where it does.
  final _followOffered = <String, String?>{};

  /// The ask of each host on its way, which a second ask of the same connection joins.
  final _askingFollow = <String, Future<String?>>{};

  /// Each host's connection, counted: an answer to an earlier one, or one that went down meanwhile, stands for nothing.
  final _followGeneration = <String, int>{};

  /// Forgets what [host] was told of the start, and every answer still on its way: its connection changed.
  void _forgetFollow(String host) {
    _followGeneration[host] = (_followGeneration[host] ?? 0) + 1;
    _followOffered.remove(host);
    _askingFollow.remove(host);
  }

  /// Whether an answer asked at [generation] still stands for [host]'s connection.
  bool _stillStands(String host, int generation) => !_disposed && _followGeneration[host] == generation && up(host);

  static String _connectFirst(String host) => 'Connect first: $host is asked through your own account on it.';

  @override
  String? whyNotFollowNow(String host) {
    final machine = _machine(host);
    if (machine == null || !up(host)) {
      // A connection down tells nothing of the next: its answer is asked again once it is up.
      if (_followOffered.containsKey(host) || _askingFollow.containsKey(host)) _forgetFollow(host);
      return _connectFirst(host);
    }
    if (_followOffered.containsKey(host)) return _followOffered[host];
    unawaited(_offered(machine, host));
    return 'Asking $host whether it offers this…';
  }

  /// Whether [host] offers the start, asked once per connection and kept while it stands.
  Future<String?> _offered(Machine machine, String host) {
    if (_askingFollow[host] case final asking?) return asking;
    final generation = _followGeneration[host] ?? 0;
    late final Future<String?> asking;
    asking = () async {
      final why = await _follow.whyNotOffered(machine, host);
      if (identical(_askingFollow[host], asking)) _askingFollow.remove(host);
      if (_stillStands(host, generation)) {
        _followOffered[host] = why;
        notifyListeners();
      }
      return why;
    }();
    return _askingFollow[host] = asking;
  }

  @override
  Future<String> followNow(String host) async {
    final machine = _machine(host);
    if (machine == null || !up(host)) throw OrganizationRefused(_connectFirst(host));
    final generation = _followGeneration[host] ?? 0;
    // A host greyed, or not asked yet, runs nothing before it is known to offer the start.
    if (!_followOffered.containsKey(host)) await _offered(machine, host);
    if (!_stillStands(host, generation)) {
      throw OrganizationRefused('The connection to $host changed meanwhile, so nothing was asked of it.');
    }
    if (_followOffered[host] case final why?) throw HostFollowUnavailable(why);
    try {
      return await _follow.follow(machine, host);
    } on HostFollowUnavailable catch (unavailable) {
      // Not offered again until the connection is made anew, as with an updated host.
      if (_stillStands(host, generation)) {
        _followOffered[host] = unavailable.words;
        notifyListeners();
      }
      rethrow;
    }
  }

  /// The person's own daemon on [host] answers it in its `Projects`, as the host's follow measured it; what it cannot
  /// be asked, or leaves unsaid, cannot say.
  @override
  Future<CentralState> central(String host, String project) async {
    final machine = _machine(host);
    if (machine == null || !up(host)) return const CentralState();
    // A machine listed and not watched yet, as while it reconnects, cannot be asked.
    final fleet = machines.watching(machine);
    if (fleet == null) return const CentralState();
    try {
      // The connection can be up before the daemon's connection over it has opened.
      await fleet.untilAsked();
      if (fleet.reachability != Reachability.connected) return const CentralState();
      final listed = await fleet.backend.projects();
      final row = listed.where((each) => each.name == project).firstOrNull;
      return row == null ? const CentralState() : CentralState.fromRepositories(row.repositoryStates);
    } on Exception {
      return const CentralState();
    } on StateError {
      // Porelo's own backend says so of a connection not open (yet or again).
      return const CentralState();
    }
  }

  String _config(String host) {
    final machine = _machine(host);
    if (machine == null) throw OrganizationRefused('Connect to $host first.');
    if (!connected(host)) throw OrganizationRefused('The organization has changed $host: connect to it again first.');
    return machine.sshConfig;
  }

  @override
  void dispose() {
    _disposed = true;
    machines.removeListener(notifyListeners);
    machines.removeListener(_turnedAway);
    machines.tunnels.removeListener(_turnedAway);
    super.dispose();
  }
}

/// Whether a forge answers at [port] on this computer's loopback, where a forward ends: any byte back is an answer, while
/// an empty reply, a refused connection or silence until [deadline] is none.
Future<bool> forgeAnswersAt(
  int port, {
  String? hostName,
  Duration deadline = const Duration(seconds: 5),
  Future<Socket> Function(int port)? connect,
}) async {
  Socket? socket;
  final connecting = (connect ?? (port) => Socket.connect(InternetAddress.loopbackIPv4, port))(port);
  // One deadline for connecting, asking and the first byte together.
  Future<bool> ask() async {
    final open = socket = await connecting;
    open.write('HEAD / HTTP/1.1\r\nHost: ${hostName ?? '127.0.0.1'}:$port\r\nConnection: close\r\n\r\n');
    await open.flush();
    return (await open.first).isNotEmpty;
  }

  try {
    return await ask().timeout(deadline);
  } on TimeoutException {
    // A connection that comes after the deadline is ended as it comes.
    connecting.then((late) => late.destroy(), onError: (_) {}).ignore();
    return false;
  } on SocketException {
    return false;
  } on StateError {
    // The forward took the connection and closed it with nothing said: the browser's empty reply.
    return false;
  } finally {
    socket?.destroy();
  }
}
