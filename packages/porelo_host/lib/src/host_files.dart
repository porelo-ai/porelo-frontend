import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as path;

import 'secret_store.dart';
import 'secrets_file.dart' show SecretsFile;
import 'host_file_writer.dart';
import 'host_act.dart';
import 'host_file_name.dart';
import 'ssh_public_key.dart';

export 'host_file_name.dart' show HostFilesRefused;

/// A vault entry and the file selected for import by the host.
class HostKeyFile {
  /// Names an entry without displaying its value.
  const HostKeyFile(this.name, this.file, {this.pathContext});

  /// Path syntax for selected files; defaults to the running platform.
  final path.Context? pathContext;

  /// The vault entry name.
  final String name;

  /// The file chosen for import.
  final File file;

  /// The name under the host files directory.
  String get basename => (pathContext ?? path.context).basename(file.path);
}

/// Public halves only; private keys never enter dialog state or arguments.
class HostTunnel {
  /// Names the public halves of the two ends.
  const HostTunnel({required this.hostPublicKey, required this.peerPublicKey});

  /// The host public half used by the local tunnel.
  final String hostPublicKey;

  /// The person public half used by the host.
  final String peerPublicKey;

  /// Public options kept identical for up, resume and down.
  List<String> get arguments => ['--vpn-peer-public-key', peerPublicKey, '--vpn-peer-address', '10.73.0.2/32'];
}

/// Prepares the host's Tresorit files and the person's key in the system store.
class HostFiles {
  /// Uses the system store, or a stand-in in a test.
  HostFiles(
    this.store, {
    HostFileWriter? writer,
    path.Context? pathContext,
    this.gitEnvironment = const {'GIT_TERMINAL_PROMPT': '0'},
  }) : _writer = writer ?? HostFileWriter(),
       _paths = pathContext ?? path.context;

  /// Extra git environment variables, inherited alongside the person's configuration.
  final Map<String, String> gitEnvironment;

  final path.Context _paths;

  /// The local destination of a validated host file in the selected folder.
  String destinationPath(String folder, String name, {bool key = false}) {
    checkBasename(name, windows: _paths.style == path.Style.windows);
    final root = _paths.join(_paths.normalize(folder), 'porelo-host');
    return key ? _paths.join(root, 'keys', name) : _paths.join(root, name);
  }

  final HostFileWriter _writer;

  /// The person private key lives here until an explicit export.
  final SecretStore store;

  /// The project-specific store entry.
  static String keyName(String project) => 'wireguard-$project';

  /// Rejects traversal and option-like names on both supported desktops.
  static void checkName(String name) => checkHostFileName(name);

  /// Refuses [name] as an own-account project name, as [checkOwnAccountProjectName] says.
  static void checkProjectName(String name) => checkOwnAccountProjectName(name);

  /// Derives the public half from 32 standard-base64 bytes, as WireGuard does.
  static Future<String> publicKey(String privateKey) async {
    List<int> bytes;
    try {
      bytes = base64Decode(privateKey);
    } on FormatException {
      throw const HostFilesRefused('The stored WireGuard key is not valid.');
    }
    if (bytes.length != 32 || base64Encode(bytes) != privateKey) {
      throw const HostFilesRefused('The stored WireGuard key is not valid.');
    }
    final pair = await X25519().newKeyPairFromSeed(bytes);
    try {
      return base64Encode((await pair.extractPublicKey()).bytes);
    } finally {
      pair.destroy();
    }
  }

  /// Refuses anything but a WireGuard public key: 32 bytes in standard base64.
  static void checkPublicKey(String key) {
    List<int> bytes;
    try {
      bytes = base64Decode(key);
    } on FormatException {
      throw const HostFilesRefused('The host key the secrets file gave is not a WireGuard public key.');
    }
    if (bytes.length != 32 || base64Encode(bytes) != key) {
      throw const HostFilesRefused('The host key the secrets file gave is not a WireGuard public key.');
    }
  }

  static Future<String> _privateKey() async {
    final pair = await X25519().newKeyPair();
    try {
      return base64Encode(await pair.extractPrivateKeyBytes());
    } finally {
      pair.destroy();
    }
  }

  /// Matches ssh-keygen's SHA-256 fingerprint after parsing the complete supported key.
  static String signingFingerprint(String publicKey) {
    try {
      return sshSigningFingerprint(publicKey);
    } on FormatException catch (error) {
      throw HostFilesRefused(error.message);
    }
  }

