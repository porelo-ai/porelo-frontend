import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:porelo_host/porelo_host.dart'
    show HostCardSsh, HostFilesRefused, SecretsFile, PreparedHost, HostPlan, HostPreparationSettings, checkHostName;

import 'desk.dart';
import 'host_protocol.dart';
import 'machines.dart';

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
  /// Keeps public setup references.
  const HostUpRecord({
    this.scalewayProject = '',
    this.givenAddress = '',
    this.givenHostKey = '',
    this.host,
    this.hostName = '',
    this.account = '',
    this.publicKey = '',
    this.forge = true,
    this.preparationSettings = const HostPreparationSettings(),
    this.preparedHost,
    this.rentalTag,
    this.setupFolder,
    this.collection = '',
    this.collectionSha256 = '',
    this.machineFile = '',
    this.preparing = false,
    this.startedAt,
    this.protocol = const [],
  });

  /// The explanation shown wherever an older rental is recovered.

  /// The provider project that owns the billed server.
  final String scalewayProject;

  /// The existing server's address, empty for provider rentals.
  final String givenAddress;

  /// Whether a rental stands behind it, rather than a machine that simply exists.
  bool get isRental => givenAddress.isEmpty && scalewayProject.isNotEmpty;

  /// The existing server's independently supplied SSH host key.
  final String givenHostKey;

  /// The settings key, including migrated project-mode rentals.
  final String? host;

  /// The server tag's name.
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

  /// The checked runner limits and local forward ends retained for setup retry.
  final HostPreparationSettings preparationSettings;

  /// The checked SSH completion, absent until confirmed.
  final PreparedHost? preparedHost;

  /// The old setup location, retained only to identify a migrated rental.
  final String? setupFolder;

  /// The debug collection reference, never a credential.
  final String collection;

  /// The collection's expected digest.
  final String collectionSha256;

  /// The private file holding what `up` hands the host of the organization.
  final String machineFile;

  /// Whether setup has not yet confirmed completion.
  final bool preparing;

  /// The UTC setup start, if recorded.
  final DateTime? startedAt;

  /// The retained public protocol.
  final List<HostProtocolEntry> protocol;

  /// Keeps recovery and its original rental identity throughout setup.
  HostUpRecord withPreparation(DateTime? instant) => _copy(preparing: instant != null, startedAt: instant);

  /// Replaces the public protocol without changing the rental identity.
  HostUpRecord withProtocol(List<HostProtocolEntry> entries) => _copy(protocol: List.unmodifiable(entries));

  /// Keeps only a checked SSH completion from the new setup flow.
  HostUpRecord withPreparedHost(PreparedHost value) {
    if (value.name != hostName) {
      throw StateError('The completion does not belong to this signed-state setup.');
    }
    return _copy(preparedHost: value);
  }

  /// Retains validated preparation choices without losing rental recovery.
  HostUpRecord withPreparationSettings(HostPreparationSettings value) {
    value.check();
    return HostUpRecord.fromStored({...stored, 'preparationSettings': value.stored})!;
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
    givenAddress: givenAddress,
    givenHostKey: givenHostKey,
    host: host ?? this.host,
    hostName: hostName,
    account: account,
    rentalTag: rentalTag ?? this.rentalTag,
    publicKey: publicKey,
    forge: forge,
    preparationSettings: preparationSettings,
    preparedHost: preparedHost ?? this.preparedHost,
    setupFolder: setupFolder,
    collection: collection,
    collectionSha256: collectionSha256,
    machineFile: machineFile,
    preparing: preparing ?? this.preparing,
    startedAt: preparing == false ? null : startedAt ?? this.startedAt,
    protocol: protocol ?? this.protocol,
  );

  /// Reads the minimum recovery identity before interpreting any optional setup state.
  ///
  /// Retired trust and credential metadata in old records is deliberately ignored. Corrupt
  /// progress cannot erase the provider identity needed to give a paid server back.
  static HostUpRecord? fromStored(Object? value) {
    if (value is! Map) return null;
    final provider = value['scalewayProject'];
    final givenAddress = value['givenAddress'] ?? '';
    final givenHostKey = value['givenHostKey'] ?? '';
    if (givenAddress is! String || givenHostKey is! String || provider is! String) return null;
    final given = givenAddress.isNotEmpty;
    if (given ? provider.isNotEmpty : !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$').hasMatch(provider)) return null;
    if (!given && givenHostKey.isNotEmpty) return null;
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
    if (marker != true) return null;
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
    final publicKey = value['publicKey'];
    final forge = value['forge'] ?? true;
    final collection = value['collection'] ?? '';
    final digest = value['collectionSha256'] ?? '';
    final machineFile = value['machineFile'] ?? '';
    if (name.isEmpty ||
        publicKey is! String ||
        !given && publicKey.isEmpty ||
        RegExp(r'[\x00\r\n]').hasMatch(publicKey) ||
        forge is! bool ||
        collection is! String ||
        digest is! String ||
        collection.contains('\x00') ||
        machineFile is! String ||
        machineFile.contains('\x00') ||
        digest.isNotEmpty && !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(digest) ||
        preparing && startedAt == null) {
      return null;
    }
    PreparedHost? prepared;
    HostPreparationSettings choices;
    try {
      choices = HostPreparationSettings.read(value['preparationSettings'] ?? <String, Object?>{});
      if (given) {
        PreparedHost.read({
          'name': name,
          'address': givenAddress,
          'ssh_port': 22,
          'ssh_host_key': givenHostKey,
          'services': choices.localServices,
        });
      }
      if (value['preparedHost'] != null) {
        prepared = PreparedHost.read(value['preparedHost']);
        if (prepared.name != name) return null;
      }
    } on FormatException {
      return null;
    }
    return HostUpRecord(
      scalewayProject: provider,
      givenAddress: givenAddress,
      givenHostKey: givenHostKey,
      host: host as String?,
      hostName: name,
      publicKey: publicKey,
      rentalTag: tag as String?,
      forge: forge,
      preparationSettings: choices,
      preparedHost: prepared,
      setupFolder: setupFolder,
      collection: collection,
      collectionSha256: digest,
      machineFile: machineFile,
      preparing: preparing,
      startedAt: startedAt,
      protocol: HostProtocolEntry.readMany(value['protocol']) ?? const [],
    );
  }

  /// The minimum recovery data or the new flow's public setup state.
  Map<String, Object?> get stored => {
    'scalewayProject': scalewayProject,
    if (givenAddress.isNotEmpty) ...{'givenAddress': givenAddress, 'givenHostKey': givenHostKey},
    if (host != null) 'host': host,
    if (hostName.isNotEmpty) 'hostName': hostName,
    if (account.isNotEmpty) 'account': account,
    if (rentalTag != null) 'rentalTag': rentalTag,
    if (setupFolder != null) 'setupFolder': setupFolder,
    if (preparing) 'preparing': true,
    if (startedAt != null) 'startedAt': startedAt!.toUtc().toIso8601String(),
    ...{
      'oneClick': true,
      'publicKey': publicKey,
      'forge': forge,
      'preparationSettings': preparationSettings.stored,
      if (preparedHost != null) 'preparedHost': preparedHost!.values,
      if (collection.isNotEmpty) 'collection': collection,
      if (collectionSha256.isNotEmpty) 'collectionSha256': collectionSha256,
      if (machineFile.isNotEmpty) 'machineFile': machineFile,
      if (protocol.isNotEmpty) 'protocol': [for (final entry in protocol) entry.stored],
    },
  };

  /// Builds setup arguments only for signed-state records.
  List<String> arguments(String project) {
    preparationSettings.check();
    return [
      '--host-name',
      hostName,
      '--public-key',
      publicKey,
      if (givenAddress.isNotEmpty) ...[
        '--given',
        givenAddress,
        '--host-key',
        givenHostKey,
      ] else ...[
        '--scaleway-project',
        scalewayProject,
      ],
      if (machineFile.isNotEmpty) ...['--machine-file', machineFile],
      ..._settingsAsChosen.arguments,
      if (rentalTag != null) ...['--rental-tag', rentalTag!],
    ];
  }

  /// Identifies give-back without opening an obsolete SSH connection.
  List<String> giveBackArguments(String project) => [
    if (hostName.isEmpty) ...['--project', project, '--account', account] else ...['--host-name', hostName],
    if (publicKey.isNotEmpty) ...['--public-key', publicKey],
    if (givenAddress.isNotEmpty) ...[
      '--given',
      givenAddress,
      '--host-key',
      givenHostKey,
    ] else ...[
      '--scaleway-project',
      scalewayProject,
    ],
    '--forge',
    '${_settingsAsChosen.forge}',
    '--kvm',
    '${_settingsAsChosen.kvm}',
    if (rentalTag != null) ...['--rental-tag', rentalTag!],
  ];

  /// The settings with this record's own forge, which an older record holds beside them.
  HostPreparationSettings get _settingsAsChosen => preparationSettings.withPlainChoices(
    forge: forge && preparationSettings.forge,
    kvm: forge && preparationSettings.forge && preparationSettings.kvm,
  );
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

  /// Puts a file from before the organization model aside, and answers whether it did, so that a person is told once.
  ///
  /// That file is one that holds settings and no [settingsForm]. It is renamed to `frontend.json.dropped`, never deleted
  /// and never migrated, and a file holding only the mark takes its place, so that a second start finds nothing to say.
  /// No file is a first run, and an unreadable one is read as empty as ever: neither is an old form. Where the rename
  /// fails nothing is said, and the next start tries again.
  Future<bool> dropOldForm() async {
    final Object? decoded;
    try {
      if (!await _file.exists()) return false;
      decoded = jsonDecode(await _file.readAsString());
    } on Exception {
      return false;
    }
    if (decoded is! Map<String, Object?> || decoded.isEmpty || decoded['form'] == settingsForm) return false;
    try {
      await _file.rename('${_file.path}.dropped');
    } on FileSystemException {
      return false;
    }
    await write({'form': settingsForm});
    return true;
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

/// The form of the settings file, written in it as `form`: settings without it are from before the organization model.
const settingsForm = 2;

/// What a person is told, once, when their saved settings were dropped.
const settingsDroppedWords =
    'Your saved settings came from before Porelo organizations, so Porelo started afresh; the old file is kept as frontend.json.dropped.';

/// A question about a blocked connection that ran out with nobody answering it.
class RanOutQuestion {
  /// Keeps what the row says of it.
  const RanOutQuestion({
    required this.id,
    required this.machine,
    required this.task,
    required this.shown,
    this.seen = false,
    this.seenAt = '',
  });

  /// Reads one from the settings file, or null for one it cannot read. One an older build kept has no `seenAt`.
  static RanOutQuestion? fromStored(Map<String, dynamic> stored) {
    final (id, machine, task, shown) = (stored['id'], stored['machine'], stored['task'], stored['shown']);
    if (id is! String || machine is! String || task is! String || shown is! String) return null;
    final seenAt = stored['seenAt'];
    return RanOutQuestion(
      id: id,
      machine: machine,
      task: task,
      shown: shown,
      seen: stored['seen'] == true,
      seenAt: seenAt is String ? seenAt : '',
    );
  }

  /// The machine, the question's identity there and when it ran out: one occurrence. An older build kept the
  /// identity alone, which no occurrence of today matches.
  final String id;

  /// The machine's name.
  final String machine;

  /// The work that asked.
  final String task;

  /// What it asked to reach.
  final String shown;

  /// Whether somebody said they have seen it.
  final bool seen;

  /// When somebody said so, ISO-8601; empty where an older build kept it.
  final String seenAt;

  /// The same question, seen at [at].
  RanOutQuestion seenAs(DateTime at) => RanOutQuestion(
    id: id,
    machine: machine,
    task: task,
    shown: shown,
    seen: true,
    seenAt: at.toUtc().toIso8601String(),
  );

  /// What the settings file holds of it.
  Map<String, Object> get stored => {
    'id': id,
    'machine': machine,
    'task': task,
    'shown': shown,
    'seen': seen,
    if (seenAt.isNotEmpty) 'seenAt': seenAt,
  };
}

/// What the person chose about how the interface looks.
class Settings extends ChangeNotifier {
  /// Constructor taking where the choices are kept.
  Settings(this._store);

  final SettingsStore _store;

  Map<String, Object?> _shellNavigation = {};

  /// The checked page and folds of the navigation tree.
  Map<String, Object?> get shellNavigation => Map.unmodifiable(_shellNavigation);

  /// Keeps navigation separately from the selected task and project.
  Future<void> rememberShellNavigation(Map<String, Object?> value) async {
    if (_sameStored(_shellNavigation, value)) return;
    _shellNavigation = Map.of(value);
    await _write();
  }

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
    if (stored['shellNavigation'] case final Map<dynamic, dynamic> navigation) {
      _shellNavigation = {
        for (final entry in navigation.entries)
          if (entry.key is String && entry.value is String) entry.key as String: entry.value,
        if (navigation['folded'] case final List<dynamic> folded) 'folded': folded.whereType<String>().toList(),
      };
    }
    _appearance = _appearanceNamed(stored['appearance']);
    final every = stored['refreshSeconds'];
    if (every is int && every >= 0) _refreshSeconds = every;
    final retention = stored['keepResolvedMinutes'];
    if (retention is int && retention >= 0) _keepResolvedMinutes = retention;
    final user = stored['workUser'];
    if (user is String && isUserName(user)) _workUser = user;
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
    // Absent in settings written before it: nobody is invited there.
    _messageInvited.clear();
    final invited = stored['messageInvited'];
    if (invited is Map) {
      for (final MapEntry(key: machine, value: projects) in invited.entries) {
        if (machine is! String || projects is! List) continue;
        for (final project in projects) {
          if (project is String && messagePerson(machine, project) != null) _messageInvited.add((machine, project));
        }
      }
    }
    final draft = stored['setupDraft'];
    _forwardedBranches.clear();
    final forwards = stored['forwardedBranches'];
    if (forwards is List) {
      for (final value in forwards) {
        if (value
            case {
              'machine': final String machine,
              'project': final String project,
              'repository': final String repository,
              'task': final String task,
              'branch': final String branch,
            }
            when _validForward(machine, project, repository, task, branch)) {
          _forwardedBranches[(machine, project, repository, task)] = branch;
        }
      }
    }
    _planningOffers.clear();
    if (stored['planningOffers'] case final List<dynamic> offers) {
      for (final value in offers) {
        if (value
            case {'machine': final String machine, 'container': final String container, 'offer': final String offer}
            when _validOffer(machine, container, offer)) {
          _planningOffers[(machine, container)] = offer;
        }
      }
    }
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
    _keyRecoveries.clear();
    if (stored['keyRecoveries'] case final Map<String, Object?> receipts) {
      for (final MapEntry(:key, :value) in receipts.entries) {
        // Each receipt is read field by field where it is used; here only its JSON shape is kept.
        if (value is Map<String, Object?>) _keyRecoveries[key] = Map.unmodifiable(value);
      }
    }
    _hostUps.clear();
    final hostUps = stored['hostUps'];
    if (hostUps is Map) {
      for (final entry in hostUps.entries) {
        final key = entry.key;
        final record = HostUpRecord.fromStored(entry.value);
        if (key is! String || record == null) continue;
        try {
          SecretsFile.checkHost(record.host ?? key);
        } on Exception {
          continue;
        }
        _hostUps[key] = record;
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
    final explained = stored['explanationsSeen'];
    if (explained is List) _explanationsSeen = explained.whereType<String>().toList();
    // What the version before kept: one folded there has been seen.
    final folded = stored['explanationsFolded'];
    if (folded is List) {
      _explanationsSeen = (<String>{..._explanationsSeen, ...folded.whereType<String>()}.toList()..sort());
    }
    final putAway = stored['endedPutAway'];
    if (putAway is List) _endedPutAway = putAway.whereType<String>().toList();
    final ranOut = stored['ranOut'];
    if (ranOut is List) {
      _ranOut = ranOut.whereType<Map<String, dynamic>>().map(RanOutQuestion.fromStored).nonNulls.toList();
    }
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
      _machines = machines.whereType<Map<String, Object?>>().toList();
    }
    final forges = stored['forges'];
    if (forges is List) _forges = List<Object?>.of(forges);
    _loaded = true;
    notifyListeners();
  }

  /// Whether [load] has read what an earlier run stored: before, a mark written would replace every stored one.
  bool get loaded => _loaded;
  bool _loaded = false;

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
    // An invitation belongs to the account it invited: another person, or none, is not invited.
    _messageInvited.remove((machine, project));
    if (person == null) {
      final projects = _messagePeople[machine]!;
      projects.remove(project);
      if (projects.isEmpty) _messagePeople.remove(machine);
    } else {
      (_messagePeople[machine] ??= <String, String>{})[project] = person;
    }
    await _write();
  }

  final _messageInvited = <(String, String)>{};

  /// Whether the remembered person of a machine's project room was invited with an account they had, rather than
  /// made one: such an account keeps its own password, and nothing here offers it a new one.
  bool messageInvited(String machine, String project) => _messageInvited.contains((machine, project));

  /// Keeps whether the remembered person's join invited an account they had; ignored where nobody is remembered.
  Future<void> rememberMessageInvited(String machine, String project, {required bool invited}) async {
    if (messagePerson(machine, project) == null || messageInvited(machine, project) == invited) return;
    if (invited) {
      _messageInvited.add((machine, project));
    } else {
      _messageInvited.remove((machine, project));
    }
    await _write();
  }

  Map<String, String> _tresorFolders = <String, String>{};

  final _forwardedBranches = <(String, String, String, String), String>{};

  /// The last confirmed branch for this machine, project, repository and task.
  String? lastForwardedBranch(String machine, String project, String repository, String task) =>
      _forwardedBranches[(machine, project, repository, task)];

  /// Keeps a branch only after the daemon confirms that this task's push was forwarded.
  Future<void> rememberForwardedBranch(
    String machine,
    String project,
    String repository,
    String task,
    String branch,
  ) async {
    if (!_validForward(machine, project, repository, task, branch)) {
      throw ArgumentError('A machine, project, repository, task and branch must be valid names.');
    }
    _forwardedBranches[(machine, project, repository, task)] = branch;
    await _write();
  }

  static bool _validForward(String machine, String project, String repository, String task, String branch) =>
      [machine, project, task, branch].every((value) => value.trim().isNotEmpty && !value.contains('\x00')) &&
      branch.trim() == branch &&
      !repository.contains('\x00');

  final _planningOffers = <(String, String), String>{};

  /// The offer a planner gave a task this window started, by the machine and the container it runs in.
  String? planningOffer(String machine, String container) => _planningOffers[(machine, container)];

  /// Keeps [offer] beside the machine and container of the task started for it.
  Future<void> rememberPlanningOffer({
    required String machine,
    required String container,
    required String offer,
  }) async {
    if (!_validOffer(machine, container, offer)) {
      throw ArgumentError('A machine, a container and an offer of at most 200 characters must be given.');
    }
    _planningOffers[(machine, container)] = offer;
    await _write();
  }

  /// Drops the offer kept for the task in [container] on [machine], once that task is removed.
  Future<void> forgetPlanningOffer(String machine, String container) async {
    if (_planningOffers.remove((machine, container)) != null) await _write();
  }

  // The planner sends an offer of at most 200 characters; a longer one was not written by this window.
  static bool _validOffer(String machine, String container, String offer) =>
      [
        machine,
        container,
        offer,
      ].every((value) => value.trim().isNotEmpty && !value.contains(RegExp(r'[\x00-\x1f]'))) &&
      offer.length <= 200;

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

  final _keyRecoveries = <String, Map<String, Object?>>{};

  /// The pending backup-key request kept under [key], or null; never a backup file's place.
  Map<String, Object?>? keyRecovery(String key) => _keyRecoveries[key];

  /// Every key a pending backup-key request is kept under.
  List<String> get keyRecoveryKeys => List.unmodifiable(_keyRecoveries.keys);

  /// Keeps a pending backup-key request, so asking again resumes it under the same request ID.
  Future<void> rememberKeyRecovery(String key, Map<String, Object?> receipt) async {
    _keyRecoveries[key] = Map.unmodifiable(receipt);
    notifyListeners();
    await _write();
  }

  /// Forgets a finished or never-started backup-key request.
  Future<void> forgetKeyRecovery(String key) async {
    if (_keyRecoveries.remove(key) == null) return;
    notifyListeners();
    await _write();
  }

  final _hostUps = <String, HostUpRecord>{};

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
      throw ArgumentError('A machine and a complete machine setup record are required.');
    }
    final previous = _hostUps[host];
    _hostUps[host] = record;
    try {
      await _write();
      final saved = (await _store.read())['hostUps'];
      final savedRecord = saved is Map ? saved[host] : null;
      if (savedRecord is! Map || !_sameStored(savedRecord, record.stored)) {
        throw const FileSystemException('Cannot keep the machine setup in the interface settings.');
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
    if (stored is! List) {
      // None stored is read whole too: nothing is set aside, and no mark of a notice can name what is.
      _setAside = const [];
      _olderMachines = false;
      _machinesRead = true;
      return const <Machine>[];
    }
    // One unusable entry is dropped and the rest are kept. A machine with no name, or with neither a
    // socket nor a kind of its own, cannot be watched or told apart from another, and losing every
    // other machine over it would be the worse answer. An entry with a kind is kept even without a
    // socket: a WSL distribution has none, and a kind this version does not know is not its to drop.
    // A second entry of a name already read is dropped too: every machine is told apart by its name,
    // and two of one would send one's calls through the other's way in.
    //
    // An entry whose host card does not read is set aside whole, kept in the file and said, never read as a machine:
    // it names a host this build will not reach, and losing it, or every other machine, would be worse.
    final machines = <Machine>[];
    final setAside = <Map<String, Object?>>[];
    var older = false;
    for (final each in stored) {
      if (each is! Map<String, Object?>) continue;
      final Machine machine;
      try {
        machine = Machine.fromStored(each);
      } on HostFilesRefused {
        setAside.add(each);
        continue;
      }
      if (machine.name.isEmpty || (machine.socketPath.isEmpty && machine.kind.isEmpty)) continue;
      if (machines.any((kept) => kept.name == machine.name)) continue;
      // A card saved by an older build, with its uid, its return socket or an account's own daemon socket.
      final card = each['hostCard'];
      older |=
          card is Map &&
          (card.containsKey('uid') ||
              card.containsKey('return_socket') ||
              each['remoteSocket'] != machine.remoteSocket);
      machines.add(machine);
    }
    _setAside = List.unmodifiable(setAside);
    _olderMachines = older;
    _machinesRead = true;
    return machines;
  }

  /// Whether [machines] has read the stored machines, so [machinesSetAside] is whole.
  bool get machinesRead => _machinesRead;
  bool _machinesRead = false;

  List<Map<String, Object?>> _setAside = const [];
  bool _olderMachines = false;

  /// The names of stored machines whose host card did not read at the last [machines], kept in the file unread.
  List<String> get machinesSetAside => [
    for (final each in _setAside) each['name'] is String ? each['name'] as String : '(unnamed)',
  ];

  /// Whether the last [machines] read a card an older build saved, so the list is saved again in today's form.
  bool get olderMachines => _olderMachines;

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

  /// Machines whose silence somebody has seen, until they answer again; and, as `set aside: <its words>`, the notice
  /// of machines set aside, until other machines are set aside.
  Set<String> get seenSilent => Set<String>.unmodifiable(_seenSilent);
  List<String> _seenSilent = const <String>[];

  /// The ends of work somebody has opened or put away, each by its machine, its work and when it ended; and, as
  /// `story ended <machine>/<project>/<story> at <when>`, the ends of a story's work somebody has seen.
  Set<String> get endedPutAway => Set<String>.unmodifiable(_endedPutAway);
  List<String> _endedPutAway = const <String>[];

  /// Questions that ran out with nobody answering, the seen ones kept so a machine saying one again does not
  /// bring it back.
  List<RanOutQuestion> get ranOut => List<RanOutQuestion>.unmodifiable(_ranOut);
  List<RanOutQuestion> _ranOut = const <RanOutQuestion>[];

  /// Keeps the questions that ran out.
  Future<void> setRanOut(List<RanOutQuestion> questions) async {
    _ranOut = List<RanOutQuestion>.of(questions);
    notifyListeners();
    await _write();
  }

  /// The pages whose explanation has stood open its one time.
  Set<String> get explanationsSeen => Set<String>.unmodifiable(_explanationsSeen);
  List<String> _explanationsSeen = const <String>[];

  /// The explanations open now, which no restart keeps.
  final Set<String> _explanationsOpen = <String>{};

  /// Whether the explanation of the page [id] stands open now.
  bool explanationOpen(String id) => _explanationsOpen.contains(id);

  /// Opens or closes the explanation of the page [id].
  void setExplanationOpen(String id, {required bool open}) {
    if (open ? !_explanationsOpen.add(id) : !_explanationsOpen.remove(id)) return;
    notifyListeners();
  }

  /// Forgets that the explanation of the page [id] is open, as its page goes: nothing listening is told.
  void forgetExplanationOpen(String id) => _explanationsOpen.remove(id);

  /// Opens the explanation of the page [id] if it never stood open, as the page first draws: nothing
  /// listening is told, as what draws it has not drawn yet.
  void showExplanationTheFirstTime(String id) {
    if (_explanationsSeen.contains(id)) return;
    _explanationsOpen.add(id);
    unawaited(markExplanationSeen(id));
  }

  /// Keeps that the explanation of the page [id] has stood open its one time.
  Future<void> markExplanationSeen(String id) async {
    _explanationsSeen = (<String>{..._explanationsSeen, id}.toList()..sort());
    await _write();
  }

  /// Keeps which ends of work somebody has opened or put away.
  Future<void> setEndedPutAway(Set<String> ends) async {
    _endedPutAway = ends.toList()..sort();
    notifyListeners();
    await _write();
  }

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
    _machines = <Map<String, Object?>>[
      for (final machine in machines) machine.stored,
      // What did not read stays as it was, unless a machine of its name took its place.
      for (final each in _setAside)
        if (!machines.any((machine) => machine.name == each['name'])) each,
    ];
    _olderMachines = false;
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
  /// Whether the store itself holds [machine] as it is: a file store says nothing of a write that failed.
  Future<bool> holdsMachine(Machine machine) async {
    final stored = (await _store.read())['machines'];
    // The entry as it is now, not an older one of the same name a failed write left in its place.
    final wanted = jsonEncode(machine.stored);
    return stored is List && stored.any((each) => each is Map && jsonEncode(each) == wanted);
  }

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
    'shellNavigation': _shellNavigation,
    'form': settingsForm,
    'refreshSeconds': _refreshSeconds,
    'keepResolvedMinutes': _keepResolvedMinutes,
    'workUser': _workUser,
    'messagePeople': {for (final entry in _messagePeople.entries) entry.key: Map<String, String>.of(entry.value)},
    'messageInvited': <String, List<String>>{
      for (final (machine, _) in _messageInvited)
        machine: [
          for (final (each, project) in _messageInvited)
            if (each == machine) project,
        ],
    },
    'forwardedBranches': [
      for (final MapEntry(key: (machine, project, repository, task), value: branch) in _forwardedBranches.entries)
        {'machine': machine, 'project': project, 'repository': repository, 'task': task, 'branch': branch},
    ],
    'planningOffers': [
      for (final MapEntry(key: (machine, container), value: offer) in _planningOffers.entries)
        {'machine': machine, 'container': container, 'offer': offer},
    ],
    'setupDraft': _setupDraft,
    'appearance': _appearance.name,
    'machines': _machines,
    'muted': _muted,
    'homeservers': <Map<String, Object?>>[
      for (final each in _homeservers)
        <String, Object?>{'machine': each.machine, 'project': each.project, 'port': each.port},
    ],
    'seenSilent': _seenSilent,
    'endedPutAway': _endedPutAway,
    'explanationsSeen': _explanationsSeen,
    'ranOut': [for (final each in _ranOut) each.stored],
    'place': _place,
    'templates': _templates,
    'forges': _forges,
    'tresorFolders': _tresorFolders,
    'secretsFile': _secretsFile,
    'hostUps': {for (final entry in _hostUps.entries) entry.key: entry.value.stored},
    'keyRecoveries': {for (final entry in _keyRecoveries.entries) entry.key: entry.value},
  };

  static ThemeMode _appearanceNamed(Object? name) =>
      ThemeMode.values.firstWhere((mode) => mode.name == name, orElse: () => ThemeMode.system);
}
