import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:porelo_frontend/client.dart';

import 'access_checkout.dart' show privateDirectory;
import 'quiet_after_dispose.dart';
import 'registry_checkout.dart';
import 'run_here.dart';

/// Core's boundary for the registry: the one place its read and its write are asked.
abstract interface class RegistryCore {
  /// Core's verdict on the checkout in [checkout].
  Future<RegistryRead> read(String checkout);

  /// Has Core write and sign [filing] in [checkout], without publishing it.
  Future<RegistryFiled> file(String checkout, RegistryFiling filing);
}

/// Asks Core's `porelo registry read|file` on this computer, where the checkout is a folder.
class CliRegistryCore implements RegistryCore {
  /// Constructor taking a private folder for the file a change hands Core, and an argument-list runner.
  CliRegistryCore({required this.scratch, RunHere? run}) : _run = run ?? runHere;

  /// A private folder the file a change hands Core is written to, and removed from afterwards.
  final String scratch;

  final RunHere _run;

  @override
  Future<RegistryRead> read(String checkout) async {
    final result = await _porelo(['registry', 'read', checkout, '--json']);
    if (result.code != 0) throw RegistryRefusal(_words(result, 'Porelo could not read the registry.'));
    return RegistryRead.from(_object(result.out));
  }

  @override
  Future<RegistryFiled> file(String checkout, RegistryFiling filing) async {
    final content = filing.content;
    if (content == null) throw const FormatException('A registry change names no file to file.');
    await privateDirectory(Directory(scratch));
    final handed = File(path.join(scratch, 'filing-${filing.id ?? DateTime.now().microsecondsSinceEpoch}'));
    try {
      await handed.writeAsString(content, flush: true);
      final result = await _porelo([
        'registry',
        'file',
        filing.kind.word,
        checkout,
        if (filing.kind == RegistryFilingKind.hostAccess) ...['--file', handed.path] else ...['--card', handed.path],
        if (filing.host case final host?) ...['--host', host],
        if (filing.id case final id?) ...['--id', id],
        if (filing.base case final base?) ...['--base', base],
        '--json',
      ]);
      if (result.code != 0) throw RegistryRefusal(_words(result, 'Porelo refused this registry change.'));
      final commit = _object(result.out)['commit'];
      return RegistryFiled.from(<String, dynamic>{'revision': commit});
    } finally {
      if (await handed.exists()) await handed.delete();
    }
  }

  Future<Ran> _porelo(List<String> arguments) async {
    try {
      return await _run('porelo', arguments);
    } on ProcessException {
      throw const RegistryRefusal('Porelo is not installed on this computer.');
    }
  }

  static Map<String, dynamic> _object(String out) {
    final value = jsonDecode(out);
    if (value is! Map<String, dynamic>) throw const FormatException('Core answered no JSON object.');
    return value;
  }

  /// Core's typed words for a refusal, or [otherwise] when it gave none; never its error output.
  static String _words(Ran result, String otherwise) {
    try {
      final words = _object(result.out)['words'];
      if (words is String && words.isNotEmpty) return words;
    } on FormatException {
      // No typed answer: the fixed sentence says it.
    }
    return otherwise;
  }
}

/// What a registry change writes.
enum RegistryFilingKind {
  /// A person card under `people/`.
  card('card'),

  /// A host card under `hosts/<host>/`.
  hostCard('host-card'),

  /// A host's access file, `hosts/<host>/access.yml`.
  hostAccess('host-access');

  const RegistryFilingKind(this.word);

  /// The kind as Core names it.
  final String word;
}

/// One registry change, as Core is asked to write it.
@immutable
class RegistryFiling {
  /// Constructor taking what the change writes, the host it is for and the person it names.
  const RegistryFiling(this.kind, {this.host, this.person, this.id, this.base, this.content});

  /// What the change writes.
  final RegistryFilingKind kind;

  /// The host a host change is for.
  final String? host;

  /// The login an access change names, which must be a card Core trusts.
  final String? person;

