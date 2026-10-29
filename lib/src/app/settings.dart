import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:porelo_host/porelo_host.dart' show SecretsFile, PreparedHost, checkHostName;

import 'desk.dart';
import 'host_vpn.dart' show isForgeCaCertificate, checkVpnInterface;
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

/// The non-secret inputs of one host's last setup, kept together for teardown.
@immutable
class HostUpRecord {
  /// Keeps paths and public tunnel options, never key contents or login answers.
  const HostUpRecord({
    required this.scalewayProject,
    required this.account,
    required this.tresor,
    required this.folder,
    this.setupFolder,
    this.host,
    this.vpnNetworkNumber = 0,
    this.vpnInterface = 'porelo-0',
    this.hostName = '',
    this.forge = true,
    this.preparedHost,
    this.repository = '',
    required this.signingKey,
    required this.identity,
    required this.publicKey,
    required this.collection,
    this.collectionSha256 = '',
    required this.vpnPeerPublicKey,
    required this.vpnPeerAddress,
    this.vpnHostPublicKey = '',
    this.vpnEndpointAddress = '',
    this.vpnFile,
    this.forgeCa,
    this.vaultKeys = const [],
    this.preparing = false,
    this.startedAt,
    this.protocol = const [],
  });

  /// The host name, absent in records kept before host names were stored.
  final String? host;

  /// The third octet of this host's VPN network.
  final int vpnNetworkNumber;

  /// The local WireGuard interface, including the legacy `porelo` name.
  final String vpnInterface;

  /// The server name for preparation without a project; empty for the legacy project path.
  final String hostName;

  /// Whether this server runs its own forge.
  final bool forge;

  /// The validated completion values for project admins, absent before completion.
  final PreparedHost? preparedHost;

  /// Keeps the server's confirmed public completion values.
  HostUpRecord withPreparedHost(PreparedHost host) => HostUpRecord.fromStored({
    ...stored,
    'preparedHost': host.values,
    'vpnHostPublicKey': host.values['wireguard_public_key'],
    'vpnEndpointAddress': host.values['address'],
  })!;

  /// The provider project that owns the rented host.
  final String scalewayProject;

  /// The OS user on the host.
  final String account;

  /// The Tresorit tresor a host synced in setups before the drive left them; empty since, and never passed on.
  final String tresor;

  /// Its local synced folder, absent when the host files were supplied manually.
  final String? folder;

  /// The interface's own folder holding the host's `machine.yml` and bundle, which `up` uploads; absent in a record
  /// from before the upload, whose host read them from the drive.
  final String? setupFolder;

  /// Retained for source compatibility; stored repository addresses are ignored.
  final String repository;

  /// The public signing key's path.
  final String signingKey;

  /// The private SSH key's path, never its contents.
  final String identity;

  /// The public SSH key's path.
  final String publicKey;

  /// The host setup collection's path.
  final String collection;

  /// The test collection's expected digest, absent for carried collections or older records.
  final String collectionSha256;

  /// The tunnel peer's public half, empty when none was supplied.
  final String vpnPeerPublicKey;

  /// The tunnel peer's address, empty when none was supplied.
  final String vpnPeerAddress;

  /// The host's WireGuard public half, absent in older setup records.
  final String vpnHostPublicKey;

  /// The host address used by the tunnel, without its port, absent in older setup records.
  final String vpnEndpointAddress;

  /// The explicitly exported VPN file's local path, never its private key contents.
  final String? vpnFile;

  /// This host's lasting CA certificate, public PEM; its key stays in the secrets file.
  final String? forgeCa;

  /// The names of the vault entries `machine.yml` names, never their files' contents: the stop sends these alone.
  final List<String> vaultKeys;

  /// Whether setup still needs a confirmed machine or server give-back.
  final bool preparing;

  /// The UTC instant preparation began, absent before setup or after confirmation.
  final DateTime? startedAt;

  /// The public protocol retained until the server is given back.
  final List<HostProtocolEntry> protocol;

  /// Keeps recovery until a machine or give-back has been confirmed.
  HostUpRecord withPreparation(DateTime? instant) => HostUpRecord(
    scalewayProject: scalewayProject,
    hostName: hostName,
    forge: forge,
    preparedHost: preparedHost,
    account: account,
    tresor: tresor,
    folder: folder,
    setupFolder: setupFolder,
    host: host,
    vpnNetworkNumber: vpnNetworkNumber,
    vpnInterface: vpnInterface,
    repository: repository,
    signingKey: signingKey,
    identity: identity,
    publicKey: publicKey,
    collection: collection,
    collectionSha256: collectionSha256,
    vpnPeerPublicKey: vpnPeerPublicKey,
    vpnPeerAddress: vpnPeerAddress,
    vpnHostPublicKey: vpnHostPublicKey,
    vpnEndpointAddress: vpnEndpointAddress,
    vpnFile: vpnFile,
    forgeCa: forgeCa,
    vaultKeys: vaultKeys,
    preparing: instant != null,
    startedAt: instant?.toUtc(),
    protocol: protocol,
  );

