import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'desk.dart';
import 'machines.dart';

/// Where the interface's own preferences live.
///
/// Deliberately a file this application writes itself rather than a preferences plugin: the
/// only thing being stored is which theme somebody picked, and a plugin would add platform
/// code, a registrant entry and a mock to every widget test that touches the shell.
abstract class SettingsStore {
  /// Reads what was stored, or an empty map when nothing has been.
  Future<Map<String, Object?>> read();

  /// Replaces what is stored.
  Future<void> write(Map<String, Object?> values);
}

/// The store used by the application: one JSON file under the user's config directory.
class FileSettingsStore implements SettingsStore {
  /// Constructor, optionally pointed at another file for tests.
  FileSettingsStore({File? file}) : _file = file ?? defaultFile();

  final File _file;

  /// Where it is kept unless told otherwise, read from [environment] or this process's.
  /// On Linux `$XDG_CONFIG_HOME/porelo/frontend.json`, on Windows `%APPDATA%\porelo\frontend.json`:
  /// the IntelliJ plugin reads the same file. [operatingSystem] is `Platform.operatingSystem`'s word.
  static File defaultFile([Map<String, String>? environment, String? operatingSystem]) {
    final here = Desk.of(operatingSystem ?? Platform.operatingSystem, environment ?? Platform.environment);
    return File(here.join(<String>[here.configuration, 'frontend.json']));
  }

  @override
  Future<Map<String, Object?>> read() async {
    // A missing or unreadable file is somebody's first run, not a failure worth reporting:
    // the interface has to open either way.
    try {
      if (!await _file.exists()) return const {};
      final decoded = jsonDecode(await _file.readAsString());
      return decoded is Map<String, Object?> ? decoded : const {};
    } on Exception {
      return const {};
    }
  }

  /// Replaces what is stored, in one step and readable by nobody else.
  ///
  /// **Written beside it and renamed over it.** A write in place is not one step: a crash or a
  /// power cut halfway through leaves truncated JSON, which the read below cannot tell from a
  /// first run — so the answer to "why are my machines gone" would be a file that says nothing
  /// about what happened to it. A rename within a directory is atomic: either the old file or the
  /// whole new one.
  ///
  /// Owner-only, because it names the machines somebody watches and the accounts they log in as.
  /// Not secrets, and not everybody's business either.
  @override
  Future<void> write(Map<String, Object?> values) async {
    try {
      await _file.parent.create(recursive: true);
      final beside = File('${_file.path}.writing');
      await beside.writeAsString(jsonEncode(values), flush: true);
      // Before the rename, so the file is never briefly readable by others under its real name.
      await desk.keepPrivate(beside.path);
      await beside.rename(_file.path);
    } on Exception {
      // Losing a theme choice is not worth interrupting anybody over.
    }
  }
}

/// A store that keeps values in memory, for tests that restart the interface.
class MemorySettingsStore implements SettingsStore {
  /// Constructor, optionally starting from values as if written by an earlier run.
  MemorySettingsStore([Map<String, Object?> initial = const {}]) : _values = Map<String, Object?>.of(initial);

  Map<String, Object?> _values;

  @override
  Future<Map<String, Object?>> read() async => Map<String, Object?>.of(_values);

  @override
  Future<void> write(Map<String, Object?> values) async => _values = Map<String, Object?>.of(values);
}

/// What the person chose about how the interface looks.
class Settings extends ChangeNotifier {
  /// Constructor taking where the choices are kept.
  Settings(this._store);

  final SettingsStore _store;

  ThemeMode _appearance = ThemeMode.system;

  /// Light, dark, or whatever the desktop says.
  ThemeMode get appearance => _appearance;

  /// How often every machine is asked again on its own, in seconds. Zero asks only when told.
  ///
  /// A push covers the tasks; nothing pushes the project list, so a project removed at the
  /// machine would otherwise stay on screen until something here changed it.
  int get refreshSeconds => _refreshSeconds;
  int _refreshSeconds = 60;

  /// Sets how often every machine is asked again, and keeps it for the next run.
  Future<void> setRefreshSeconds(int seconds) async {
    _refreshSeconds = seconds;
    notifyListeners();
    await _write();
  }

  /// The user a new machine runs work as, which the wizard asks Porelo's setup script to create.
  String get workUser => _workUser;
  String _workUser = 'agent';

  /// Whether [name] can be a user on a Linux machine: what `useradd` accepts by default.
  static bool isUserName(String name) => RegExp(r'^[a-z_][a-z0-9_-]{0,31}$').hasMatch(name);

