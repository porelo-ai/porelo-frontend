import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:porelo_host/porelo_host.dart' show HostCardSsh, SecretsFile, PreparedHost, HostPlan, checkHostName;

import 'desk.dart';
import 'host_protocol.dart';
import 'machines.dart';
import 'registry_checkout.dart';
import 'run_here.dart' show WorkspaceRefused;

bool _sameStored(Object? left, Object? right) {
  if (left is Map && right is Map) {
    return left.length == right.length &&
        left.keys.every((key) => right.containsKey(key) && _sameStored(left[key], right[key]));
  }
  if (left is List && right is List) {
    return left.length == right.length &&
        Iterable<int>.generate(left.length).every((index) => _sameStored(left[index], right[index]));
  }
  return left == right;
}

/// A validated rental identity and optional signed-state setup progress.
@immutable
class HostUpRecord {
  /// Keeps public setup references; legacy records can only recover the rental.
  const HostUpRecord({
    required this.scalewayProject,
    this.host,
    this.hostName = '',
    this.account = '',
    this.publicKey = '',
    this.forge = true,
    this.preparedHost,
    this.rentalTag,
    this.setupFolder,
    this.collection = '',
    this.collectionSha256 = '',
    this.preparing = false,
    this.startedAt,
    this.protocol = const [],
    this.legacy = false,
  });

  /// The explanation shown wherever an older rental is recovered.
  static const legacyExplanation = 'Made before one-click joining: give it back or set it up again.';

  /// The provider project that owns the billed server.
  final String scalewayProject;

  /// The settings key, including migrated project-mode rentals.
  final String? host;

  /// The server tag's name, empty for a legacy project-mode rental.
  final String hostName;

  /// The legacy project account, used only to identify its rental.
  final String account;

  /// The original provider tag retained when a legacy rental is set up again.
  final String? rentalTag;

  /// The original provider identity, independent of a replacement host card's name.
  String rentalTagFor(String project) =>
      rentalTag ?? (hostName.isEmpty ? HostPlan.tagFor(project) : HostPlan.serverTagFor(hostName));

  /// The person's public identity reference for new setup.
  final String publicKey;

  /// Whether setup includes a host forge.
  final bool forge;

  /// The checked SSH completion, absent until confirmed.
  final PreparedHost? preparedHost;

  /// The old setup location, retained only to identify a migrated rental.
  final String? setupFolder;

  /// The debug collection reference, never a credential.
  final String collection;

  /// The collection's expected digest.
  final String collectionSha256;

  /// Whether setup has not yet confirmed completion.
  final bool preparing;

  /// The UTC setup start, if recorded.
  final DateTime? startedAt;

  /// The retained public protocol.
  final List<HostProtocolEntry> protocol;

  /// Whether obsolete setup credentials must never be resumed.
  final bool legacy;

  /// Keeps recovery and its original rental identity throughout setup.
  HostUpRecord withPreparation(DateTime? instant) => _copy(preparing: instant != null, startedAt: instant);

  /// Replaces the public protocol without changing the rental identity.
  HostUpRecord withProtocol(List<HostProtocolEntry> entries) => _copy(protocol: List.unmodifiable(entries));

  /// Keeps only a checked SSH completion from the new setup flow.
  HostUpRecord withPreparedHost(PreparedHost value) {
    if (legacy || value.name != hostName) {
      throw StateError('The completion does not belong to this signed-state setup.');
    }
    return _copy(preparedHost: value);
  }

  /// Assigns a legacy project record to its migrated host settings key.
  HostUpRecord forHost(String name, {required String rentalProject}) {
    SecretsFile.checkHost(name);
    final tag = rentalTagFor(rentalProject);
    HostPlan.lockNameForTag(tag);
    return _copy(host: name, rentalTag: tag);
  }

  HostUpRecord _copy({
    bool? preparing,
    DateTime? startedAt,
    List<HostProtocolEntry>? protocol,
    PreparedHost? preparedHost,
    String? host,
    String? rentalTag,
  }) => HostUpRecord(
    scalewayProject: scalewayProject,
    host: host ?? this.host,
    hostName: hostName,
    account: account,
    rentalTag: rentalTag ?? this.rentalTag,
    publicKey: publicKey,
    forge: forge,
    preparedHost: preparedHost ?? this.preparedHost,
    setupFolder: setupFolder,
    collection: collection,
    collectionSha256: collectionSha256,
    preparing: preparing ?? this.preparing,
    startedAt: preparing == false ? null : startedAt ?? this.startedAt,
    protocol: protocol ?? this.protocol,
    legacy: legacy,
  );

