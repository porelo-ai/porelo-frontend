import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart' show ChangeNotifier, Listenable;
import 'package:path/path.dart' as path;
import 'package:porelo_host/porelo_host.dart';

import 'desk.dart';
import 'host_organization.dart';
import 'organization_source.dart';
import 'settings.dart';

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
  bool _preparing = false;

  /// Said when Porelo's answer names no organization settings or forge to hand a host.
  static const noAddress =
      "Porelo's answer does not name the Porelo organization's settings and forge, and a new machine needs them to follow it, "
      'so no server can be prepared.';

  /// Said of an organization at an https address, which a host's own key cannot read; other forms all can.
  static const noFollowing =
      "This Porelo organization stands at an https address, and a machine follows it with an ssh key of its own, so a machine made "
      'now could never follow it. No server is prepared until the Porelo organization stands at an ssh address.';

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
      why = 'The Porelo organization could not be read.';
    }
    if (read != _reading) return;
    _view = view;
    _whyNoView = why;
    notifyListeners();
  }

  /// Why this person may not take [host] down, only where the organization's fresh answer says so: the machine stays
  /// the guard, so a state not known here offers it and leaves the refusal to the machine.
  String? whyNotTakeDown(String host) {
    final view = _view;
    if (view == null || view.stale || view.me.isEmpty) return null;
    final named = view.hosts.where((each) => each.name == host).firstOrNull;
    if (named == null || view.isOrganizationAdmin) return null;
    if (view.holdsRoles && named.admins.contains(view.me)) return null;
    return 'Only a Machine Admin of $host or an Organization Admin may do this.${_ask(view, named.admins)}';
  }

  /// The projects the organization says stand on [host].
  List<String> projectsOn(String host) =>
      _view?.hosts.where((each) => each.name == host).firstOrNull?.projects ?? const [];

  /// What taking [host] off from this computer still lacks where nothing was kept from setting it up, as `down` asks only
  /// its address, its SSH host key and the person's key, which the organization's card and this person's card hold.
  String? whatTakingOffLacks(OrganizationHost host) {
    if (host.address == null || host.hostKey == null) {
      return 'The organization names no address or SSH host key for ${host.name}: it was never set up, so Porelo is not '
          'on it. *Remove the machine…* takes it off the list.';
    }
    if ((host.port ?? 22) != 22) {
      return '${host.name} answers ssh on port ${host.port}, which taking Porelo off does not reach from a computer that '
          'did not set it up.';
    }
    if (identity() == null) return proof?.whyNone ?? 'Your identity is not proven.';
    return null;
  }

  /// The record to take [host] off with, on a computer that kept none.
  HostUpRecord? takingOffRecord(OrganizationHost host) => whatTakingOffLacks(host) != null
      ? null
      : HostUpRecord(
          hostName: host.name,
          host: host.name,
          givenAddress: host.address!,
          givenHostKey: host.hostKey!,
          publicKey: identity()!.key,
        );

  /// Whether preparing is offered at all: not to a person the organization names as neither of the admins. Where
  /// nothing is read yet, or there is no organization, it stays, and [unavailable] says why it cannot be done.
  bool get offersPreparing {
    final view = _view;
    if (view == null || view.stale) return true;
    return view.isOrganizationAdmin || view.hosts.any((each) => each.admins.contains(view.me));
  }

  /// The listed machines this person is a Machine Admin of.
  List<String> get hostsOfMine {
    final view = _view;
    final actor = identity();
    if (view == null || actor == null) return const [];
    return [
      for (final host in view.hosts)
        if (host.admins.contains(actor.login)) host.name,
    ]..sort();
  }

  /// Why preparing [host], or any host, is unavailable now, naming whom to ask; null when it is available.
  String? unavailable([String? host]) {
    if (_whyNoView case final why?) return why;
    final view = _view;
    if (view == null) return 'The Porelo organization has not been read yet.';
    // No security check rests on a state read earlier: a pin from one could trust the wrong people.
    if (view.stale) {
      return 'Porelo could not reach the Porelo organization just now, and no machine is prepared on an older state. Try again.';
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
        ? view.isOrganizationAdmin || view.hosts.any((each) => each.admins.contains(actor.login))
        : named?.admins.contains(actor.login) == true;
    if (!permitted) {
      if (host == null) return 'Only a Machine Admin of this organization may do this.${_ask(view, _owners(view))}';
      if (named == null) {
        return 'The organization lists no machine $host yet: an Organization Admin adds it first.${_ask(view, _owners(view))}';
      }
      return 'Only a Machine Admin of $host may do this.${_ask(view, named.admins)}';
    }
    if ((view.settings ?? '').isEmpty || (view.forge ?? '').isEmpty) return noAddress;
    if (view.address?.toLowerCase().startsWith('https://') ?? false) return noFollowing;
    return named == null ? null : _whyNoPin(view, named);
  }

  /// Why [host]'s admins cannot be pinned now: a host believes only a trusted card's key, and leaving a row out would
  /// make a pin without an admin, who then cannot sign for their own host. So it refuses, and goes on when asked again.
  static String? _whyNoPin(OrganizationView view, OrganizationHost host) {
    for (final login in {for (final row in host.adminKeys) row.login}) {
      final standing = view.persons.where((person) => person.login == login).firstOrNull?.standing;
      if (standing == CardStanding.trusted) continue;
      return standing == CardStanding.notYet
          ? 'The forge cannot yet say whether the key of $login, a Machine Admin of ${host.name}, is theirs, and a new '
                'machine would not believe it. Try again later.'
          : 'The organization holds no accepted card of $login, a Machine Admin of ${host.name}, and a new machine would '
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

  /// Opens one preparation dialog at a time; the dialog reads permission before offering any action.
  Future<void> prepare(Future<void> Function() start) async {
    if (_preparing) return;
    _preparing = true;
    try {
      await start();
    } finally {
      _preparing = false;
    }
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
      knownHosts: centralForgeKnownHosts(forgeInKnownHosts(view.forge!, view.address), await _knownHosts()),
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
      // `up` run again finds the card filed: the store refuses a write that changes nothing, and nothing is amiss.
      final card = view.hosts.where((each) => each.name == prepared.name).firstOrNull;
      if (card != null &&
          card.address == prepared.address &&
          card.port == prepared.sshPort &&
          card.hostKey == prepared.sshHostKey &&
          (forge?['web_port'] ?? card.webPort) == card.webPort &&
          (forge?['git_port'] ?? card.gitPort) == card.gitPort &&
          (matrix?['port'] ?? card.matrixPort) == card.matrixPort) {
        return null;
      }
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
    return 'The organization still names $host at ${named!.address}: a Machine Admin enters its new address, or an '
        'organization owner removes the machine.';
  }

  static final _random = Random.secure();

  String _newId() => [for (var i = 0; i < 16; i++) _random.nextInt(256).toRadixString(16).padLeft(2, '0')].join();
}
