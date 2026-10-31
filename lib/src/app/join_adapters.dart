import 'dart:async';
import 'dart:convert';

import 'package:porelo_frontend/client.dart';
import 'package:porelo_host/porelo_host.dart' show HostCardSsh;

import 'desk.dart';
import 'fleet_backend.dart';
import 'identity.dart';
import 'machines.dart';
import 'project_join.dart';
import 'registry.dart';
import 'registry_read_source.dart';
import 'run_here.dart';
import 'tunnel.dart';

/// What the app hands its shell to join with, both as the person Core's identity names.
///
/// Discovery reads the registry checkout [registry] reads for the pages, never a second one; a join's tunnel is
/// raised through [machines]' own tunnels. Both use the person's card only while it may be used to join through that
/// registry ([whyCardUnusable]).
({CoreJoinDiscovery discovery, DaemonJoinHost host}) appJoins({
  required RegistryReadSource registry,
  required Machines machines,
  Identity? identity,
  RunHere? run,
}) {
  final person = identity ?? Identity(run: run);
  Future<IdentityCard> usable() async {
    final IdentityCard card;
    try {
      card = await person.show();
    } on RegistryRefusal {
      rethrow;
    } on NoIdentity {
      throw const RegistryRefusal('Porelo knows no identity of yours yet, so no project you may join is known.');
    } on Object {
      throw const RegistryRefusal(
        'Porelo\'s answer on your identity could not be read, so no project you may join is known. Try again.',
      );
    }
    final address = registry.registry?.checkout.repository;
    if (address == null) throw const RegistryRefusal(CoreJoinDiscovery.noRegistry);
    if (whyCardUnusable(card, address) case final why?) throw RegistryRefusal(why);
    return card;
  }

  return (
    discovery: CoreJoinDiscovery(
      registry: () => registry.registry,
      login: () async => (await usable()).login,
      run: run,
    ),
    host: DaemonJoinHost(
      connect: cardTunnel(
        machines,
        person: () async {
          final card = await usable();
          return (login: card.login, key: card.key);
        },
      ),
      current: (machine) async => machine.hostCard?.publicKey == (await usable()).key,
      raise: (machine) async {
        await machines.tunnels.raiseFor(machine);
      },
      ready: cardTunnelUp(machines),
      release: cardTunnelDown(machines),
    ),
  );
}

