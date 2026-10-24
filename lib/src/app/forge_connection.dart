import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:porelo_host/porelo_host.dart' show forgeAddress;

import 'session.dart';

import 'desk.dart';
import 'forge.dart';
import 'project_workspace.dart';
import 'quiet_after_dispose.dart';

/// Makes the forge for a token at an address: GitHub for now. Injectable, so a test judges the
/// flow offline.
typedef ForgeFor = Forge Function(String token, String address);

/// One forge set up on this computer: what kind it is, what the person calls it, and where it is.
/// Its token is in the system secret store under the forge's host name.
class ForgeEntry {
  /// How this named entry is told apart from another of the same kind.
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
/// **A token is typed in a terminal and kept in this computer's secret store**, never shown again.
/// API requests send it only to its forge. What it reaches is asked of the forge each time, never kept here.
class ForgeConnection extends ChangeNotifier with QuietAfterDispose {
  /// Constructor taking where tokens and the list are kept, and how a forge is made from a token.
  ForgeConnection(
    this._tokens, {
    ForgeEntries? entries,
    ForgeFor? forgeFor,
    WorkspaceFor? workspaceFor,
    this.openTerminal,
  }) : _entries = entries ?? MemoryForgeEntries(),
       _forgeFor = forgeFor ?? ((token, address) => GitHub(token, api: GitHub.apiOf(address))),
       _workspaceFor =
           workspaceFor ?? ((repository, token) => ProjectWorkspace(repository, token, root: workingFolders()));

  /// Opens a terminal, with a stand-in in widget tests.
  final OpenTerminal? openTerminal;

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

  /// Whether each repository has a `project.yml` on its default branch, by full name, as the forge
  /// answered: asked for every repository once it is listed, so the list can say which are projects.
  final Map<String, bool> isProject = <String, bool>{};

  /// The repositories matching the search by name.
  List<ForgeRepository> get shown {
    final all = repositories ?? const <ForgeRepository>[];
    final wanted = filter.trim().toLowerCase();
    return all.where((each) => wanted.isEmpty || each.fullName.toLowerCase().contains(wanted)).toList();
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

  /// Registers a forge after checking the token kept by the terminal command.
  /// Answers the entry, or null where the forge did not accept it.
  Future<ForgeEntry?> add({required String name, required String address, String kind = 'github'}) async {
    ForgeEntry? made;
    await _asking(() async {
      final where = forgeAddress(address);
      final typed = await _tokens.read(where);
      if (typed == null || typed.isEmpty) {
        problem = 'No token is kept for $where. Enter it in the terminal first.';
        return;
      }
      final forge = _forgeFor(typed, where);
      final login = await forge.whoAmI();
      var id = where;
      for (var n = 2; entries.any((each) => each.id == id); n++) {
        id = '$where#$n';
      }
      final entry = ForgeEntry(id: id, kind: kind, name: name.trim().isEmpty ? where : name.trim(), address: where);
      entries = <ForgeEntry>[...entries, entry];
      await _keep();
      made = entry;
      await _use(entry, forge, typed, login);
    });
    return made;
  }

  /// Renames an entry and reloads the token kept by the terminal command.
  Future<void> edit(ForgeEntry entry, {String? name}) => _asking(() async {
    final renamed = name == null || name.trim().isEmpty ? entry : entry.named(name.trim());
    entries = <ForgeEntry>[for (final each in entries) each.id == entry.id ? renamed : each];
    await _keep();
    await _open(renamed);
  });

  /// Whether the terminal command kept a token; no value reaches a widget.
  Future<bool> hasToken(String address) async {
    final kept = await _tokens.read(forgeAddress(address));
    return kept != null && kept.isNotEmpty;
  }

  /// Removes [entry] here: its token out of the keychain. **Nothing at the forge is touched**: the
  /// token stays valid there until the person revokes it; machine vaults keep their own entries.
  Future<void> remove(ForgeEntry entry) => _asking(() async {
    await _tokens.delete(entry.address);
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
    final token = await _tokens.read(entry.address);
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
    final token = await _tokens.read(entry.address);
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
    isProject.clear();
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
    isProject.clear();
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

  Future<void> _asking(Future<void> Function() action) async {
    busy = true;
    problem = null;
    notifyListeners();
    try {
      await action();
    } on ForgeRefused catch (refused) {
      problem = refused.words;
    } on FormatException catch (error) {
      problem = error.message;
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
