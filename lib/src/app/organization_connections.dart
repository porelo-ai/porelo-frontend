import 'package:porelo_host/porelo_host.dart' show HostCardSsh, HostFiles, HostFilesRefused;

import 'ssh_words.dart';
import 'desk.dart';
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
    String Function(String host)? endpoint,
  }) : _progress = hostProgress ?? SshHostProgress(),
       _endpoint = endpoint ?? Machine.endpointFor {
    machines.addListener(notifyListeners);
  }

  /// Where hosts are read.
  final Organization organization;

  /// The machines this computer watches.
  final Machines machines;

  /// The person's own public key.
  final Future<String> Function() publicKey;

  final SshHostProgress _progress;

  final String Function(String host) _endpoint;

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

  /// The hosts the last *Connect* found waiting for a first token.
  final Set<String> _waiting = <String>{};

  @override
  bool waitsForToken(String host) => _waiting.contains(host) && connected(host) && !up(host);

  /// What the machine now says of the token is what stands, whoever gave it and from where.
  HostProgress _heard(String host, HostProgress progress) {
    if (!progress.waitsForToken && _waiting.remove(host)) notifyListeners();
    return progress;
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

  @override
  Future<void> connect(String host) async {
    final card = await _card(host);
    final known = _machine(host);
    _waiting.remove(card.name);
    // Connected already with what the organization names: nothing to do, whatever number of projects it carries.
    if (known?.hostCard == card && machines.tunnels.of(known!)?.state == TunnelState.up) return;
    if (known != null) {
      await machines.tunnels.dropAndUnpublish(known);
      await machines.forget(known);
    }
    final machine = Machine.fromHostCard(
      card,
      socketPath: _endpoint(card.name),
      // A server this computer prepared stays one it can give back.
      hostProject: machines.settings.hostUp(card.name) == null ? '' : card.name,
      sshConfig: card.configPath(
        environment: machines.tunnels.configEnvironment ?? desk.environment,
        windows: desk.isWindows,
      ),
    );
    // A new host makes no account before it has a token, and a host admin gives it that as root: the connection's
    // files stay for that, and *Connect* is asked again after it.
    if (!await machines.tunnels.raiseFor(machine)) {
      if (await _waitsForToken(machine, card.name)) {
        _waiting.add(card.name);
      } else {
        final why =
            machine.whyNotReachableHere ??
            sshRefusalWords(machines.tunnels.of(machine)?.problem) ??
            'The connection to ${card.name} could not be opened.';
        await machines.tunnels.dropAndUnpublish(machine);
        throw OrganizationRefused(why);
      }
    }
    var saved = false;
    try {
      await machines.add(machine);
      saved = await machines.settings.holdsMachine(machine.name);
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
    notifyListeners();
  }

  /// Whether [host] says, to its host admin as root, that it waits for its first token.
  Future<bool> _waitsForToken(Machine machine, String host) async {
    final view = organization.view;
    final entry = view?.hosts.where((each) => each.name == host).firstOrNull;
    if (view == null || entry == null || !entry.admins.contains(view.me)) return false;
    try {
      return (await _progress.status(machine.sshConfig, host)).waitsForToken;
    } on OrganizationRefused {
      return false;
    }
  }

  /// The card [host]'s connection is written from, or the words of what is missing.
  Future<HostCardSsh> _card(String host) async {
    final view = organization.view;
    final entry = view?.hosts.where((each) => each.name == host).firstOrNull;
    if (view == null || entry == null) throw OrganizationRefused('The organization names no machine $host.');
    if (view.stale) {
      throw OrganizationRefused('The organization could not be read just now, so no connection to $host was made.');
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
    _waiting.remove(host);
    if (machine == null) return;
    await machines.disconnect(machine);
    notifyListeners();
  }

  @override
  Future<HostProgress> refresh(String host) async => _heard(host, await _progress.refresh(_config(host), host));

  @override
  Future<HostProgress> progress(String host) async => _heard(host, await _progress.status(_config(host), host));

  @override
  Future<CentralState> central(String host, String project) async =>
      connected(host) ? _progress.central(_config(host), host, project) : const CentralState();

  String _config(String host) {
    final machine = _machine(host);
    if (machine == null) throw OrganizationRefused('Connect to $host first.');
    if (!connected(host)) throw OrganizationRefused('The organization has changed $host: connect to it again first.');
    return machine.sshConfig;
  }

  @override
  void dispose() {
    machines.removeListener(notifyListeners);
    super.dispose();
  }
}
