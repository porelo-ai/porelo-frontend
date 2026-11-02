import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart' show ChangeNotifier, Listenable;
import 'package:path/path.dart' as path;
import 'package:porelo_host/porelo_host.dart';

import 'desk.dart';
import 'host_organization.dart';
import 'organization_source.dart';

export 'host_organization.dart' show HostAccessRefused;

/// The current identity proven by Porelo, never a typed account name.
class HostAdminIdentity {
  /// Keeps Porelo's proven login, current key fingerprint and public key.
  const HostAdminIdentity(this.login, this.fingerprint, this.key);

  /// The central-forge login.
  final String login;

  /// The current proven public key fingerprint.
  final String fingerprint;

  /// The current proven public key.
  final String key;
}

/// Where the proven identity is read again from, and why there is none; it notifies after every read.
abstract interface class HostAdminProof implements Listenable {
  /// Reads the proven identity again; what it found is what [HostAccess.identity] answers next.
  Future<void> readAgain();

  /// Why no identity is proven now, or null when one is.
  String? get whyNone;
}

/// Who may prepare which host, judged on what `porelo org` answers, and what goes to the organization and to `up`.
class HostAccess extends ChangeNotifier {
  /// Reads and writes the organization through [source].
  HostAccess({
    required this.source,
    required this.identity,
    required this.scratch,
    this.proof,
    Future<String> Function()? knownHosts,
    Future<void> Function(File file, String text)? keepFile,
  }) : _knownHosts = knownHosts ?? _ownKnownHosts,
       _keepFile = keepFile ?? _keepPrivately;

  /// Where the organization is read and changed.
  final OrganizationSource source;

  /// The current proven identity, read again before every side effect.
  final HostAdminIdentity? Function() identity;

  /// A private folder the machine files `up` hands on are kept in.
  final String scratch;

  /// Reads [identity] again, and says why none is proven; absent where [identity] is given whole, as in tests.
  final HostAdminProof? proof;

  final Future<String> Function() _knownHosts;
  final Future<void> Function(File file, String text) _keepFile;

  OrganizationView? _view;
  String? _whyNoView;
  int _reading = 0;

  /// Said when Porelo's answer names no organization settings or forge to hand a host.
  static const noAddress =
      "Porelo's answer does not name the organization's settings and forge, and a new host needs them to follow it, "
      'so no server can be prepared.';

  static Future<String> _ownKnownHosts() async {
    final file = File(path.join(desk.home, '.ssh', 'known_hosts'));
    return await file.exists() ? file.readAsString() : '';
  }

  static Future<void> _keepPrivately(File file, String text) async {
    final writer = HostFileWriter();
    await file.parent.create(recursive: true);
    await writer.protectDirectory(file.parent);
    // Each try hands on what the organization says now, never an older try's pin.
    if (await file.exists()) await file.delete();
    await writer.write(file, utf8.encode(text));
  }

  /// Reads the organization and the proven identity again; only the newest read is kept.
  Future<void> readAgain() async {
    final read = ++_reading;
    await proof?.readAgain();
    OrganizationView? view;
    String? why;
    try {
      view = await source.read();
    } on OrganizationRefused catch (refused) {
      why = refused.words;
    } on Exception {
      why = 'The organization could not be read.';
    }
    if (read != _reading) return;
    _view = view;
    _whyNoView = why;
    notifyListeners();
  }

  /// Why preparing [host], or any host, is unavailable now, naming whom to ask; null when it is available.
  String? unavailable([String? host]) {
    if (_whyNoView case final why?) return why;
    final view = _view;
    if (view == null) return 'The organization has not been read yet.';
    // No security check rests on a state read earlier: a pin from one could trust the wrong people.
    if (view.stale) {
      return 'Porelo could not reach the organization just now, and no host is prepared on an older state. Try again.';
    }
    final actor = identity();
    if (actor == null) return proof?.whyNone ?? 'Your identity is not proven.';
    if (view.me != actor.login) return 'The organization holds no card of yours, ${actor.login}, yet.';
    if (!view.holdsRoles) return 'The organization does not take your card, ${actor.login}, so it holds no role.';
    // A login is only a name: the place is held by the key on the accepted card.
    if (view.myCard?.key != actor.fingerprint) {
      return 'Your key ${actor.fingerprint} is not the one the organization holds for ${actor.login}.';
    }
    final named = host == null ? null : view.hosts.where((each) => each.name == host).firstOrNull;
    final permitted = host == null
        ? view.hosts.any((each) => each.admins.contains(actor.login))
        : named?.admins.contains(actor.login) == true;
    if (!permitted) {
      if (host == null) return 'Only a host admin of this organization may do this.${_ask(view, _owners(view))}';
      if (named == null) {
        return 'The organization lists no host $host yet: an organization owner adds it first.${_ask(view, _owners(view))}';
      }
      return 'Only a host admin of $host may do this.${_ask(view, named.admins)}';
    }
    if ((view.settings ?? '').isEmpty || (view.forge ?? '').isEmpty) return noAddress;
    return named == null ? null : _whyNoPin(view, named);
  }

