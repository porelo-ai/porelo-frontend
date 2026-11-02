import 'package:porelo_host/porelo_host.dart' show HostCardSsh, HostFiles, HostFilesRefused;

import 'desk.dart';
import 'host_progress.dart';
import 'machines.dart';
import 'organization_source.dart';

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
    final card = _machine(host)?.hostCard;
    return card != null && !_movedPast(card);
  }

  /// Whether the organization now names another address, host key, port or key of mine than [card] was written from:
  /// then it is a connection to replace, which only *Connect* does. What the answer leaves out says nothing.
  bool _movedPast(HostCardSsh card) {
    final view = organization.view;
    final entry = view?.hosts.where((each) => each.name == card.name).firstOrNull;
    if (view == null || entry == null) return false;
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
    // Connected already with what the organization names: nothing to do, whatever number of projects it carries.
    if (known?.hostCard == card) return;
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
    if (!await machines.tunnels.raiseFor(machine)) {
      final why =
          machine.whyNotReachableHere ??
          machines.tunnels.of(machine)?.problem ??
          'The connection to ${card.name} could not be opened.';
      await machines.tunnels.dropAndUnpublish(machine);
      throw OrganizationRefused(why);
    }
    try {
      await machines.add(machine);
    } on Exception {
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

  /// The card [host]'s connection is written from, or the words of what is missing.
  Future<HostCardSsh> _card(String host) async {
    final view = organization.view;
    final entry = view?.hosts.where((each) => each.name == host).firstOrNull;
    if (view == null || entry == null) throw OrganizationRefused('The organization names no host $host.');
    final (address, port, hostKey) = (entry.address, entry.port, entry.hostKey);
    final (web, git, matrix) = (entry.webPort, entry.gitPort, entry.matrixPort);
    if (address == null || port == null || hostKey == null) {
      throw OrganizationRefused('The host admin of $host has not entered its address and host key yet.');
    }
    final String key;
    try {
      key = await publicKey();
    } on Exception {
      throw const OrganizationRefused('Your own key could not be read from your identity, so no host was connected.');
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
    if (machine == null) return;
    await machines.forget(machine);
    await machines.tunnels.dropAndUnpublish(machine);
    notifyListeners();
  }

  @override
  Future<HostProgress> refresh(String host) async => _progress.refresh(_config(host), host);

  @override
  Future<HostProgress> progress(String host) async => _progress.status(_config(host), host);

  String _config(String host) => _machine(host)?.sshConfig ?? (throw OrganizationRefused('Connect to $host first.'));

  @override
  void dispose() {
    machines.removeListener(notifyListeners);
    super.dispose();
  }
}
