import 'dart:convert';

import 'package:porelo_frontend/client.dart';
import 'package:porelo_host/porelo_host.dart' show PreparedHost, checkAdminName;

import 'fleet_backend.dart';
import 'machines.dart';
import 'project_join.dart';
import 'registry.dart';
import 'registry_checkout.dart';
import 'run_here.dart';

/// Core's `porelo registry joinable` on the person's private registry checkout, for the person Core names.
class CoreJoinDiscovery implements JoinDiscovery {
  /// Takes the registry checkout, who the person is, and an argument-list process runner.
  CoreJoinDiscovery({required this.checkout, required this.login, RunHere? run}) : _run = run ?? runHere;

  /// The private checkout of the registry Core reads.
  final RegistryCheckout checkout;

  /// The logged-in person's login as Core's identity names it, or null when there is none.
  final Future<String?> Function() login;

  final RunHere _run;

  @override
  Future<List<JoinAdmission>> admissions() async {
    final person = await _login();
    final Ran result;
    try {
      result = await _run('porelo', ['registry', 'joinable', checkout.folder, '--login', person, '--json']);
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
        throw const RegistryRefusal('Core refused to say which projects you may join: the registry did not verify.');
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

  final Future<Machine> Function(PreparedHost host) _connect;
  final FleetBackend Function(Machine) _reach;
  final Map<String, FleetBackend> _open = {};

  @override
  Future<Machine> connect(PreparedHost host) => _connect(host);

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