  /// Keeps the same host identity when the exported file is saved or explicitly deleted.
  HostUpRecord withVpnFile(String? file) => HostUpRecord(
    scalewayProject: scalewayProject,
    hostName: hostName,
    forge: forge,
    preparedHost: preparedHost,
    account: account,
    tresor: tresor,
    folder: folder,
    setupFolder: setupFolder,
    host: host,
    vpnNetworkNumber: vpnNetworkNumber,
    vpnInterface: vpnInterface,
    repository: repository,
    signingKey: signingKey,
    identity: identity,
    publicKey: publicKey,
    collection: collection,
    collectionSha256: collectionSha256,
    vpnPeerPublicKey: vpnPeerPublicKey,
    vpnPeerAddress: vpnPeerAddress,
    vpnHostPublicKey: vpnHostPublicKey,
    vpnEndpointAddress: vpnEndpointAddress,
    vpnFile: file,
    forgeCa: forgeCa,
    vaultKeys: vaultKeys,
    preparing: preparing,
    startedAt: startedAt,
    protocol: protocol,
  );

  /// Keeps the confirmed public tunnel settings without changing setup or the chosen file.
  HostUpRecord withTunnel({required String hostPublicKey, required String address}) => HostUpRecord(
    scalewayProject: scalewayProject,
    hostName: hostName,
    forge: forge,
    preparedHost: preparedHost,
    account: account,
    tresor: tresor,
    folder: folder,
    setupFolder: setupFolder,
    host: host,
    vpnNetworkNumber: vpnNetworkNumber,
    vpnInterface: vpnInterface,
    repository: repository,
    signingKey: signingKey,
    identity: identity,
    publicKey: publicKey,
    collection: collection,
    collectionSha256: collectionSha256,
    vpnPeerPublicKey: vpnPeerPublicKey,
    vpnPeerAddress: vpnPeerAddress,
    vpnHostPublicKey: hostPublicKey,
    vpnEndpointAddress: address,
    vpnFile: vpnFile,
    forgeCa: forgeCa,
    vaultKeys: vaultKeys,
    preparing: preparing,
    startedAt: startedAt,
    protocol: protocol,
  );

  /// Replaces the kept protocol without changing the setup answers.
  HostUpRecord withProtocol(List<HostProtocolEntry> entries) => HostUpRecord(
    scalewayProject: scalewayProject,
    hostName: hostName,
    forge: forge,
    preparedHost: preparedHost,
    account: account,
    tresor: tresor,
    folder: folder,
    setupFolder: setupFolder,
    host: host,
    vpnNetworkNumber: vpnNetworkNumber,
    vpnInterface: vpnInterface,
    repository: repository,
    signingKey: signingKey,
    identity: identity,
    publicKey: publicKey,
    collection: collection,
    collectionSha256: collectionSha256,
    vpnPeerPublicKey: vpnPeerPublicKey,
    vpnPeerAddress: vpnPeerAddress,
    vpnHostPublicKey: vpnHostPublicKey,
    vpnEndpointAddress: vpnEndpointAddress,
    vpnFile: vpnFile,
    forgeCa: forgeCa,
    vaultKeys: vaultKeys,
    preparing: preparing,
    startedAt: startedAt,
    protocol: List.unmodifiable(entries),
  );

  /// Keeps this host's trust with its setup identity.
  HostUpRecord withForgeCa(String? pem) {
    if (pem != null && !isForgeCaCertificate(pem)) {
      throw ArgumentError('The host\'s CA must be one certificate in PEM.');
    }
    return HostUpRecord.fromStored({...stored, 'forgeCa': pem})!;
  }

  /// Assigns a migrated setup to its host without changing its tunnel identity.
  HostUpRecord forHost(String name) {
    SecretsFile.checkHost(name);
    return HostUpRecord.fromStored({...stored, 'host': name})!;
  }