  static String _scalar(String value) {
    final quoted = StringBuffer('"');
    for (final code in value.runes) {
      if (code < 32 || (code >= 127 && code <= 159) || code == 0x2028 || code == 0x2029) {
        quoted.write('\\u${code.toRadixString(16).padLeft(4, '0')}');
      } else if (code == 34) {
        quoted.write(r'\"');
      } else if (code == 92) {
        quoted.write(r'\\');
      } else {
        quoted.writeCharCode(code);
      }
    }
    return '$quoted"';
  }

  /// Refuses Windows devices, alternate streams and ambiguous trailing characters.
  static void checkBasename(String name, {bool? windows}) {
    checkName(name);
    if (!(windows ?? Platform.isWindows)) return;
    final stem = name.split('.').first.trimRight().toUpperCase();
    if (name.contains(':') ||
        name.endsWith('.') ||
        name.endsWith(' ') ||
        RegExp(r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$').hasMatch(stem)) {
      throw const HostFilesRefused(
        'A key file name must not name a Windows device or stream, or end with a dot or space.',
      );
    }
  }

  Future<T> _storeCall<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on Exception {
      throw const SecretStoreFailed('The system secret store could not keep or read the WireGuard key.');
    }
  }

  /// The project bundle's fixed name in an own-account setup directory.
  static const projectBundleFileName = 'project.bundle';

  /// The access repository bundle's fixed name beside an own-account machine file.
  static const accessBundleFileName = 'access.bundle';

  /// Writes the machine contract with escaped, double-quoted YAML scalars only.
  ///
  /// For [HostAct.ownAccount], [url] names the absolute project bundle and `access.bundle` is relative to this file.
  static String machineYaml({
    required String project,
    required String url,
    required String fingerprint,
    HostAct act = HostAct.legacyUp,
    List<HostKeyFile> keys = const [],
    bool? windows,
  }) {
    checkName(project);
    _checkKeys(keys, windows: windows);
    if (act == HostAct.ownAccount) {
      final suffix = '/${act.setupPlace(project: project)}/$projectBundleFileName';
      if (!url.endsWith(suffix) ||
          path.posix.normalize(url) != url ||
          !_isPlainHostHome(url.substring(0, url.length - suffix.length))) {
        throw const HostFilesRefused(
          'An own-account machine file needs its absolute project.bundle in its project setup directory, under a normalized home.',
        );
      }
    }
    return 'project:\n'
        '  name: ${_scalar(project)}\n'
        '  url: ${_scalar(url)}\n'
        '  signed_by: ${_scalar(fingerprint)}\n'
        '${act == HostAct.ownAccount ? 'access: { bundle: ${_scalar(accessBundleFileName)} }\n' : ''}'
        '${keys.isEmpty ? 'keys: []\n' : 'keys:\n'}'
        '${keys.map((key) => '  - { name: ${_scalar(key.name)}, path: ${_scalar(path.posix.join('keys', key.basename))} }\n').join()}';
  }

  static void _checkKeys(List<HostKeyFile> keys, {bool? windows}) {
    final names = <String>{};
    final files = <String>{};
    for (final key in keys) {
      checkName(key.name);
      checkBasename(key.basename, windows: windows);
      if (!names.add(key.name) ||
          !files.add((windows ?? Platform.isWindows) ? key.basename.toLowerCase() : key.basename)) {
        throw const HostFilesRefused('Each vault entry and file base name must be unique.');
      }
    }
  }

  /// Returns [project]'s absolute bundle URL for [act], using the checked host [home] for an own-account act.
  static String bundleUrl(String project, {HostAct act = HostAct.legacyUp, String? home}) {
    checkName(project);
    if (act != HostAct.ownAccount) return path.posix.join(act.setupPlace(), '$project.bundle');
    if (home == null || !_isPlainHostHome(home)) {
      throw const HostFilesRefused('The own-account bundle URL needs the checked absolute host home.');
    }
    return path.posix.join(home, act.setupPlace(project: project), projectBundleFileName);
  }

  static bool _isPlainHostHome(String home) =>
      path.posix.isAbsolute(home) &&
      home != '/' &&
      path.posix.normalize(home) == home &&
      !RegExp(r'[\r\n\x00]').hasMatch(home);

  /// Returns [project]'s access bundle beside its project bundle, relative to the person's host home.
  static String accessBundleUrl(String project) {
    checkName(project);
    return path.posix.join(HostAct.ownAccount.setupPlace(project: project), accessBundleFileName);
  }

