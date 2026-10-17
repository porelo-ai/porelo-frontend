import 'dart:async';

import 'package:flutter/foundation.dart';

import 'desk.dart';
import 'forge.dart';
import 'project_workspace.dart';
import 'quiet_after_dispose.dart';

/// Makes the forge for a token at an address: GitHub for now. Injectable, so a test judges the
/// flow offline.
typedef ForgeFor = Forge Function(String token, String address);

/// One forge set up on this computer: what kind it is, what the person calls it, and where it is.
/// **Its token is not in here**: it is in the keychain, under the entry's id.
class ForgeEntry {
  /// What its token is kept under, and how it is told apart from another of the same kind.
  final String id;

  /// `github`; the other kinds come later, each one more [Forge].
  final String kind;

  /// What the person calls it: "GitHub private", "GitHub work".
  final String name;

  /// Where it is: `github.com`, or a self-hosted instance's host.
  final String address;

  /// Constructor taking every field.
  const ForgeEntry({required this.id, required this.kind, required this.name, required this.address});

  /// What kind of forge, in words.
  String get kindWords => switch (kind) {
    'github' => address == 'github.com' ? 'GitHub' : 'GitHub Enterprise',
    _ => kind,
  };

  /// Kept as it is stored.
  Map<String, Object?> toJson() => <String, Object?>{'id': id, 'kind': kind, 'name': name, 'address': address};

  /// Read back from what was stored, or null where it is not one.
  static ForgeEntry? fromJson(Object? stored) {
    if (stored is! Map) return null;
    final id = stored['id'], kind = stored['kind'], name = stored['name'], address = stored['address'];
    if (id is! String || kind is! String || name is! String || address is! String) return null;
    if (id.isEmpty || address.isEmpty) return null;
    return ForgeEntry(id: id, kind: kind, name: name.isEmpty ? address : name, address: address);
  }

  /// The same entry with another name.
  ForgeEntry named(String name) => ForgeEntry(id: id, kind: kind, name: name, address: address);
}

/// Where the list of forges is kept: this computer's settings. Injectable, so a test keeps it in memory.
abstract interface class ForgeEntries {
  /// What was stored.
  Future<List<Object?>> read();

  /// Keeps [entries], replacing what was there.
  Future<void> write(List<Map<String, Object?>> entries);
}

/// A list kept in memory, for a test and for a run with no settings.
class MemoryForgeEntries implements ForgeEntries {
  List<Map<String, Object?>> _kept = <Map<String, Object?>>[];

  @override
  Future<List<Object?>> read() async => List<Object?>.of(_kept);

  @override
  Future<void> write(List<Map<String, Object?>> entries) async => _kept = List<Map<String, Object?>>.of(entries);
}

/// Makes the working folder for a repository, with the token that reaches it. Injectable likewise.
typedef WorkspaceFor = ProjectWorkspace Function(ForgeRepository repository, String token);

/// Where a person's working folders are kept on this computer: one per repository, under this
/// interface's own data directory.
String workingFolders() => desk.join(<String>[desk.data, 'projects']);

/// The forges a person set up on this computer, the one being used, and the repositories it reaches.
///
/// **A token is typed once and kept in this computer's keychain**, never shown again, never sent
/// anywhere but its forge. What it reaches is asked of the forge each time, never kept here.
class ForgeConnection extends ChangeNotifier with QuietAfterDispose {
  /// Constructor taking where tokens and the list are kept, and how a forge is made from a token.
  ForgeConnection(this._tokens, {ForgeEntries? entries, ForgeFor? forgeFor, WorkspaceFor? workspaceFor})
    : _entries = entries ?? MemoryForgeEntries(),
      _forgeFor = forgeFor ?? ((token, address) => GitHub(token, api: GitHub.apiOf(address))),
      _workspaceFor =
          workspaceFor ?? ((repository, token) => ProjectWorkspace(repository, token, root: workingFolders()));

  final ForgeTokens _tokens;
  final ForgeEntries _entries;

  /// Where a token kept before the list existed was kept: one GitHub token, under its host.
  static const String _keptBefore = 'github.com';