  /// A machine setup the wizard started and did not finish, as `SetupRun` stores it, or null.
  ///
  /// **Never a private key**: only where a kept key lives. Kept so a wizard that was canceled, or
  /// a window that was closed, picks up where it stopped rather than asking everything again.
  Map<String, Object?>? get setupDraft => _setupDraft;
  Map<String, Object?>? _setupDraft;

  /// Keeps [draft] as the unfinished setup, or forgets it when null.
  Future<void> setSetupDraft(Map<String, Object?>? draft) async {
    _setupDraft = draft;
    notifyListeners();
    await _write();
  }

  /// Sets the user new machines run work as, and keeps it for the next run.
  Future<void> setWorkUser(String name) async {
    if (!isUserName(name)) return;
    _workUser = name;
    notifyListeners();
    await _write();
  }

  /// Reads what an earlier run stored. Safe to call before the first frame.
  Future<void> load() async {
    final stored = await _store.read();
    _appearance = _appearanceNamed(stored['appearance']);
    final every = stored['refreshSeconds'];
    if (every is int && every >= 0) _refreshSeconds = every;
    final user = stored['workUser'];
    if (user is String && isUserName(user)) _workUser = user;
    final draft = stored['setupDraft'];
    if (draft is Map) _setupDraft = <String, Object?>{for (final e in draft.entries) '${e.key}': e.value};
    final place = stored['place'];
    if (place is Map) {
      _place = <String, String>{
        for (final entry in place.entries)
          if (entry.value is String) '${entry.key}': entry.value as String,
      };
    }
    final seen = stored['seenSilent'];
    if (seen is List) _seenSilent = seen.whereType<String>().toList();
    final muted = stored['muted'];
    if (muted is List) _muted = muted.whereType<String>().toList();
    final homeservers = stored['homeservers'];
    if (homeservers is List) {
      _homeservers = <({String machine, String project, int port})>[
        for (final each in homeservers.whereType<Map<String, dynamic>>())
          if (each['machine'] is String && each['project'] is String && each['port'] is int)
            (machine: each['machine'] as String, project: each['project'] as String, port: each['port'] as int),
      ];
    }
    final templates = stored['templates'];
    if (templates is List) {
      _templates = <Map<String, Object?>>[
        for (final each in templates)
          if (each is Map<String, Object?>) each,
      ];
    }
    final machines = stored['machines'];
    if (machines is List) {
      _machines = <Map<String, Object?>>[
        for (final each in machines)
          if (each is Map<String, Object?>) each,
      ];
    }
    final forges = stored['forges'];
    if (forges is List) _forges = List<Object?>.of(forges);
    notifyListeners();
  }

  /// Chooses an appearance and remembers it for the next run.
  Future<void> setAppearance(ThemeMode appearance) async {
    if (appearance == _appearance) return;
    _appearance = appearance;
    notifyListeners();
    await _write();
  }

  /// The machines an earlier run was watching.
  Future<List<Machine>> machines() async {
    final stored = (await _store.read())['machines'];
    if (stored is! List) return const <Machine>[];
    // One unusable entry is dropped and the rest are kept. A machine with no name, or with neither a
    // socket nor a kind of its own, cannot be watched or told apart from another, and losing every
    // other machine over it would be the worse answer. An entry with a kind is kept even without a
    // socket: a WSL distribution has none, and a kind this version does not know is not its to drop.
    // A second entry of a name already read is dropped too: every machine is told apart by its name,
    // and two of one would send one's calls through the other's way in.
    final machines = <Machine>[];
    for (final each in stored) {
      if (each is! Map<String, Object?>) continue;
      final machine = Machine.fromStored(each);
      if (machine.name.isEmpty || (machine.socketPath.isEmpty && machine.kind.isEmpty)) continue;
      if (machines.any((kept) => kept.name == machine.name)) continue;
      machines.add(machine);
    }
    return machines;
  }

  /// Where somebody was when the interface last closed.
  ///
  /// A restart, asked for or not, comes back to the same place. Losing it is small every time and
  /// tiring every time, which is the kind of thing nobody reports.
  Future<Map<String, String>> whereYouWere() async {
    final stored = (await _store.read())['place'];
    if (stored is! Map) return const <String, String>{};
    return <String, String>{
      for (final entry in stored.entries)
        if (entry.value is String) '${entry.key}': entry.value as String,
    };
  }

  /// Remembers where somebody is, for the next run.
  Future<void> rememberWhereYouWere(Map<String, String> place) async {
    if (_place.toString() == place.toString()) return;
    _place = place;
    await _write();
  }

