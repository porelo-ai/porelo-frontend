import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';

import 'host_file_writer.dart';
import 'host_files.dart' show HostFilesRefused;
import 'ssh_public_key.dart';
import 'ssh.dart';

/// Public transport values supplied by Core after verifying a signed host card.
///
/// This boundary does not verify signatures or infer admission. The login and the
/// selected public key accompany Core's verified card; the host links the login's
/// daemon and return sockets at fixed paths in that person's own directory.
class HostCardSsh {
  /// Validates all values before they can enter OpenSSH configuration.
  HostCardSsh({
    required this.name,
    required this.address,
    required this.sshPort,
    required this.hostKey,
    required this.login,
    required this.publicKey,
    required this.webPort,
    required this.gitPort,
    required this.matrixPort,
  }) {
    if (!RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$').hasMatch(name)) {
      throw const HostFilesRefused('A host name must be a lower-case DNS label.');
    }
    if (!_address(address)) throw const HostFilesRefused('The host address must be an IP address or DNS name.');
    // Core's rule for a login, checked here too because the login becomes a path on the host.
    if (!RegExp(r'^[a-z][a-z0-9-]{0,31}$').hasMatch(login)) {
      throw const HostFilesRefused('The host needs an admitted login.');
    }
    _key(hostKey);
    _key(publicKey);
    for (final port in [sshPort, ...ports]) {
      if (port < 1 || port > 65535) throw const HostFilesRefused('A host port must be between 1 and 65535.');
    }
    if (ports.toSet().length != ports.length) {
      throw HostFilesRefused('Host $name repeats a local service port.');
    }
  }

  /// Reads the public adapter shape, checking every field without casts.
  ///
  /// An older record's `uid` and `return_socket` are read past: both sockets now follow from the login.
  factory HostCardSsh.fromStored(Object? value) {
    if (value is! Map) throw const HostFilesRefused('The verified host card must be an object.');
    String text(String key) {
      final found = value[key];
      if (found is! String) throw HostFilesRefused('The host card needs a string $key.');
      return found;
    }

    int number(Map<Object?, Object?> source, String key) {
      final found = source[key];
      if (found is! int) throw HostFilesRefused('The host card needs an integer $key.');
      return found;
    }

    final services = value['services'];
    final forge = services is Map ? services['forge'] : null;
    final matrix = services is Map ? services['matrix'] : null;
    if (forge is! Map || matrix is! Map) throw const HostFilesRefused('The host card needs forge and matrix services.');
    return HostCardSsh(
      name: text('name'),
      address: text('address'),
      sshPort: number(value, 'ssh_port'),
      hostKey: text('host_key'),
      login: text('login'),
      publicKey: text('public_key'),
      webPort: number(forge, 'web_port'),
      gitPort: number(forge, 'git_port'),
      matrixPort: number(matrix, 'port'),
    );
  }

  /// The host's lower-case DNS label.
  final String name;

  /// The SSH address from the verified card.
  final String address;

  /// The SSH port from the verified card.
  final int sshPort;

  /// The pinned public host key.
  final String hostKey;

  /// The admitted person's account name.
  final String login;

  /// The selected public identity, whose private half stays in the local agent.
  final String publicKey;

  /// The fixed local forge web port.
  final int webPort;

  /// The fixed local Git-over-HTTP port.
  final int gitPort;

  /// The fixed local Matrix port.
  final int matrixPort;

  /// The local ports reserved by this card.
  List<int> get ports => [webPort, gitPort, matrixPort];

  /// The agreed Unix service endpoints on the host.
  static const serviceSockets = [
    '/run/porelo-forge/web.sock',
    '/run/porelo-forge/git.sock',
    '/run/porelo-matrix/client.sock',
  ];

  /// The host's link to the admitted account's daemon, in that person's own directory.
  String get daemonSocket => '/run/porelo-host/people/$login/porelod.sock';

  /// The only permitted remote messenger endpoint, in that person's own directory.
  String get returnSocket => '/run/porelo-host/people/$login/return.sock';

  /// The forge web address advertised to browsers.
  String get forgeUrl => 'http://$name.localhost:$webPort/';

  /// The homeserver address advertised to Element.
  String get matrixUrl => 'http://$name.localhost:$matrixPort/';

  /// The short control endpoint inside the private config directory.
  String controlSocket(String config) => path.join(
    File(config).absolute.parent.path,
    'c-${sha256.convert(utf8.encode(name)).toString().substring(0, 16)}',
  );

  /// The public adapter values persisted with the machine entry.
  Map<String, Object?> get stored => {
    'name': name,
    'address': address,
    'ssh_port': sshPort,
    'host_key': hostKey,
    'login': login,
    'public_key': publicKey,
    'services': {
      'forge': {'web_port': webPort, 'git_port': gitPort},
      'matrix': {'port': matrixPort},
    },
  };

  static bool _address(String value) =>
      InternetAddress.tryParse(value) != null ||
      (value.length <= 253 &&
          value
              .split('.')
              .every((label) => RegExp(r'^[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$').hasMatch(label)));