  /// Every forge set up here, in the order they were added; empty before [load].
  List<ForgeEntry> entries = <ForgeEntry>[];

  /// The forge whose repositories are shown, or null while none is chosen.
  ForgeEntry? current;

  /// Whether the list was read yet.
  bool loaded = false;
  final ForgeFor _forgeFor;
  final WorkspaceFor _workspaceFor;

  /// The accepted token, in memory while this runs, for git to reach the forge with.
  String? _token;

  /// The working folder for [repository], or null while nothing is connected.
  ProjectWorkspace? workspace(ForgeRepository repository) {
    final token = _token;
    return token == null ? null : _workspaceFor(repository, token);
  }

  Forge? _forge;

  /// Who the kept token logs in as, or null while none is kept or it was not accepted.
  ForgeAccount? account;

  /// Every repository the login reaches, or null before the forge answered.
  List<ForgeRepository>? repositories;

  /// What is typed into the search.
  String filter = '';

  /// Why the last thing asked did not happen, in words, or null.
  String? problem;

  /// Whether the forge is being asked right now.
  bool busy = false;

  /// Whether a token is kept and accepted.
  bool get connected => account != null;

  /// Whether the token itself may bind a machine to each repository, by full name, as the forge
  /// answered. The listing is the account's, whatever the token was narrowed to, so this is asked.
  final Map<String, bool> mayBind = <String, bool>{};

  /// Why the token may not bind a machine to each repository it may not, in the forge's words.
  final Map<String, String> whyNot = <String, String>{};

  /// Records what the forge answered about [repository]: allowed where [why] is null.
  void heardAbout(String repository, String? why) {
    mayBind[repository] = why == null;
    if (why == null) {
      whyNot.remove(repository);
    } else {
      whyNot[repository] = why;
    }
  }

  /// How many repositories are still to be asked about.
  int stillAsking = 0;

  /// Whether each repository has a `project.yml` on its default branch, by full name, as the forge
  /// answered: asked for every repository once it is listed, so the list can say which are projects.
  final Map<String, bool> isProject = <String, bool>{};

  /// Whether the list shows only what the token may bind a machine to; otherwise, as it starts,
  /// every repository the account has.
  bool onlyBindable = false;

  /// Whether the forge was asked about every repository yet: only once somebody wants the list
  /// narrowed, since it asks about each one.
  bool _askedAboutEvery = false;

  /// The repositories the token may bind a machine to, once asked.
  int get bindable => mayBind.values.where((each) => each).length;

  /// The repositories that match the search, by name: only those the token may bind, where that
  /// was asked for.
  List<ForgeRepository> get shown {
    final all = repositories ?? const <ForgeRepository>[];
    final wanted = filter.trim().toLowerCase();
    return all
        .where((each) => wanted.isEmpty || each.fullName.toLowerCase().contains(wanted))
        .where((each) => !onlyBindable || mayBind[each.fullName] == true)
        .toList();
  }

  /// Shows only the repositories the token may bind, asking the forge about each one the first
  /// time; or every repository the account has again.
  void showOnlyBindable(bool only) {
    onlyBindable = only;
    final forge = _forge;
    final found = repositories;
    if (only && !_askedAboutEvery && forge != null && found != null) {
      _askedAboutEvery = true;
      unawaited(_askWhatTheTokenMayBind(forge, found));
    }
    notifyListeners();
  }

  /// Reads the forges set up here, and opens the one there is where there is only one. A GitHub
  /// token kept before the list existed becomes its first entry, under the key it was kept by.
  Future<void> load() => _asking(() async {
    await _readList();
    if (entries.length == 1 && current == null) await _open(entries.single);
  });

  /// Reads the forges set up here without asking any of them anything: what says, before a forge
  /// is used, which project's repository is on which.
  Future<void> readList() => _asking(_readList);

  Future<void> _readList() async {
    entries = <ForgeEntry>[for (final each in await _entries.read()) ?ForgeEntry.fromJson(each)];
    if (entries.isEmpty) {
      final before = await _tokens.read(_keptBefore);
      if (before != null && before.isNotEmpty) {
        entries = <ForgeEntry>[
          const ForgeEntry(id: _keptBefore, kind: 'github', name: 'GitHub', address: 'github.com'),
        ];
        await _keep();
      }
    }
    loaded = true;
  }