  /// Builds only the daemon's verified revision, without reading daemon-owned files.
  Future<List<int>> createBundle({
    required String project,
    required String url,
    required String commit,
    required File signingKey,
  }) async {
    checkBasename('$project.bundle', windows: _writer.isWindows);
    if (!RegExp(r'^(?:[0-9a-fA-F]{40}|[0-9a-fA-F]{64})$').hasMatch(commit)) {
      throw const HostFilesRefused('The drive: this project has no valid verified commit to put on a server.');
    }
    if (url.trim().isEmpty || url.startsWith('-') || url.contains('\x00')) {
      throw const HostFilesRefused('The drive: the followed repository address cannot be read by this computer.');
    }
    final chosen = signingFingerprint(await signingKey.readAsString());
    final scratch = await _writer.createPrivateTemporary(Directory.systemTemp);
    try {
      final repository = path.join(scratch.path, 'repository');
      await _bundleGit(scratch, [
        'clone',
        '--no-checkout',
        '--no-local',
        '--',
        url,
        repository,
      ], timeout: const Duration(minutes: 10));
      final cloned = Directory(repository);
      await _bundleGit(cloned, ['cat-file', '-e', '$commit^{commit}']);
      await _checkSigner(scratch, cloned, commit, signingKey: await signingKey.readAsString(), chosen: chosen);
      await _bundleGit(cloned, ['update-ref', '--no-deref', 'HEAD', commit]);
      await _bundleGit(cloned, ['branch', '-f', 'main', commit]);
      await _bundleGit(cloned, ['symbolic-ref', 'HEAD', 'refs/heads/main']);
      final bundle = File(path.join(scratch.path, '$project.bundle'));
      await _bundleGit(cloned, ['bundle', 'create', bundle.path, 'HEAD', 'main']);
      return await bundle.readAsBytes();
    } finally {
      await scratch.delete(recursive: true);
    }
  }

  /// Holds the commit to the key the host checks it against, so a wrong key is refused before renting.
  Future<void> _checkSigner(
    Directory scratch,
    Directory cloned,
    String commit, {
    required String signingKey,
    required String chosen,
  }) async {
    final fields = signingKey.trim().split(RegExp(r'\s+'));
    final allowed = File(path.join(scratch.path, 'allowed_signers'));
    await allowed.writeAsString('porelo namespaces="git" ${fields[0]} ${fields[1]}\n');
    final answer = (await _bundleGit(cloned, [
      '-c',
      'gpg.ssh.allowedSignersFile=${allowed.path}',
      'log',
      '-1',
      '--format=%G?%n%GF',
      commit,
    ])).split('\n');
    final status = answer.first.trim();
    final signer = answer.length > 1 ? answer[1].trim() : '';
    if (status == 'G' && signer == chosen) return;
    if (status == 'N') {
      throw const HostFilesRefused('The drive: the verified commit is not signed, so the host would refuse it.');
    }
    if (signer.isEmpty) {
      throw const HostFilesRefused(
        'The drive: the verified commit’s signature could not be checked; ssh-keygen must be installed.',
      );
    }
    throw HostFilesRefused(
      'The drive: the verified commit is signed by $signer, not by $chosen, the chosen public key for signing '
      'commits. Choose the key that signed it. No server was rented.',
    );
  }

  Future<String> _bundleGit(
    Directory directory,
    List<String> arguments, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    const refused = HostFilesRefused(
      'The drive: Git could not read the followed repository and its verified commit or create the project bundle.',
    );
    Process process;
    try {
      process = await Process.start('git', arguments, workingDirectory: directory.path, environment: gitEnvironment);
    } on ProcessException {
      throw refused;
    }
    final stdout = process.stdout.transform(utf8.decoder).join();
    final output = Future.wait([stdout, process.stderr.drain<void>()]);
    try {
      if (await process.exitCode.timeout(timeout) != 0) throw refused;
    } on TimeoutException {
      process.kill();
      await process.exitCode;
      final limit = timeout.inMinutes >= 1 ? '${timeout.inMinutes} minutes' : '${timeout.inSeconds} seconds';
      // The command, past a leading `-c name=value`.
      final command = arguments.first == '-c' ? arguments[2] : arguments.first;
      throw HostFilesRefused('The drive: git $command did not answer within $limit. No server was rented.');
    } finally {
      await output;
    }
    return stdout;
  }