  static void _key(String value) {
    if (!RegExp(r'^ssh-ed25519 [A-Za-z0-9+/]+={0,2}$').hasMatch(value)) {
      throw const HostFilesRefused('The card needs a plain ssh-ed25519 public key.');
    }
    sshSigningFingerprint(value);
  }

  /// Refuses a local port collision before publication or process launch.
  void checkAgainst(Iterable<HostCardSsh> cards) {
    for (final other in cards) {
      if (other.name == name) {
        if (jsonEncode(other.stored) != jsonEncode(stored)) {
          throw HostFilesRefused('Host $name already has a different imported card.');
        }
        continue;
      }
      for (final port in ports) {
        if (other.ports.contains(port)) throw HostFilesRefused('Port $port is used by both ${other.name} and $name.');
      }
    }
  }

  /// Checks all fixed binds, retaining them together until the check finishes.
  Future<void> checkPortsAvailable({Future<({String program, int pid})?> Function(int port)? holder}) async {
    final held = <ServerSocket>[];
    try {
      for (final port in ports) {
        try {
          held.add(await ServerSocket.bind(InternetAddress.loopbackIPv4, port, shared: false));
        } on SocketException {
          // Who holds it, so a tunnel started by hand is found and ended; only its program's name and pid, never its
          // command line, which may carry anything.
          final who = await (holder ?? portHolder)(port);
          throw HostFilesRefused(
            who == null
                ? 'Host $name cannot start: port $port is busy on 127.0.0.1.'
                : 'Host $name cannot start: port $port is busy on 127.0.0.1, held by ${who.program} (pid ${who.pid}), not by '
                      'this interface. If you started it by hand, end it with kill ${who.pid}, then try again.',
          );
        }
      }
    } finally {
      for (final socket in held) {
        await socket.close();
      }
    }
  }

  /// The program listening on [port] on 127.0.0.1 and its pid, as `ss` names them, or null where it cannot say.
  static Future<({String program, int pid})?> portHolder(int port) async {
    try {
      final listed = await Process.run('ss', ['-ltnpH', 'sport = :$port']);
      if (listed.exitCode != 0) return null;
      return holderIn('${listed.stdout}');
    } on ProcessException {
      return null;
    }
  }

  /// The first `users:(("program",pid=N,…))` in `ss -p` output, or null.
  static ({String program, int pid})? holderIn(String listed) {
    final found = RegExp(r'users:\(\("([^"]{1,64})",pid=(\d+),').firstMatch(listed);
    if (found == null) return null;
    final program = found.group(1)!;
    if (RegExp(r'[^A-Za-z0-9._ :/+-]').hasMatch(program)) return null;
    return (program: program, pid: int.parse(found.group(2)!));
  }

  /// The platform's public host config path used by the interface and plugins.
  String configPath({Map<String, String>? environment, bool windows = false}) {
    return _configPath(name, environment: environment, windows: windows);
  }

  static String _configPath(String host, {Map<String, String>? environment, bool windows = false}) {
    final env = environment ?? Platform.environment;
    final paths = windows ? path.windows : path.posix;
    final root = windows
        ? env['APPDATA']
        : env['XDG_CONFIG_HOME'] ?? (env['HOME'] == null ? null : paths.join(env['HOME']!, '.config'));
    if (root == null || !paths.isAbsolute(root)) {
      throw const HostFilesRefused('An absolute platform config directory is required.');
    }
    return paths.join(root, 'porelo', 'ssh', '$host.conf');
  }

  /// Refuses stored paths outside the platform location shared with Core.
  static void checkConfigPath(String host, String config, {Map<String, String>? environment, bool windows = false}) {
    _path(config);
    if (config != _configPath(host, environment: environment, windows: windows)) {
      throw const HostFilesRefused('The SSH config must use the platform host config directory.');
    }
  }

  /// Publishes private public-only files, refusing changed pins or identity files.
  Future<void> publish(String config, {HostFileWriter? writer, Map<String, String>? environment}) async {
    checkConfigPath(name, config, environment: environment, windows: Platform.isWindows);
    final files = writer ?? HostFileWriter();
    final folder = File(config).absolute.parent;
    _path(config);
    if (path.basename(config) != '$name.conf') {
      throw const HostFilesRefused('The SSH config must be named for its host.');
    }
    for (var ancestor = folder; ; ancestor = ancestor.parent) {
      final type = await FileSystemEntity.type(ancestor.path, followLinks: false);
      if (type != FileSystemEntityType.notFound && type != FileSystemEntityType.directory) {
        throw const HostFilesRefused('An SSH config directory must not pass through a link or file.');
      }
      if (ancestor.parent.path == ancestor.path) break;
    }
    await folder.create(recursive: true);
    if (await FileSystemEntity.type(folder.path, followLinks: false) != FileSystemEntityType.directory) {
      throw const HostFilesRefused('The SSH config directory must not be a link.');
    }
    await files.protectDirectory(folder);
    final contents = _contents(config);
    for (final entry in contents.entries) {
      await files.check(File(entry.key), utf8.encode(entry.value));
    }
    for (final entry in contents.entries) {
      await files.write(File(entry.key), utf8.encode(entry.value));
    }
  }