/// Why [card] cannot be used to join through the registry at [registry], or null when it can: its key must be
/// usable (not revoked, the card verified, the agent holding the key) and the card filed `done` in that registry.
String? whyCardUnusable(IdentityCard card, String registry) {
  if (card.whyKeyUnusable case final why?) return '$why No project can be joined with it.';
  final filed = card.registry.where((each) => each.address == registry);
  if (filed.length != 1 || filed.single.filed != FiledState.done) {
    return 'Your card is not accepted in the registry $registry yet, so no project you may join is known.';
  }
  return null;
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
/// [person] is the login and public key of the person's card now; a row for another login than theirs raises
/// nothing. A tunnel that does not come up is taken down with its published files. [endpoint] is where the daemon's
/// local end goes for a host, under the runtime directory unless a test says.
Future<Machine> Function(JoinOffered offer) cardTunnel(
  Machines machines, {
  required Future<({String login, String key})> Function() person,
  String Function(String host)? endpoint,
}) => (offer) async {
  final ({String login, String key}) own;
  try {
    own = await person();
  } on RegistryRefusal {
    rethrow;
  } on Exception {
    throw const RegistryRefusal('Your own key could not be read from your identity, so no host was connected.');
  }
  if (own.login != offer.login) {
    throw const RegistryRefusal(
      'This row was found for another login than your card names now. Look at the list again.',
    );
  }
  final card = joinCard(offer, own.key);
  // The watched account of this card reached with a key the person no longer uses gives its tunnel and its files up
  // to this one; it publishes them again when it is raised.
  for (final old in machines.all) {
    if (offer.reaches(old) && old.hostCard!.publicKey != own.key) await machines.tunnels.dropAndUnpublish(old);
  }
  final machine = Machine.fromHostCard(
    card,
    socketPath: (endpoint ?? Machine.endpointFor)(card.name),
    sshConfig: card.configPath(
      environment: machines.tunnels.configEnvironment ?? desk.environment,
      windows: desk.isWindows,
    ),
  );
  if (!await machines.tunnels.raiseFor(machine)) {
    final why =
        machine.whyNotReachableHere ??
        machines.tunnels.of(machine)?.problem ??
        'The tunnel to ${card.name} could not be opened.';
    if (!machines.all.contains(machine)) await cardTunnelDown(machines)(machine);
    throw RegistryRefusal(why);
  }
  return machine;
};

/// Whether a card machine's tunnel is up through [machines]' tunnels, with the ssh configuration this desktop
/// publishes for its card.
bool Function(Machine machine) cardTunnelUp(Machines machines) => (machine) {
  final card = machine.hostCard;
  return card != null &&
      machine.sshConfig ==
          card.configPath(
            environment: machines.tunnels.configEnvironment ?? desk.environment,
            windows: desk.isWindows,
          ) &&
      machines.tunnels.of(machine)?.state == TunnelState.up;
};

/// Takes down a card machine's tunnel in [machines]' tunnels and the files published for its card, so nothing of a
/// join that was not confirmed refuses the host's next card.
Future<void> Function(Machine machine) cardTunnelDown(Machines machines) =>
    (machine) => machines.tunnels.dropAndUnpublish(machine);

/// Core's `porelo registry joinable` on the person's private registry checkout, for the person Core names.
///
/// It asks only once the registry pages' read of that checkout has ended accepted, never while a fetch, a read or a
/// filing runs in it or a key replacement holds it.
class CoreJoinDiscovery implements JoinDiscovery {
  /// Takes the registry the pages read, who the person is, and an argument-list process runner.
  CoreJoinDiscovery({required this.registry, required this.login, RunHere? run}) : _run = run ?? runHere;

  /// What is said before a registry was chosen.
  static const noRegistry = 'Choose the registry repository first, so the projects you may join can be read.';

  /// The registry the pages read, or null before one was chosen.
  final Registry? Function() registry;

  /// The logged-in person's login as Core's identity names it, or null when there is none; a [RegistryRefusal] says
  /// why their card cannot be used to join.
  final Future<String?> Function() login;

  final RunHere _run;

  @override
  Future<List<JoinAdmission>> admissions() async {
    final registry = this.registry();
    if (registry == null) throw const RegistryRefusal(noRegistry);
    await _settled(registry);
    if (whyNotRead(registry) case final why?) throw RegistryRefusal(why);
    final person = await _login();
    final Ran result;
    try {
      result = await _run('porelo', ['registry', 'joinable', registry.checkout.folder, '--login', person, '--json']);
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
        return readJoinable(json, login: person);
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

  /// Why [registry] was not read far enough to join through, or null when its last read ended with an accepted
  /// revision.
  ///
  /// A commit Core refused beside the accepted revision leaves that revision read: Core answers what it accepted, and
  /// a host whose access file it refused as that host's own row. A read that answered no accepted revision, or a fetch
  /// or read that failed, leaves nothing to join through.
  static String? whyNotRead(Registry registry) {
    if (registry.accepted?.revision == null) {
      return 'The registry has no accepted revision here yet, so the projects you may join are not known. '
          '${registry.problem ?? 'Refresh it.'}';
    }
    final problem = registry.problem;
    if (problem == null) return null;
    // The words of a read that ended with a refused commit beside the accepted revision, as the registry says them.
    final refused = registry.refusedCommit;
    if (refused != null &&
        refused.commit.length >= 12 &&
        problem.startsWith('Porelo refused commit ${refused.commit.substring(0, 12)} at ${refused.path}: ')) {
      return null;
    }
    return 'The registry has not been read here completely, so the projects you may join are not known. $problem';
  }

  /// Waits until no fetch, read or filing runs in [registry] and no key replacement holds it.
  static Future<void> _settled(Registry registry) async {
    while (registry.busy || registry.held) {
      final changed = Completer<void>();
      void moved() {
        if (!changed.isCompleted) changed.complete();
      }

      registry.addListener(moved);
      try {
        await changed.future;
      } finally {
        registry.removeListener(moved);
      }
    }
  }

  /// The person's login, checked against Core's rule before it reaches a command line.
  Future<String> _login() async {
    String? person;
    try {
      person = await login();
    } on RegistryRefusal {
      rethrow;
    } on Exception {
      person = null;
    }
    if (person == null) {
      throw const RegistryRefusal('Porelo knows no identity of yours yet, so no project you may join is known.');
    }
    if (!RegExp(r'^[a-z][a-z0-9-]{0,31}$').hasMatch(person)) {
      throw const RegistryRefusal(
        'The login your card names is not one a host account takes (a lower-case letter first, then lower-case '
        'letters, digits or hyphens, at most 32), so no project can be joined with it.',
      );
    }
    return person;
  }
}

/// The host side of a join: the card tunnel, and the account daemon's existing follow with Core's signers.
class DaemonJoinHost implements JoinHost {
  /// Takes the card tunnel's connect, whether a card holds the person's key now, how a tunnel is raised again, whether
  /// one is up, how one is taken down, and how a watched account's daemon is reached.
  DaemonJoinHost({
    required this._connect,
    required this._current,
    required this._raise,
    required this._ready,
    required this._release,
    FleetBackend Function(Machine)? reach,
  }) : _reach = reach ?? ((machine) => PoreloBackend(Machines.backendFor(machine)));

  final Future<Machine> Function(JoinOffered offer) _connect;
  final Future<bool> Function(Machine machine) _current;
  final Future<void> Function(Machine machine) _raise;
  final bool Function(Machine machine) _ready;
  final Future<void> Function(Machine machine) _release;
  final FleetBackend Function(Machine) _reach;
  final Map<String, FleetBackend> _open = {};

  @override
  Future<Machine> connect(JoinOffered offer) => _connect(offer);

  @override
  Future<bool> current(Machine machine) => _current(machine);

  @override
  Future<void> raise(Machine machine) => _raise(machine);

  @override
  bool ready(Machine machine) => _ready(machine);

  @override
  Future<void> release(Machine machine) async {
    _open.remove(machine.socketPath);
    await _release(machine);
  }

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