  /// Reads the minimum recovery identity before interpreting any optional setup state.
  ///
  /// Retired trust and credential metadata in old records is deliberately ignored. Corrupt
  /// progress cannot erase the provider identity needed to give a paid server back.
  static HostUpRecord? fromStored(Object? value) {
    if (value is! Map) return null;
    final provider = value['scalewayProject'];
    if (provider is! String || !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$').hasMatch(provider)) return null;
    final tag = value['rentalTag'];
    if (tag != null) {
      if (tag is! String) return null;
      try {
        HostPlan.lockNameForTag(tag);
      } on FormatException {
        return null;
      }
    }
    final marker = value['oneClick'];
    if (marker != null && marker is! bool) return null;
    final legacy = marker != true;
    final host = value['host'];
    final name = value['hostName'] ?? '';
    final account = value['account'] ?? '';
    if (host != null && host is! String || name is! String || account is! String) return null;
    try {
      if (host is String) {
        SecretsFile.checkHost(host);
      }
      if (name.isNotEmpty) {
        checkHostName(name);
      }
      if (account.isNotEmpty && !Settings.isUserName(account)) return null;
    } on FormatException {
      return null;
    }
    final folder = value['setupFolder'];
    final setupFolder = folder is String && path.isAbsolute(folder) && !RegExp(r'[\x00\r\n]').hasMatch(folder)
        ? folder
        : null;
    final preparing = value['preparing'] == true;
    final start = value['startedAt'];
    final instant = start is String ? DateTime.tryParse(start) : null;
    final startedAt = instant?.isUtc == true ? instant : null;
    if (legacy) {
      return HostUpRecord(
        scalewayProject: provider,
        host: host as String?,
        hostName: name,
        account: account,
        rentalTag: tag as String?,
        setupFolder: setupFolder,
        legacy: true,
        preparing: preparing,
        startedAt: startedAt,
      );
    }
    final publicKey = value['publicKey'];
    final forge = value['forge'] ?? true;
    final collection = value['collection'] ?? '';
    final digest = value['collectionSha256'] ?? '';
    if (name.isEmpty ||
        publicKey is! String ||
        publicKey.isEmpty ||
        RegExp(r'[\x00\r\n]').hasMatch(publicKey) ||
        forge is! bool ||
        collection is! String ||
        digest is! String ||
        collection.contains('\x00') ||
        digest.isNotEmpty && !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(digest) ||
        preparing && startedAt == null) {
      return null;
    }
    PreparedHost? prepared;
    try {
      if (value['preparedHost'] != null) {
        prepared = PreparedHost.read(value['preparedHost']);
        if (prepared.name != name) return null;
      }
    } on FormatException {
      return null;
    }
    return HostUpRecord(
      scalewayProject: provider,
      host: host as String?,
      hostName: name,
      publicKey: publicKey,
      rentalTag: tag as String?,
      forge: forge,
      preparedHost: prepared,
      setupFolder: setupFolder,
      collection: collection,
      collectionSha256: digest,
      preparing: preparing,
      startedAt: startedAt,
      protocol: HostProtocolEntry.readMany(value['protocol']) ?? const [],
    );
  }

  /// The minimum recovery data or the new flow's public setup state.
  Map<String, Object?> get stored => {
    'scalewayProject': scalewayProject,
    if (host != null) 'host': host,
    if (hostName.isNotEmpty) 'hostName': hostName,
    if (account.isNotEmpty) 'account': account,
    if (rentalTag != null) 'rentalTag': rentalTag,
    if (setupFolder != null) 'setupFolder': setupFolder,
    if (preparing) 'preparing': true,
    if (startedAt != null) 'startedAt': startedAt!.toUtc().toIso8601String(),
    if (!legacy) ...{
      'oneClick': true,
      'publicKey': publicKey,
      'forge': forge,
      if (preparedHost != null) 'preparedHost': preparedHost!.values,
      if (collection.isNotEmpty) 'collection': collection,
      if (collectionSha256.isNotEmpty) 'collectionSha256': collectionSha256,
      if (protocol.isNotEmpty) 'protocol': [for (final entry in protocol) entry.stored],
    },
  };

  /// Builds setup arguments only for signed-state records.
  List<String> arguments(String project) {
    if (legacy) throw StateError('This rental needs setup again through signed state.');
    return [
      '--host-name',
      hostName,
      '--public-key',
      publicKey,
      '--scaleway-project',
      scalewayProject,
      '--forge',
      '$forge',
      if (rentalTag != null) ...['--rental-tag', rentalTag!],
    ];
  }

  /// Identifies give-back without opening an obsolete SSH connection.
  List<String> giveBackArguments(String project) => [
    if (hostName.isEmpty) ...['--project', project, '--account', account] else ...['--host-name', hostName],
    '--scaleway-project',
    scalewayProject,
    if (legacy) '--legacy-rental',
    if (rentalTag != null) ...['--rental-tag', rentalTag!],
  ];
}

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