  /// Reads every field or drops the entire unusable record.
  static HostUpRecord? fromStored(Object? value) {
    if (value case {
      'scalewayProject': final String scalewayProject,
      'account': final String account,
      'tresor': final String tresor,
      'folder': final Object? folder,
      'signingKey': final String signingKey,
      'identity': final String identity,
      'publicKey': final String publicKey,
      'collection': final String collection,
      'vpnPeerPublicKey': final String vpnPeerPublicKey,
      'vpnPeerAddress': final String vpnPeerAddress,
    }) {
      final host = value['host'];
      if (value.containsKey('host') && host is! String) return null;
      final match = RegExp(r'^10\.73\.(0|[1-9][0-9]{0,2})\.(0|[1-9][0-9]{0,2})/32$').firstMatch(vpnPeerAddress);
      if (vpnPeerAddress.isNotEmpty && (match == null || int.parse(match[1]!) > 255 || int.parse(match[2]!) > 255)) {
        return null;
      }
      final network = value.containsKey('vpnNetworkNumber')
          ? value['vpnNetworkNumber']
          : match == null
          ? 0
          : int.parse(match[1]!);
      final interface = value.containsKey('vpnInterface') ? value['vpnInterface'] : 'porelo';
      if (network is! int || interface is! String) return null;
      try {
        if (host is String) SecretsFile.checkHost(host);
        SecretsFile.checkNetworkNumber(network);
        checkVpnInterface(interface, network);
      } on Exception {
        return null;
      }
      if (match != null && int.parse(match[1]!) != network) return null;
      final hostName = value['hostName'] ?? '';
      final forge = value['forge'] ?? true;
      if (hostName is! String || forge is! bool) return null;
      PreparedHost? preparedHost;
      try {
        if (hostName.isNotEmpty) {
          checkHostName(hostName);
          if (hostName != host) return null;
        }
        if (value['preparedHost'] != null) {
          preparedHost = PreparedHost.read(value['preparedHost']);
          if (preparedHost.network != network ||
              preparedHost.values['homeserver'] != 'matrix.$hostName.porelo.internal') {
            return null;
          }
        }
      } on FormatException {
        return null;
      }
      // Unreadable progress must not erase the answers needed to give a billed server back.
      final protocol = HostProtocolEntry.readMany(value['protocol']) ?? const <HostProtocolEntry>[];
      final preparing = value.containsKey('preparing') ? value['preparing'] : false;
      if (preparing is! bool) return null;
      final start = value['startedAt'];
      if (start != null && start is! String) return null;
      final startedAt = start is String ? DateTime.tryParse(start) : null;
      if (start != null && (startedAt == null || !startedAt.isUtc)) return null;
      if (preparing && startedAt == null) return null;
      final vpnFile = value['vpnFile'];
      if (vpnFile != null && vpnFile is! String) return null;
      final forgeCa = value['forgeCa'];
      if (forgeCa != null && (forgeCa is! String || !isForgeCaCertificate(forgeCa))) return null;
      final vaultKeys = value['vaultKeys'] ?? const <Object?>[];
      if (vaultKeys is! List ||
          vaultKeys.any((name) => name is! String || !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$').hasMatch(name)) ||
          vaultKeys.toSet().length != vaultKeys.length) {
        return null;
      }
      final setupFolder = value['setupFolder'];
      if (setupFolder != null &&
          (setupFolder is! String || !path.isAbsolute(setupFolder) || setupFolder.contains('\x00'))) {
        return null;
      }
      final vpnHostPublicKey = value['vpnHostPublicKey'] ?? '';
      final vpnEndpointAddress = value['vpnEndpointAddress'] ?? '';
      if (vpnHostPublicKey is! String || vpnEndpointAddress is! String) return null;
      if (vpnHostPublicKey.isNotEmpty) {
        try {
          final bytes = base64Decode(vpnHostPublicKey);
          if (bytes.length != 32 || base64Encode(bytes) != vpnHostPublicKey) return null;
        } on FormatException {
          return null;
        }
      }
      if (vpnEndpointAddress.isNotEmpty && !RegExp(r'^[A-Za-z0-9][A-Za-z0-9.:-]*$').hasMatch(vpnEndpointAddress)) {
        return null;
      }
      if (folder != null && (folder is! String || folder.trim().isEmpty || folder.contains('\x00'))) return null;
      final required = [scalewayProject, account, identity, publicKey];
      if (required.any((field) => field.trim().isEmpty)) return null;
      final collectionSha256 = switch (value) {
        {'collectionSha256': final Object? digest} => digest,
        _ => '',
      };
      if (collectionSha256 is! String ||
          (collectionSha256.isNotEmpty &&
              (collection.trim().isEmpty || !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(collectionSha256)))) {
        return null;
      }
      if ([
        ...required,
        tresor,
        signingKey,
        collection,
        vpnPeerPublicKey,
        vpnPeerAddress,
      ].any((field) => field.contains('\x00'))) {
        return null;
      }
      if (vpnPeerPublicKey.isEmpty != vpnPeerAddress.isEmpty) return null;
      if (folder != null && signingKey.trim().isEmpty) return null;
      return HostUpRecord(
        scalewayProject: scalewayProject,
        hostName: hostName,
        forge: forge,
        preparedHost: preparedHost,
        account: account,
        tresor: tresor,
        folder: folder is String ? folder : null,
        host: host is String ? host : null,
        vpnNetworkNumber: network,
        vpnInterface: interface,
        repository: '',
        signingKey: signingKey,
        identity: identity,
        publicKey: publicKey,
        collection: collection,
        collectionSha256: collectionSha256,
        vpnPeerPublicKey: vpnPeerPublicKey,
        vpnPeerAddress: vpnPeerAddress,
        vpnHostPublicKey: vpnHostPublicKey,
        vpnEndpointAddress: vpnEndpointAddress,
        vpnFile: vpnFile is String ? vpnFile : null,
        forgeCa: forgeCa is String ? forgeCa : null,
        vaultKeys: List.unmodifiable(vaultKeys.whereType<String>()),
        setupFolder: setupFolder is String ? setupFolder : null,
        preparing: preparing,
        startedAt: startedAt,
        protocol: protocol,
      );
    }
    return null;
  }

  /// Only the public setup choices that belong in the interface's settings.
  Map<String, Object?> get stored => {
    if (host != null) 'host': host,
    'vpnNetworkNumber': vpnNetworkNumber,
    'vpnInterface': vpnInterface,
    'scalewayProject': scalewayProject,
    if (hostName.isNotEmpty) ...{'hostName': hostName, 'forge': forge},
    if (preparedHost != null) 'preparedHost': preparedHost!.values,
    'account': account,
    'tresor': tresor,
    'folder': folder,
    if (setupFolder != null) 'setupFolder': setupFolder,
    'signingKey': signingKey,
    'identity': identity,
    'publicKey': publicKey,
    'collection': collection,
    if (collectionSha256.isNotEmpty) 'collectionSha256': collectionSha256,
    'vpnPeerPublicKey': vpnPeerPublicKey,
    'vpnPeerAddress': vpnPeerAddress,
    if (vpnHostPublicKey.isNotEmpty) 'vpnHostPublicKey': vpnHostPublicKey,
    if (vpnEndpointAddress.isNotEmpty) 'vpnEndpointAddress': vpnEndpointAddress,
    if (vpnFile != null) 'vpnFile': vpnFile,
    if (forgeCa != null) 'forgeCa': forgeCa,
    if (vaultKeys.isNotEmpty) 'vaultKeys': vaultKeys,
    if (protocol.isNotEmpty) 'protocol': [for (final entry in protocol) entry.stored],
    if (preparing) 'preparing': true,
    if (startedAt != null) 'startedAt': startedAt!.toUtc().toIso8601String(),
  };

  /// The identical host identity options for up, resume and down.
  List<String> arguments(String project) => [
    if (hostName.isEmpty) ...[
      '--project',
      project,
      '--account',
      account,
    ] else ...[
      '--host-name',
      hostName,
      '--network',
      '$vpnNetworkNumber',
      '--login-user',
      'root',
      '--forge',
      '$forge',
    ],
    '--public-key',
    publicKey,
    '--identity',
    identity,
    if (vpnPeerPublicKey.isNotEmpty) ...[
      '--vpn-peer-public-key',
      vpnPeerPublicKey,
      '--vpn-peer-address',
      vpnPeerAddress,
    ],
    '--scaleway-project',
    scalewayProject,
    if (setupFolder case final folder?) ...[
      '--machine-file',
      path.join(path.normalize(folder), 'porelo-host', 'machine.yml'),
      '--bundle',
      path.join(path.normalize(folder), 'porelo-host', '$project.bundle'),
    ],
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
        _hostUps[unique ? host : key] = unique && record.host == null && host != key ? record.forHost(host) : record;
        migratedHosts |= unique && host != key;
        if (unique && host != key) migratedHostKeys[key] = host;
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

  /// One certificate in PEM, and nothing beside it.
  static bool isCertificate(String pem) => isForgeCaCertificate(pem);

  /// Keeps the lasting CA only with the host whose stop supplied it.
  Future<void> rememberForgeCa(String host, String? pem) async {
    final record = hostUp(host);
    if (record == null) throw ArgumentError('The CA needs a kept host setup.');
    await rememberHostUp(host, record.withForgeCa(pem));
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