  /// Shows [entry]'s repositories, with its kept token.
  Future<void> choose(ForgeEntry entry) => _asking(() => _open(entry));

  /// Sets up a forge: kept, with its token, only once the forge accepted the token. Answers the
  /// entry, or null where it was not accepted.
  Future<ForgeEntry?> add({
    required String name,
    required String address,
    required String token,
    String kind = 'github',
  }) async {
    ForgeEntry? made;
    await _asking(() async {
      final typed = token.trim();
      final where = address.trim().isEmpty ? 'github.com' : address.trim().toLowerCase();
      if (typed.isEmpty) return;
      final forge = _forgeFor(typed, where);
      final login = await forge.whoAmI();
      var id = where;
      for (var n = 2; entries.any((each) => each.id == id); n++) {
        id = '$where#$n';
      }
      final entry = ForgeEntry(id: id, kind: kind, name: name.trim().isEmpty ? where : name.trim(), address: where);
      await _tokens.write(id, typed);
      entries = <ForgeEntry>[...entries, entry];
      await _keep();
      made = entry;
      await _use(entry, forge, typed, login);
    });
    return made;
  }

  /// Connects GitHub with [token], as the first forge set up here.
  Future<void> connect(String token) async {
    await add(name: 'GitHub', address: 'github.com', token: token);
  }

  /// Renames [entry], and replaces its token where a new one is given: one that expired, say. The
  /// kind stays, so the projects made from it still fit. A token is kept only once it was accepted.
  Future<void> edit(ForgeEntry entry, {String? name, String? token}) => _asking(() async {
    final typed = token?.trim() ?? '';
    if (typed.isNotEmpty) {
      final forge = _forgeFor(typed, entry.address);
      final login = await forge.whoAmI();
      await _tokens.write(entry.id, typed);
      if (current?.id == entry.id) await _use(entry, forge, typed, login);
    }
    final renamed = name == null || name.trim().isEmpty ? entry : entry.named(name.trim());
    entries = <ForgeEntry>[for (final each in entries) each.id == entry.id ? renamed : each];
    if (current?.id == entry.id) current = renamed;
    await _keep();
  });

  /// Removes [entry] here: its token out of the keychain. **Nothing at the forge is touched**: the
  /// token stays valid there until the person revokes it, and keys machines registered stay.
  Future<void> remove(ForgeEntry entry) => _asking(() async {
    await _tokens.delete(entry.id);
    entries = <ForgeEntry>[
      for (final each in entries)
        if (each.id != entry.id) each,
    ];
    await _keep();
    if (current?.id == entry.id) _close();
  });

  /// Forgets the forge being used here. It stays valid at the forge until the person revokes it there.
  Future<void> forget() async {
    final entry = current;
    if (entry != null) await remove(entry);
  }

  /// Puts the chosen forge away, so another can be chosen.
  void putAway() {
    _close();
    notifyListeners();
  }

  /// A forge for [entry], with its kept token, without changing which one is shown: what a
  /// project's own tools reach its repositories with. Null where no token is kept for it.
  Future<({Forge forge, String token})?> reach(ForgeEntry entry) async {
    final token = await _tokens.read(entry.id);
    if (token == null || token.isEmpty) return null;
    return (forge: _forgeFor(token, entry.address), token: token);
  }

  /// The working folder for [repository] with [token]: a project's own tools clone with the
  /// forge's token they reached it with.
  ProjectWorkspace workspaceWith(ForgeRepository repository, String token) => _workspaceFor(repository, token);

  /// The entry whose forge holds [url], a repository's address as git reaches it, or null.
  ForgeEntry? holding(String url) {
    final host = hostOf(url);
    return host == null ? null : entries.where((each) => each.address == host).firstOrNull;
  }

  Future<void> _open(ForgeEntry entry) async {
    final token = await _tokens.read(entry.id);
    if (token == null || token.isEmpty) {
      _close();
      current = entry;
      problem = 'No token is kept for ${entry.name} on this computer any more. Give it one again.';
      return;
    }
    final forge = _forgeFor(token, entry.address);
    await _use(entry, forge, token, null);
  }