  /// The change's stable ID: the same ID on the same base answers the same commit, never a second one.
  final String? id;

  /// The accepted registry commit the change was made against; Core refuses it on another `HEAD`.
  final String? base;

  /// The file's public text, the access file or the host card, which Core files at its path.
  final String? content;
}

/// Somebody who may make a change another person may not, with their address when their card has one.
@immutable
class RegistryContact {
  /// Constructor taking the login, the name and the optional address.
  const RegistryContact({required this.login, required this.name, this.email});

  /// Their login on the central forge.
  final String login;

  /// Their name from their card, or their login when no card names them.
  final String name;

  /// Their card's address, absent when the card has none.
  final String? email;
}

/// A registry change refused before or by Core, saying why and who may make it.
class RegistryRefusal implements Exception {
  /// Constructor taking the reason and who may.
  const RegistryRefusal(this.words, {this.whoMay = const <RegistryContact>[]});

  /// Why, in a sentence safe to show.
  final String words;

  /// The owners or host admins who may make this change.
  final List<RegistryContact> whoMay;

  @override
  String toString() {
    final contacts = whoMay
        .map((person) => '${person.name} (${person.login})${person.email == null ? '' : ', ${person.email}'}')
        .join('; ');
    return '$words${contacts.isEmpty ? '' : ' Ask $contacts.'}';
  }
}

/// The organisation's registry as Core last accepted it, shared by every list of persons, hosts and projects.
class Registry extends ChangeNotifier with QuietAfterDispose {
  /// Constructor taking the private checkout and Core's boundary.
  Registry({required this.checkout, required this.core});

  /// The private checkout of the registry repository.
  final RegistryCheckout checkout;

  /// Core, which judges the checkout.
  final RegistryCore core;

  RegistryRead? _accepted;
  RegistryRefusedCommit? _refusedCommit;
  String? _problem;
  int _running = 0;

  /// The last complete answer Core accepted, or null before one arrived.
  RegistryRead? get accepted => _accepted;

  /// The commit Core refused at the last read, or null.
  RegistryRefusedCommit? get refusedCommit => _refusedCommit;

  /// Why the newest state is not the one shown, or null when it is.
  String? get problem => _problem;

  /// Whether a fetch, a read or a change is running.
  bool get busy => _running > 0;

  /// Every person card, refused ones included.
  List<RegistryCard> get people => _accepted?.people ?? const <RegistryCard>[];

  /// The cards a change may name: only those Core trusts.
  List<RegistryCard> get selectable => [
    for (final card in people)
      if (card.trusted) card,
  ];

  /// Every host, with its admins and admitted projects.
  List<RegistryHost> get hosts => _accepted?.hosts ?? const <RegistryHost>[];

  /// The registry's owners from `owners.yml`.
  List<RegistryOwner> get owners => _accepted?.owners ?? const <RegistryOwner>[];

  /// The login of the registry owner who signed `owners.yml`, or null when Core did not say.
  String? get ownersSigner => _accepted?.ownersSigner;

  /// Fetches the repository and publishes Core's answer once it is complete.
  ///
  /// A refused fetch or an incomplete answer keeps the last accepted state. Beside a refused commit,
  /// Core supplies the verified state before it, including any newer accepted revocations.
  Future<void> refresh() => _oneAtATime(_readAgain);

  /// Why [filing] cannot be made now, or null when it can.
  String? unavailable(RegistryFiling filing) => busy ? 'Another registry operation is still running.' : _whyNot(filing);

  /// The owners or host admins who may make [filing], with the addresses their trusted cards give.
  ///
  /// A host change names that host's admins; a card, or a host without assigned admins, names the
  /// registry's owners, who name the host admins in `owners.yml`.
  List<RegistryContact> whoMay(RegistryFiling filing) {
    final host = hosts.where((each) => each.host == filing.host).firstOrNull;
    final logins = filing.kind != RegistryFilingKind.card && host != null && host.admins.isNotEmpty
        ? host.admins
        : [
            for (final owner in owners)
              if (!owner.backup) owner.login,
          ];
    return [
      for (final login in {...logins}) _contact(login),
    ];
  }