  /// Refuses unless every file [publish] writes for this card at [config] is there and holds exactly its bytes.
  Future<void> checkPublished(String config, {HostFileWriter? writer, Map<String, String>? environment}) async {
    checkConfigPath(name, config, environment: environment, windows: Platform.isWindows);
    final files = writer ?? HostFileWriter();
    for (final entry in _contents(config).entries) {
      if (!await files.check(File(entry.key), utf8.encode(entry.value))) {
        throw HostFilesRefused('${entry.key} is missing. Join $name again to publish its card.');
      }
    }
  }

  /// Removes what [publish] wrote for this card at [config], only while every file there holds exactly this card's
  /// bytes.
  ///
  /// A card tunnel raised for a join that was never confirmed leaves no pin behind, so a later card of the host, with
  /// another key or address, is not refused for it; the files of another card, or any changed by hand, stay whole.
  Future<void> unpublish(String config, {Map<String, String>? environment}) async {
    checkConfigPath(name, config, environment: environment, windows: Platform.isWindows);
    final ours = <File>[];
    for (final entry in _contents(config).entries) {
      final file = File(entry.key);
      final type = await FileSystemEntity.type(file.path, followLinks: false);
      if (type == FileSystemEntityType.notFound) continue;
      if (type != FileSystemEntityType.file || await file.readAsString() != entry.value) return;
      ours.add(file);
    }
    for (final file in ours) {
      await file.delete();
    }
  }

  /// The files [publish] writes at [config], by path.
  Map<String, String> _contents(String config) {
    final known = '$config.known_hosts';
    final identity = '$config.pub';
    final control = controlSocket(config);
    checkLocalSocket(control);
    final host = sshPort == 22 ? address : '[$address]:$sshPort';
    return {
      known: '$host $hostKey\n',
      identity: '$publicKey\n',
      config:
          'Host $name\n'
          '  HostName ${address.replaceAll('%', '%%')}\n  Port $sshPort\n  User $login\n'
          '${pinnedHostSshPolicy(known.replaceAll('%', '%%')).entries.map((entry) => '  ${entry.key} ${entry.value}\n').join()}'
          '  IdentityFile ${_quote(identity)}\n'
          '  StreamLocalBindMask 0177\n'
          '  ControlMaster auto\n  ControlPath ${_quote(control)}\n  ControlPersist no\n',
    };
  }

  static String _quote(String value) => '"${value.replaceAll('%', '%%')}"';

  /// Refuses paths whose SSH expansion could select another file or endpoint.
  static void checkLocalSocket(String value) {
    _path(value);
    if (value.contains(':') || utf8.encode(value).length > 107) {
      throw const HostFilesRefused('A local socket must be a short absolute path without a colon.');
    }
  }

  /// Refuses a local messenger endpoint that could forward the selected SSH agent.
  static void checkMessengerSocket(String value, {String? agentSocket}) {
    checkLocalSocket(value);
    final agent = agentSocket ?? Platform.environment['SSH_AUTH_SOCK'];
    if (agent == null || agent.isEmpty) return;
    String resolved(String endpoint) {
      try {
        if (FileSystemEntity.typeSync(endpoint, followLinks: false) != FileSystemEntityType.notFound) {
          return File(endpoint).resolveSymbolicLinksSync();
        }
        final parent = path.dirname(endpoint);
        if (parent == endpoint) throw const HostFilesRefused('Cannot verify the messenger endpoint.');
        return path.join(resolved(parent), path.basename(endpoint));
      } on FileSystemException {
        throw const HostFilesRefused('Cannot verify the messenger endpoint against the local SSH agent.');
      }
    }

    final messenger = resolved(File(value).absolute.path);
    final signing = resolved(File(agent).absolute.path);
    var same = messenger == signing;
    try {
      if (!same &&
          FileSystemEntity.typeSync(messenger) != FileSystemEntityType.notFound &&
          FileSystemEntity.typeSync(signing) != FileSystemEntityType.notFound) {
        same = FileSystemEntity.identicalSync(messenger, signing);
      }
    } on FileSystemException {
      throw const HostFilesRefused('Cannot verify the messenger endpoint against the local SSH agent.');
    }
    if (same) {
      throw const HostFilesRefused('The SSH agent socket cannot be used as the messenger return endpoint.');
    }
  }

  static void _path(String value) {
    if (!path.isAbsolute(value) || value.contains(RegExp(r'[\x00-\x1f\x7f"\\$]')) || value.contains('~')) {
      throw const HostFilesRefused('An SSH path must be absolute and contain no control characters or expansions.');
    }
  }

  @override
  bool operator ==(Object other) => other is HostCardSsh && jsonEncode(other.stored) == jsonEncode(stored);

  @override
  int get hashCode => Object.hash(name, address, sshPort, hostKey, login, publicKey, webPort, gitPort, matrixPort);
}