  void _close() {
    mayBind.clear();
    whyNot.clear();
    isProject.clear();
    stillAsking = 0;
    _forge = null;
    _token = null;
    account = null;
    repositories = null;
    current = null;
  }

  Future<void> _keep() => _entries.write(<Map<String, Object?>>[for (final each in entries) each.toJson()]);

  /// Asks the forge again what the login reaches.
  Future<void> refresh() => _asking(() async {
    final forge = _forge;
    if (forge != null) repositories = await forge.repositories();
  });

  /// Narrows the list to what matches [typed].
  void search(String typed) {
    filter = typed;
    notifyListeners();
  }

  /// The forge the token reaches, for what comes after picking a repository.
  Forge? get forge => _forge;

  Future<void> _use(ForgeEntry entry, Forge forge, String token, ForgeAccount? login) async {
    _close();
    current = entry;
    account = login ?? await forge.whoAmI();
    _forge = forge;
    _token = token;
    final found = await forge.repositories();
    repositories = found;
    mayBind.clear();
    whyNot.clear();
    isProject.clear();
    _askedAboutEvery = false;
    onlyBindable = false;
    unawaited(_askWhichAreProjects(forge, found));
  }

  /// Asks, a few at a time, which repositories have a `project.yml`.
  Future<void> _askWhichAreProjects(Forge forge, List<ForgeRepository> found) => _eachOf(found, forge, (each) async {
    try {
      isProject[each.fullName] = await forge.hasProjectFile(each);
    } on ForgeRefused {
      // Said as not known: the row then offers nothing it cannot back.
    }
  });

  /// Runs [ask] for every one of [found], twelve at a time over the forge's one connection, for as
  /// long as [forge] is still the one connected.
  Future<void> _eachOf(List<ForgeRepository> found, Forge forge, Future<void> Function(ForgeRepository) ask) async {
    final queue = List<ForgeRepository>.of(found);
    Future<void> worker() async {
      while (queue.isNotEmpty && identical(_forge, forge)) {
        await ask(queue.removeLast());
        notifyListeners();
      }
    }

    await Future.wait(<Future<void>>[for (var i = 0; i < 12; i++) worker()]);
  }

  /// Asks, a few at a time, whether the token may manage each repository's deploy keys. Only an
  /// admin of a repository may, so the others are not asked.
  Future<void> _askWhatTheTokenMayBind(Forge forge, List<ForgeRepository> found) async {
    final admins = <ForgeRepository>[
      for (final each in found)
        if (each.admin) each,
    ];
    stillAsking = admins.length;
    notifyListeners();
    await _eachOf(admins, forge, (each) async {
      try {
        heardAbout(each.fullName, await forge.whyNoKeys(each.fullName));
      } on ForgeRefused catch (refused) {
        heardAbout(each.fullName, refused.words);
      }
      stillAsking--;
    });
  }

  Future<void> _asking(Future<void> Function() action) async {
    busy = true;
    problem = null;
    notifyListeners();
    try {
      await action();
    } on ForgeRefused catch (refused) {
      problem = refused.words;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}

/// The host a repository's address names, as a forge entry's address is written: `github.com` for
/// `git@github.com:acme/api.git` and `https://github.com/acme/api`. Null for a local path.
String? hostOf(String url) {
  final scp = RegExp(r'^[^@/:]+@([^:/]+):').firstMatch(url.trim());
  if (scp != null) return scp.group(1)!.toLowerCase();
  final uri = Uri.tryParse(url.trim());
  return uri == null || uri.host.isEmpty ? null : uri.host.toLowerCase();
}

/// `owner/name` for a repository's address on any host, or null.
String? fullNameOf(String url) {
  final match = RegExp(r'^(?:[^@/:]+@[^:/]+:|[a-z+]+://(?:[^@/]+@)?[^/]+/)([^/]+/[^/]+?)(?:\.git)?/?$')
      .firstMatch(url.trim());
  return match?.group(1);
}