  /// Has Core write and sign [filing], publishes the commit, and reads the registry again.
  ///
  /// Throws a [RegistryRefusal] naming who may when the change is not allowed now or Core refuses it,
  /// and a [WorkspaceRefused] when Git cannot publish it.
  Future<RegistryFiled> file(RegistryFiling filing) => _oneAtATime(() async {
    if (_whyNot(filing) case final reason?) throw RegistryRefusal(reason, whoMay: whoMay(filing));
    final RegistryFiled filed;
    try {
      await checkout.prepareFiling();
      filed = await core.file(checkout.folder, filing);
    } on WorkspaceRefused catch (refused) {
      _problem = refused.words;
      rethrow;
    } on FeatureNotSupported {
      throw const RegistryRefusal('Porelo on this computer cannot write the registry yet.');
    } on VarlinkException {
      throw RegistryRefusal('Porelo refused this registry change.', whoMay: whoMay(filing));
    }
    try {
      await checkout.publish(filed.revision);
    } on WorkspaceRefused catch (refused) {
      _problem = refused.words;
      rethrow;
    }
    await _readAgain();
    return filed;
  });

  Future<void> _tail = Future<void>.value();

  /// Runs [work] after everything asked before it, so a fetch never meets a change half made.
  Future<T> _oneAtATime<T>(Future<T> Function() work) {
    _running++;
    notifyListeners();
    final result = _tail.then((_) => work());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result.whenComplete(() {
      _running--;
      notifyListeners();
    });
  }

  Future<void> _readAgain() async {
    try {
      await checkout.fetch();
    } on WorkspaceRefused catch (refused) {
      _problem = refused.words;
      return;
    }
    final RegistryRead answer;
    try {
      answer = await core.read(checkout.folder);
    } on FeatureNotSupported {
      _problem = 'Porelo on this computer cannot read a registry yet. $_unchanged';
      return;
    } on FormatException {
      _problem = 'Porelo answered the registry read incompletely. $_unchanged';
      return;
    } on VarlinkDisconnected {
      _problem = 'No Porelo answers on this computer to read the registry. $_unchanged';
      return;
    } on Exception {
      _problem = 'Porelo could not read the registry. $_unchanged';
      return;
    }
    _refusedCommit = answer.refusedCommit;
    _accepted = answer.revision == null ? null : answer;
    if (answer.refusedCommit case final refused?) {
      _problem =
          'Porelo refused commit ${refused.commit.substring(0, 12)} at ${refused.path}: ${refused.why} $_unchanged';
      return;
    }
    _problem = null;
  }

  String get _unchanged =>
      _accepted == null ? 'No accepted registry is available yet.' : 'The last accepted registry stays shown.';

  String? _whyNot(RegistryFiling filing) {
    if (_accepted == null) return 'The registry has not been read yet.';
    if (_problem != null) return 'The newest registry state was not accepted. Refresh it before making a change.';
    if (filing.kind != RegistryFilingKind.card && (filing.host == null || filing.host!.trim().isEmpty)) {
      return 'Choose the host this change is for.';
    }
    if (filing.kind == RegistryFilingKind.hostAccess && !hosts.any((host) => host.host == filing.host)) {
      return 'The registry lists no such host.';
    }
    final login = filing.person;
    if (login == null) {
      return filing.kind == RegistryFilingKind.hostAccess ? 'Choose a person whose card is in the registry.' : null;
    }
    final card = people.where((card) => card.login == login).firstOrNull;
    if (card == null) return 'Choose a person whose card is in the registry.';
    if (card.refused) return 'Porelo refused the card of ${card.login}: ${card.why}';
    if (!card.trusted) return 'The card of ${card.login} has not been checked against the forge yet.';
    return null;
  }

  RegistryContact _contact(String login) {
    final card = people.where((card) => card.login == login && card.trusted).firstOrNull;
    return RegistryContact(login: login, name: card?.name ?? login, email: card?.contactEmail);
  }
}