  /// Stages a complete bundle beside its target before replacing a regular file.
  ///
  /// [ownFolder] is this desktop's own folder for the host's files: made where missing, kept private, and reached
  /// through no link; a drive's folder must exist already. [act] selects the bundle's fixed own-account name.
  Future<void> publishBundle({
    required String project,
    required String folder,
    required List<int> bytes,
    bool ownFolder = false,
    HostAct act = HostAct.legacyUp,
  }) async {
    if (act == HostAct.ownAccount) checkProjectName(project);
    final name = act == HostAct.ownAccount ? projectBundleFileName : '$project.bundle';
    final target = File(destinationPath(folder, name));
    if (ownFolder) {
      await _own(folder);
    } else {
      await _directory(Directory(folder), create: false);
      await _directory(target.parent);
    }
    Future<void> checkTarget() async {
      final type = await FileSystemEntity.type(target.path, followLinks: false);
      if (type != FileSystemEntityType.notFound && type != FileSystemEntityType.file) _conflict(target.path);
    }

    await checkTarget();
    final staging = await _writer.createPrivateTemporary(target.parent);
    try {
      final prepared = File(path.join(staging.path, 'contents'));
      await prepared.writeAsBytes(bytes, flush: true);
      await _writer.protect(prepared);
      await checkTarget();
      await prepared.rename(target.path);
    } finally {
      await staging.delete(recursive: true);
    }
  }

  /// Reuses existing keys. Without a folder the host files are supplied manually.
  ///
  /// With [hostPublicKey], the public half of the host's key the person's secrets file keeps, no host key is made
  /// or written to the drive: the private half never leaves that file. With [ownFolder], [folder] is this desktop's
  /// own, as for [publishBundle], and a machine file of an earlier attempt there is replaced. [act] selects its contract.
  Future<HostTunnel> prepare({
    required String project,
    String? folder,
    required String url,
    required File signingKey,
    List<HostKeyFile> keys = const [],
    String? hostPublicKey,
    bool ownFolder = false,
    HostAct act = HostAct.legacyUp,
  }) async {
    act == HostAct.ownAccount ? checkProjectName(project) : checkName(project);
    _checkKeys(keys, windows: _writer.isWindows || _paths.style == path.Style.windows);
    if (hostPublicKey != null) checkPublicKey(hostPublicKey);
    String? hostPrivate;
    if (folder != null) {
      if (url.trim().isEmpty || _paths.extension(signingKey.path) != '.pub') {
        throw const HostFilesRefused('Give the repository URL and signing public key (.pub).');
      }
      final yaml = machineYaml(
        project: project,
        url: url,
        fingerprint: signingFingerprint(await signingKey.readAsString()),
        act: act,
        keys: keys,
        windows: _writer.isWindows,
      );
      final root = Directory(_paths.join(_paths.normalize(folder), 'porelo-host'));
      if (ownFolder) {
        await _own(folder);
      } else {
        await _directory(Directory(folder), create: false);
        await _directory(root);
      }
      final hostFile = File(destinationPath(folder, 'wireguard.key'));
      final onTheDrive = await FileSystemEntity.type(hostFile.path, followLinks: false);
      // The secrets file keeps the key now; a copy left on the drive is a key in the clear, said and never ignored.
      if (hostPublicKey != null && onTheDrive != FileSystemEntityType.notFound) {
        throw HostFilesRefused(
          '${hostFile.path} still holds a host key while your secrets file keeps it. Open the secrets file again from '
          'its step, which moves it, or remove it.',
        );
      }
      final existing = hostPublicKey != null ? FileSystemEntityType.notFound : onTheDrive;
      if (existing != FileSystemEntityType.notFound) {
        if (existing != FileSystemEntityType.file) _conflict(hostFile.path);
        hostPrivate = (await hostFile.readAsString()).trim();
        try {
          await publicKey(hostPrivate);
        } on HostFilesRefused {
          _conflict(hostFile.path);
        }
      }
      if (hostPublicKey == null) hostPrivate ??= await _privateKey();
      // With the secrets file the entries' files stay there: machine.yml names them, the stop's lines carry them.
      final copied = hostPublicKey == null ? keys : const <HostKeyFile>[];
      if (copied.isNotEmpty) await _directory(Directory(_paths.join(root.path, 'keys')));
      final contents = <String, List<int>>{
        destinationPath(folder, 'machine.yml'): utf8.encode(yaml),
        if (hostPrivate != null) hostFile.path: utf8.encode('$hostPrivate\n'),
        for (final key in copied) destinationPath(folder, key.basename, key: true): await key.file.readAsBytes(),
      };
      // In this desktop's own folder a machine file of an earlier attempt is this desktop's own, and replaced once
      // every other file has passed its check.
      final machineFile = File(destinationPath(folder, 'machine.yml'));
      var earlier = false;
      if (ownFolder && await FileSystemEntity.type(machineFile.path, followLinks: false) == FileSystemEntityType.file) {
        final kept = await machineFile.readAsBytes();
        final wanted = utf8.encode(yaml);
        earlier = kept.length != wanted.length || Iterable<int>.generate(kept.length).any((i) => kept[i] != wanted[i]);
      }
      for (final entry in contents.entries) {
        if (earlier && entry.key == machineFile.path) continue;
        await _writer.check(File(entry.key), entry.value);
      }
      if (earlier) await machineFile.delete();
      for (final entry in contents.entries) {
        await _writer.write(File(entry.key), entry.value);
      }
    }
    final name = keyName(project);
    var peerPrivate = await _storeCall(() => store.read(name));
    if (peerPrivate == null) {
      peerPrivate = await _privateKey();
      await _storeCall(() => store.write(name, peerPrivate!));
      if (await _storeCall(() => store.read(name)) != peerPrivate) {
        throw const HostFilesRefused('The secret store did not keep the WireGuard key.');
      }
    }
    return HostTunnel(
      hostPublicKey: hostPublicKey ?? (hostPrivate == null ? '' : await publicKey(hostPrivate)),
      peerPublicKey: await publicKey(peerPrivate),
    );
  }