  /// Why [host]'s admins cannot be pinned now: a host believes only a trusted card's key, and leaving a row out would
  /// make a pin without an admin, who then cannot sign for their own host. So it refuses, and goes on when asked again.
  static String? _whyNoPin(OrganizationView view, OrganizationHost host) {
    for (final login in {for (final row in host.adminKeys) row.login}) {
      final standing = view.persons.where((person) => person.login == login).firstOrNull?.standing;
      if (standing == CardStanding.trusted) continue;
      return standing == CardStanding.notYet
          ? 'The forge cannot yet say whether the key of $login, a host admin of ${host.name}, is theirs, and a new '
                'host would not believe it. Try again later.'
          : 'The organization holds no accepted card of $login, a host admin of ${host.name}, and a new host would '
                'not believe their key.${_ask(view, _owners(view))}';
    }
    return null;
  }

  static List<String> _owners(OrganizationView view) => view.owners;

  /// The person asking is never told to ask themselves.
  static String _ask(OrganizationView view, List<String> logins) {
    final others = {...logins}.where((login) => login != view.me);
    return others.isEmpty ? '' : ' Ask ${others.join(', ')}.';
  }

  /// Rechecks a retained Prepare callback immediately before it can open the way to a server.
  Future<void> prepare(Future<void> Function() start) async {
    await readAgain();
    requireAdmin();
    await start();
  }

  /// Reads again and refuses a stale callback before it can change a host.
  Future<void> check(String host) async {
    checkHostName(host);
    await readAgain();
    requireAdmin(host);
  }

  /// Refuses a stale callback before it can change a host.
  void requireAdmin([String? host]) {
    if (unavailable(host) case final reason?) throw HostAccessRefused(reason);
  }

  /// Shows the proven key's bootstrap instruction for a separate terminal.
  String bootstrapCommand() {
    requireAdmin();
    return hostRootBootstrapCommand(identity()!.key);
  }

  /// Writes what `up` hands [host] of the organization, from a fresh read, and answers its path.
  ///
  /// Refuses in words before anything is rented: a host that could not trust the forge or its admins is worth nothing.
  Future<String> machineFile(String host) async {
    await check(host);
    final view = _view!;
    final text = hostMachineFile(
      settings: view.settings!,
      knownHosts: centralForgeKnownHosts(view.forge!, await _knownHosts()),
      pin: hostPin(view.hosts.firstWhere((each) => each.name == host)),
    );
    final file = File(path.join(scratch, '$host.yml'));
    await _keepFile(file, text);
    return file.path;
  }

  /// Files [prepared]'s real address, ssh port, host key and service ports on its card by `org host change`.
  ///
  /// Answers why it could not be written, or null when it was.
  Future<String?> writeCard(PreparedHost prepared) async {
    try {
      await check(prepared.name);
      final view = _view!;
      final forge = prepared.hostServices['forge'];
      final matrix = prepared.hostServices['matrix'];
      await source.apply(
        OrganizationWrite(
          change: OrganizationChange.changeHost,
          input: {
            'host': prepared.name,
            'address': prepared.address,
            'port': '${prepared.sshPort}',
            'hostKey': prepared.sshHostKey,
            if (forge?['web_port'] case final port?) 'webPort': '$port',
            if (forge?['git_port'] case final port?) 'gitPort': '$port',
            if (matrix?['port'] case final port?) 'matrixPort': '$port',
          },
          person: view.me,
          base: view.revision,
          id: _newId(),
        ),
      );
      await readAgain();
      return null;
    } on HostAccessRefused catch (refused) {
      return refused.words;
    } on OrganizationRefused catch (refused) {
      return refused.words;
    } on Exception {
      return 'The change could not be asked for.';
    }
  }

  /// What is said after [host] was given back while its card still names it; null where no card does.
  String? cardLeftBehind(String host) {
    final named = _view?.hosts.where((each) => each.name == host).firstOrNull;
    if (named?.address == null) return null;
    return 'The organization still names $host at ${named!.address}: a host admin enters its new address, or an '
        'organization owner removes the host.';
  }

  static final _random = Random.secure();

  String _newId() => [for (var i = 0; i < 16; i++) _random.nextInt(256).toRadixString(16).padLeft(2, '0')].join();
}