  Map<String, String> _place = const <String, String>{};

  /// Projects nobody wants to be told about.
  Future<Set<String>> mutedProjects() async {
    final stored = (await _store.read())['muted'];
    return stored is List ? stored.whereType<String>().toSet() : <String>{};
  }

  /// Remembers which projects are turned off.
  Future<void> rememberMutedProjects(Set<String> projects) async {
    _muted = projects.toList()..sort();
    await _write();
  }

  List<String> _muted = const <String>[];

  /// The homeservers a person joined from this computer, kept forwarded while the window runs and
  /// raised again when it starts: each a machine, a project and the port its homeserver listens on.
  List<({String machine, String project, int port})> get homeservers => List.unmodifiable(_homeservers);

  /// Remembers [machine]'s homeserver for [project] on [port], replacing what was kept for them.
  Future<void> rememberHomeserver(String machine, String project, int port) async {
    _homeservers = <({String machine, String project, int port})>[
      for (final each in _homeservers)
        if (each.machine != machine || each.project != project) each,
      (machine: machine, project: project, port: port),
    ];
    await _write();
  }

  List<({String machine, String project, int port})> _homeservers =
      const <({String machine, String project, int port})>[];

  /// Machines whose silence somebody has seen, until they answer again.
  Set<String> get seenSilent => Set<String>.unmodifiable(_seenSilent);
  List<String> _seenSilent = const <String>[];

  /// Keeps which silent machines somebody has seen.
  Future<void> setSeenSilent(Set<String> machines) async {
    _seenSilent = machines.toList()..sort();
    notifyListeners();
    await _write();
  }

  /// Remembers which machines to open next time.
  Future<void> rememberMachines(List<Machine> machines) async {
    _machines = <Map<String, Object?>>[for (final machine in machines) machine.stored];
    await _write();
  }

  List<Map<String, Object?>> _machines = const <Map<String, Object?>>[];

  /// The recurring jobs somebody named, as stored.
  ///
  /// **Kept here rather than with the project, and that is settled rather than temporary.** The
  /// requirement asks for templates shared with the project; the answer is no.
  ///
  /// Not because a project file cannot be written — `SetEgress` edits `project.yml` in place, so
  /// it plainly can. A job kept *with a project* is one the machine could start with nobody
  /// present, and there is no scheduler: work starts when somebody starts it. So a template lives
  /// beside this interface's other choices and follows the person.
  Future<List<Map<String, Object?>>> templates() async {
    final stored = (await _store.read())['templates'];
    if (stored is! List) return const <Map<String, Object?>>[];
    return <Map<String, Object?>>[
      for (final each in stored)
        if (each is Map<String, Object?>) each,
    ];
  }

  /// The forges set up on this computer, as a forge entry keeps them: kind, name and address.
  /// **Never a token**: those are in the keychain.
  List<Object?> get forges => _forges;
  List<Object?> _forges = const <Object?>[];

  /// Keeps the forges set up on this computer.
  Future<void> rememberForges(List<Map<String, Object?>> forges) async {
    _forges = forges;
    await _write();
  }

  /// Remembers the recurring jobs.
  Future<void> rememberTemplates(List<Map<String, Object?>> templates) async {
    _templates = templates;
    await _write();
  }

  List<Map<String, Object?>> _templates = const <Map<String, Object?>>[];

  /// Writes every choice, **keeping the keys this version does not know**: the file is shared with
  /// the IntelliJ plugin and outlives this version, and what a later one wrote is not this one's to
  /// drop.
  Future<void> _write() async {
    final known = _known;
    final kept = <String, Object?>{
      for (final entry in (await _store.read()).entries)
        if (!known.containsKey(entry.key)) entry.key: entry.value,
    };
    await _store.write(<String, Object?>{...kept, ...known});
  }

  Map<String, Object?> get _known => <String, Object?>{
    'refreshSeconds': _refreshSeconds,
    'workUser': _workUser,
    'setupDraft': _setupDraft,
    'appearance': _appearance.name,
    'machines': _machines,
    'muted': _muted,
    'homeservers': <Map<String, Object?>>[
      for (final each in _homeservers)
        <String, Object?>{'machine': each.machine, 'project': each.project, 'port': each.port},
    ],
    'seenSilent': _seenSilent,
    'place': _place,
    'templates': _templates,
    'forges': _forges,
  };

  static ThemeMode _appearanceNamed(Object? name) =>
      ThemeMode.values.firstWhere((mode) => mode.name == name, orElse: () => ThemeMode.system);
}