  /// Exports the person's private half on the selected host network only when requested.
  Future<void> exportTunnel({
    required String project,
    required HostTunnel tunnel,
    required String address,
    required File destination,
    int networkNumber = 0,
  }) async {
    SecretsFile.checkNetworkNumber(networkNumber);
    if (tunnel.hostPublicKey.isEmpty || !RegExp(r'^[A-Za-z0-9][A-Za-z0-9.:-]*$').hasMatch(address)) {
      throw const HostFilesRefused('The host has not supplied valid tunnel settings.');
    }
    final privateKey = await _storeCall(() => store.read(keyName(project)));
    if (privateKey == null || await publicKey(privateKey) != tunnel.peerPublicKey) {
      throw const HostFilesRefused('The secret store does not hold this tunnel key.');
    }
    final endpoint = address.contains(':') ? '[$address]' : address;
    await _writer.write(
      destination,
      utf8.encode(
        '[Interface]\nPrivateKey = $privateKey\nAddress = 10.73.$networkNumber.2/24\n\n'
        '[Peer]\nPublicKey = ${tunnel.hostPublicKey}\nEndpoint = $endpoint:51820\nAllowedIPs = 10.73.$networkNumber.1/32\nPersistentKeepalive = 25\n',
      ),
    );
  }

  static Never _conflict(String path) => throw HostFilesRefused(
    '$path already exists and differs or is not a regular file. Remove it or choose another folder.',
  );

  /// Makes [folder] and its `porelo-host` where missing, each kept private, and refuses one reached through a link.
  Future<void> _own(String folder) async {
    final normalized = _paths.normalize(_paths.absolute(folder));
    final root = Directory(_paths.join(normalized, 'porelo-host'));
    final missing = <Directory>[];
    // Up to the first folder that is one: a link on the way is refused before anything is made. A folder above it,
    // such as a configuration folder the person links elsewhere, is theirs.
    // This desktop's folders: the one holding every project's (`hosts`), the project's, and its porelo-host. Each is
    // looked at from the top down, so a link at one is seen before any path through it is.
    final own = [_paths.dirname(normalized), normalized, root.path];
    for (final each in own) {
      final type = await FileSystemEntity.type(each, followLinks: false);
      if (type == FileSystemEntityType.notFound) break;
      if (type != FileSystemEntityType.directory) _conflict(each);
    }
    for (var each = root; ; each = each.parent) {
      final type = await FileSystemEntity.type(each.path, followLinks: false);
      if (type == FileSystemEntityType.directory) break;
      // This desktop's own folders are never a link; above them a link to a folder is the person's own choice.
      if (type == FileSystemEntityType.link && !own.contains(each.path) && await Directory(each.path).exists()) break;
      if (type != FileSystemEntityType.notFound) _conflict(each.path);
      missing.add(each);
      if (each.parent.path == each.path) break;
    }
    await root.create(recursive: true);
    for (final made in missing.reversed) {
      await _writer.protectDirectory(made);
    }
    await _writer.protectDirectory(Directory(normalized));
    await _writer.protectDirectory(root);
  }

  static Future<void> _directory(Directory directory, {bool create = true}) async {
    final type = await FileSystemEntity.type(directory.path, followLinks: false);
    if (type != FileSystemEntityType.notFound && type != FileSystemEntityType.directory) _conflict(directory.path);
    if (create) await directory.create(recursive: true);
    if (!create && type != FileSystemEntityType.directory) _conflict(directory.path);
  }
}
