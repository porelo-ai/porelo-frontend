import 'dart:convert';

import 'package:porelo_frontend/client.dart';
import 'package:porelo_host/porelo_host.dart' show HostCardSsh, checkAdminName;

import 'desk.dart';
import 'fleet_backend.dart';
import 'identity.dart';
import 'machines.dart';
import 'project_join.dart';
import 'registry.dart';
import 'registry_checkout.dart';
import 'registry_read_source.dart';
import 'run_here.dart';

/// What the app hands its shell to join with, both as the person Core's identity names.
///
/// Discovery reads the registry checkout [registry] reads for the pages, never a second one; a join's tunnel is
/// raised through [machines]' own tunnels.
({CoreJoinDiscovery discovery, DaemonJoinHost host}) appJoins({
  required RegistryReadSource registry,
  required Machines machines,
  Identity? identity,
  RunHere? run,
}) {
  final person = identity ?? Identity(run: run);
  return (
    discovery: CoreJoinDiscovery(
      checkout: () => registry.registry?.checkout,
      login: () async => (await person.show()).login,
      run: run,
    ),
    host: DaemonJoinHost(connect: cardTunnel(machines, publicKey: () async => (await person.show()).key)),
  );
}

/// The card a join's tunnel is written from: Core's verified host card, the row's host account and the person's
/// own public key, whose private half stays in their agent.
HostCardSsh joinCard(JoinOffered offer, String publicKey) => HostCardSsh(
  name: offer.host.name,
  address: offer.host.address,
  sshPort: offer.host.sshPort,
  hostKey: offer.host.sshHostKey,
  login: offer.login,
  publicKey: publicKey,
  webPort: offer.host.services['forge']!['web_port']!,
  gitPort: offer.host.services['forge']!['git_port']!,
  matrixPort: offer.host.services['matrix']!['port']!,
);

/// Raises a joinable row's card tunnel through [machines]' tunnels and names the account it reaches; the account is
/// watched only once the join is confirmed.
///
/// [endpoint] is where the daemon's local end goes for a host, under the runtime directory unless a test says.
Future<Machine> Function(JoinOffered offer) cardTunnel(
  Machines machines, {
  required Future<String> Function() publicKey,
  String Function(String host)? endpoint,
}) => (offer) async {
  final String key;
  try {
    key = await publicKey();
  } on Exception {
    throw const RegistryRefusal('Your own key could not be read from your identity, so no host was connected.');
  }
  final card = joinCard(offer, key);
  final machine = Machine.fromHostCard(
    card,
    socketPath: (endpoint ?? Machine.endpointFor)(card.name),
    sshConfig: card.configPath(
      environment: machines.tunnels.configEnvironment ?? desk.environment,
      windows: desk.isWindows,
    ),
  );
  if (!await machines.tunnels.raiseFor(machine)) {
    throw RegistryRefusal(
      machine.whyNotReachableHere ??
          machines.tunnels.of(machine)?.problem ??
          'The tunnel to ${card.name} could not be opened.',
    );
  }
  return machine;
};

/// Core's `porelo registry joinable` on the person's private registry checkout, for the person Core names.
class CoreJoinDiscovery implements JoinDiscovery {
  /// Takes the registry checkout, who the person is, and an argument-list process runner.
  CoreJoinDiscovery({required this.checkout, required this.login, RunHere? run}) : _run = run ?? runHere;

  /// The private checkout of the registry Core reads, or null before a registry was chosen.
  final RegistryCheckout? Function() checkout;

  /// The logged-in person's login as Core's identity names it, or null when there is none.
  final Future<String?> Function() login;

  final RunHere _run;

  @override
  Future<List<JoinAdmission>> admissions() async {
    final registry = checkout();
    if (registry == null) {
      throw const RegistryRefusal('Choose the registry repository first, so the projects you may join can be read.');
    }
    final person = await _login();
    final Ran result;
    try {
      result = await _run('porelo', ['registry', 'joinable', registry.folder, '--login', person, '--json']);
    } on Exception {
      throw const RegistryRefusal('Porelo could not be asked which projects you may join.');
    }
    switch (result.code) {
      case 0:
        final Object? json;
        try {
          json = jsonDecode(result.out);
        } on FormatException {
          throw const RegistryRefusal('Core\'s answer on the projects you may join could not be read.');
        }
        return readJoinable(json);
      case 65:
        throw const RegistryRefusal(
          'Core refused to say which projects you may join: the registry did not verify, or accepted no commit yet.',
        );
      case 66:
        throw const RegistryRefusal('The registry has not been read here yet, so no project you may join is known.');
      case 69:
        throw const RegistryRefusal('Core could not reach the registry or an access repository. Try again.');
      default:
        throw const RegistryRefusal('Core could not say which projects you may join.');
    }
  }

  /// The person's login, checked before it reaches a command line.
  Future<String> _login() async {
    String? person;
    try {
      person = await login();
    } on Exception {
      person = null;
    }
    try {
      if (person == null) throw const FormatException('no login');
      checkAdminName(person);
      return person;
    } on FormatException {
      throw const RegistryRefusal('Porelo knows no identity of yours yet, so no project you may join is known.');
    }
  }
}

/// The host side of a join: the card tunnel, and the account daemon's existing follow with Core's signers.
class DaemonJoinHost implements JoinHost {
  /// Takes the card tunnel's connect and how a watched account's daemon is reached.
  DaemonJoinHost({required this._connect, FleetBackend Function(Machine)? reach})
    : _reach = reach ?? ((machine) => PoreloBackend(Machines.backendFor(machine)));

  final Future<Machine> Function(JoinOffered offer) _connect;
  final FleetBackend Function(Machine) _reach;
  final Map<String, FleetBackend> _open = {};

  @override
  Future<Machine> connect(JoinOffered offer) => _connect(offer);

  @override
  Future<Followed?> followed(Machine machine, String project) async {
    final all = await _asking(machine, (daemon) => daemon.following());
    return all.where((each) => each.name == project).firstOrNull;
  }

  @override
  Future<Followed> follow(Machine machine, JoinOffered offer) =>
      _asking(machine, (daemon) => daemon.follow(offer.project, offer.source, signers: offer.signers));

  /// Asks the daemon over one opened connection, opened again after any failure so a retry reads the host anew.
  Future<T> _asking<T>(Machine machine, Future<T> Function(FleetBackend daemon) ask) async {
    final key = machine.socketPath;
    try {
      var daemon = _open[key];
      if (daemon == null) {
        daemon = _reach(machine);
        await daemon.open();
        _open[key] = daemon;
      }
      return await ask(daemon);
    } on Object {
      _open.remove(key);
      rethrow;
    }
  }
}