  /// How long resolved attention rows remain readable, in minutes; zero removes them immediately.
  int get keepResolvedMinutes => _keepResolvedMinutes;
  int _keepResolvedMinutes = 60;

  /// Keeps the retention choice without persisting the rows themselves.
  Future<void> setKeepResolvedMinutes(int minutes) async {
    if (minutes < 0) return;
    _keepResolvedMinutes = minutes;
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

  /// The organisation's registry repository, a credential-free `git@` or `https` address, or null before
  /// it was chosen. Only the address is kept: Git reaches it with the person's own access.
  String? get registryRepository => _registryRepository;
  String? _registryRepository;

  /// Keeps [repository] as the registry's address, or forgets it when null.
  ///
  /// Throws a `WorkspaceRefused` without repeating the input when it carries a user name, password or
  /// token, so a pasted secret is never kept.
  Future<void> setRegistryRepository(String? repository) async {
    final trimmed = repository?.trim();
    if (trimmed != null && trimmed.isNotEmpty) RegistryCheckout.checkRepository(trimmed);
    _registryRepository = trimmed == null || trimmed.isEmpty ? null : trimmed;
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
    final retention = stored['keepResolvedMinutes'];
    if (retention is int && retention >= 0) _keepResolvedMinutes = retention;
    final user = stored['workUser'];
    if (user is String && isUserName(user)) _workUser = user;
    final registry = stored['registryRepository'];
    _registryRepository = null;
    if (registry is String) {
      try {
        RegistryCheckout.checkRepository(registry);
        _registryRepository = registry;
      } on WorkspaceRefused {
        // An address written by hand with credentials in it is not taken; the person chooses it again.
      }
    }
    _messagePeople.clear();
    final people = stored['messagePeople'];
    if (people is Map) {
      for (final entry in people.entries) {
        final machine = entry.key;
        final projects = entry.value;
        if (machine is! String || !_isConversationName(machine) || projects is! Map) continue;
        for (final entry in projects.entries) {
          final project = entry.key;
          final person = entry.value;
          if (project is String && _isConversationName(project) && person is String && _isMessagePerson(person)) {
            (_messagePeople[machine] ??= <String, String>{})[project] = person;
          }
        }
      }
    }
    final draft = stored['setupDraft'];
    if (draft is Map) _setupDraft = <String, Object?>{for (final e in draft.entries) '${e.key}': e.value};
    final folders = stored['tresorFolders'];
    _tresorFolders = <String, String>{};
    if (folders is Map) {
      for (final entry in folders.entries) {
        final project = entry.key;
        final folder = entry.value;
        if (project is String &&
            project.isNotEmpty &&
            folder is String &&
            folder.trim().isNotEmpty &&
            !folder.contains('\x00')) {
          _tresorFolders[project] = folder;
        }
      }
    }
    final secrets = stored['secretsFile'];
    _secretsFile = secrets is String && secrets.startsWith('/') && !secrets.contains('\x00') ? secrets : null;
    _hostUps.clear();
    var migratedHosts = false;
    final migratedHostKeys = <String, String>{};
    final hostUps = stored['hostUps'];
    if (hostUps is Map) {
      final candidates = <({String key, String host, HostUpRecord record})>[];
      for (final entry in hostUps.entries) {
        final key = entry.key;
        final record = HostUpRecord.fromStored(entry.value);
        if (key is! String || record == null) continue;
        final folder = record.setupFolder;
        final host =
            record.host ??
            (folder != null && path.basename(path.dirname(folder)) == 'hosts' ? path.basename(folder) : key);
        try {
          SecretsFile.checkHost(host);
        } on Exception {
          continue;
        }
        candidates.add((key: key, host: host, record: record));
      }
      // Ambiguous folders must not prevent startup or collapse two retained server identities.
      final unique = candidates.map((candidate) => candidate.host).toSet().length == candidates.length;
      for (final candidate in candidates) {
        final (:key, :host, :record) = candidate;
        var target = unique ? host : key;
        var saved = record;
        if (unique && host != key) {
          try {
            saved = record.forHost(host, rentalProject: key);
          } on FormatException {
            // An invalid old key must not create a tag that loses recovery on restart.
            target = key;
          }
        }
        _hostUps[target] = saved;
        migratedHosts |= target != key;
        if (target != key) migratedHostKeys[key] = target;
      }
    }
    _projectHosts.clear();
    final projectHosts = stored['projectHosts'];
    if (projectHosts is Map) {
      for (final entry in projectHosts.entries) {
        if (entry.key is! String || entry.value is! String) continue;
        try {
          SecretsFile.checkHost(entry.key as String);
          SecretsFile.checkHost(entry.value as String);
          _projectHosts[entry.key as String] = migratedHostKeys[entry.value] ?? entry.value as String;
        } on Exception {
          continue;
        }
      }
    }
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
          if (each is Map<String, Object?>)
            {
              ...each,
              if (migratedHostKeys.containsKey(each['hostProject']))
                'hostProject': migratedHostKeys[each['hostProject']],
            },
      ];
    }
    final forges = stored['forges'];
    if (forges is List) _forges = List<Object?>.of(forges);
    if (migratedHosts) await _write();
    notifyListeners();
  }

  final _messagePeople = <String, Map<String, String>>{};

  static bool _isConversationName(String name) => name.trim().isNotEmpty && !name.contains('\x00');

  static bool _isMessagePerson(String person) => RegExp(r'^[a-z0-9._=\-]+$').hasMatch(person);

  /// The name this computer joined a machine's project room as, subject to its member list.
  String? messagePerson(String machine, String project) => _messagePeople[machine]?[project];

  /// Keeps only a confirmed person's name, or forgets a member the daemon no longer lists.
  Future<void> rememberMessagePerson(String machine, String project, String? person) async {
    if (!_isConversationName(machine) ||
        !_isConversationName(project) ||
        (person != null && !_isMessagePerson(person))) {
      throw ArgumentError('A machine, project, and valid chat name are required.');
    }
    if (messagePerson(machine, project) == person) return;
    if (person == null) {
      final projects = _messagePeople[machine]!;
      projects.remove(project);
      if (projects.isEmpty) _messagePeople.remove(machine);
    } else {
      (_messagePeople[machine] ??= <String, String>{})[project] = person;
    }
    await _write();
  }

  Map<String, String> _tresorFolders = <String, String>{};

  String? _secretsFile;

  /// Where the person's `secrets.kdbx` lies on this desktop, or null before it is chosen. Only its path is kept.
  String? get secretsFile => _secretsFile;

  /// Keeps where the secrets file lies, never anything of what it holds.
  Future<void> rememberSecretsFile(String? file) async {
    if (file != null && (!file.startsWith('/') || file.contains('\x00'))) {
      throw ArgumentError('The secrets file needs an absolute path.');
    }
    _secretsFile = file;
    await _write();
    notifyListeners();
  }

  final _hostUps = <String, HostUpRecord>{};
  final _projectHosts = <String, String>{};

  /// The host this project was successfully brought onto, absent before a confirmed bring.
  String? projectHost(String project) => _projectHosts[project];

  /// Keeps the host association only after the bring has been confirmed.
  Future<void> rememberProjectHost(String project, String host) async {
    SecretsFile.checkHost(project);
    SecretsFile.checkHost(host);
    final previous = _projectHosts[project];
    _projectHosts[project] = host;
    try {
      await _write();
      final saved = (await _store.read())['projectHosts'];
      if (saved is! Map || saved[project] != host) {
        throw const FileSystemException('Cannot keep the project host association in the interface settings.');
      }
    } on Exception {
      if (previous == null) {
        _projectHosts.remove(project);
      } else {
        _projectHosts[project] = previous;
      }
      rethrow;
    }
    notifyListeners();
  }

  /// Clears the association only after the host confirms removal; following is independent.
  Future<void> forgetProjectHost(String project, {required String host}) async {
    if (_projectHosts[project] != host) return;
    final previous = _projectHosts.remove(project);
    if (previous == null) return;
    try {
      await _write();
      final saved = (await _store.read())['projectHosts'];
      if (saved is! Map || saved.containsKey(project)) {
        throw const FileSystemException('Cannot clear the project host association in the interface settings.');
      }
    } on Exception {
      _projectHosts[project] = previous;
      rethrow;
    }
    notifyListeners();
  }

  /// Every kept host setup, keyed by host name.
  Map<String, HostUpRecord> get hostUps => Map.unmodifiable(_hostUps);

  /// The arguments used for the host's last setup, absent when none were kept.
  HostUpRecord? hostUp(String host) => _hostUps[host];

  /// Removes recovery only after provider-confirmed give-back.
  Future<void> forgetHostUp(String host) async {
    final previous = _hostUps.remove(host);
    if (previous == null) return;
    try {
      await _write();
      final saved = (await _store.read())['hostUps'];
      if (saved is! Map || saved.containsKey(host)) {
        throw const FileSystemException('Cannot clear the confirmed rental record.');
      }
    } on Exception {
      _hostUps[host] = previous;
      rethrow;
    }
    notifyListeners();
  }

  /// Persists the setup before a process can rent a host that would otherwise be lost.
  Future<void> rememberHostUp(String host, HostUpRecord record) async {
    host = record.host ?? host;
    SecretsFile.checkHost(host);
    if (host.isEmpty || host.contains('\x00') || HostUpRecord.fromStored(record.stored) == null) {
      throw ArgumentError('A host and a complete host setup record are required.');
    }
    final previous = _hostUps[host];
    _hostUps[host] = record;
    try {
      await _write();
      final saved = (await _store.read())['hostUps'];
      final savedRecord = saved is Map ? saved[host] : null;
      if (savedRecord is! Map || !_sameStored(savedRecord, record.stored)) {
        throw const FileSystemException('Cannot keep the host setup in the interface settings.');
      }
    } on Exception {
      if (previous == null) {
        _hostUps.remove(host);
      } else {
        _hostUps[host] = previous;
      }
      rethrow;
    }
    notifyListeners();
  }

  /// The locally synced Tresorit folder chosen for this project.
  String? tresorFolder(String project) => _tresorFolders[project];

  /// Keeps a folder in the interface's own settings, never the project file.
  Future<void> rememberTresorFolder(String project, String? folder) async {
    if (project.isEmpty || (folder != null && (folder.trim().isEmpty || folder.contains('\x00')))) {
      throw ArgumentError('A project and a valid folder are required.');
    }
    if (folder == null) {
      _tresorFolders.remove(project);
    } else {
      _tresorFolders[project] = folder;
    }
    await _write();
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
      final project = each['hostProject'];
      final machine = Machine.fromStored(each, legacyHost: project is String && hostUp(project)?.legacy == true);
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
    final cards = <HostCardSsh>[];
    for (final machine in machines) {
      final card = machine.hostCard;
      if (card == null) continue;
      card.checkAgainst(cards);
      cards.add(card);
    }
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

  // Protocol updates and other preferences share one atomic replacement file.
  Future<void>? _writes;

  /// Keeps unknown settings because the file also serves other versions and the IntelliJ plugin.
  Future<void> _write() {
    final known = _known;
    final writing = _writes?.then((_) => _writeKnown(known)) ?? _writeKnown(known);
    late final Future<void> tail;
    void finished() {
      if (identical(_writes, tail)) _writes = null;
    }

    tail = writing.then((_) => finished(), onError: (Object _, StackTrace _) => finished());
    _writes = tail;
    return writing;
  }

  Future<void> _writeKnown(Map<String, Object?> known) async {
    final kept = <String, Object?>{
      for (final entry in (await _store.read()).entries)
        if (entry.key != 'forgeCa' && !known.containsKey(entry.key)) entry.key: entry.value,
    };
    await _store.write(<String, Object?>{...kept, ...known});
  }

  Map<String, Object?> get _known => <String, Object?>{
    'refreshSeconds': _refreshSeconds,
    'keepResolvedMinutes': _keepResolvedMinutes,
    'workUser': _workUser,
    'registryRepository': _registryRepository,
    'messagePeople': {for (final entry in _messagePeople.entries) entry.key: Map<String, String>.of(entry.value)},
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
    'tresorFolders': _tresorFolders,
    'secretsFile': _secretsFile,
    'hostUps': {for (final entry in _hostUps.entries) entry.key: entry.value.stored},
    'projectHosts': Map<String, String>.of(_projectHosts),
  };

  static ThemeMode _appearanceNamed(Object? name) =>
      ThemeMode.values.firstWhere((mode) => mode.name == name, orElse: () => ThemeMode.system);
}
