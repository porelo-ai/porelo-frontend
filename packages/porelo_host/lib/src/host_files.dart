import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';

import 'secret_store.dart';
import 'host_file_writer.dart';

/// A vault entry and the file selected for import by the host.
class HostKeyFile {
  /// Names an entry without displaying its value.
  const HostKeyFile(this.name, this.file);

  /// The vault entry name.
  final String name;

  /// The file chosen for import.
  final File file;

  /// The name under the host files directory.
  String get basename => file.uri.pathSegments.last;
}

/// A refusal safe to show without revealing file contents.
class HostFilesRefused implements Exception {
  /// Gives the reason without file contents.
  const HostFilesRefused(this.message);

  /// The safe explanation.
  final String message;
  @override
  String toString() => message;
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
  HostFiles(this.store, {HostFileWriter? writer}) : _writer = writer ?? HostFileWriter();

  final HostFileWriter _writer;

  /// The person private key lives here until an explicit export.
  final SecretStore store;

  /// The project-specific store entry.
  static String keyName(String project) => 'wireguard-$project';

  /// Rejects traversal and option-like names on both supported desktops.
  static void checkName(String name) {
    if (name.isEmpty ||
        name.startsWith('-') ||
        name.contains('..') ||
        name.contains('/') ||
        name.contains(r'\') ||
        name.contains('\x00')) {
      throw const HostFilesRefused('A name must not be empty, start with - or contain /, \\, .. or NUL.');
    }
  }

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
    final fields = publicKey.trim().split(RegExp(r'\s+'));
    if (fields.length < 2) throw const HostFilesRefused('Choose an ssh-ed25519 or ssh-rsa signing public key (.pub).');
    if (fields[0] != 'ssh-ed25519' && fields[0] != 'ssh-rsa') {
      throw const HostFilesRefused('Only ssh-ed25519 and ssh-rsa signing public keys are supported.');
    }
    try {
      final blob = base64Decode(fields[1]);
      final reader = _SshBlob(blob);
      if (utf8.decode(reader.field()) != fields[0]) throw const FormatException();
      if (fields[0] == 'ssh-ed25519') {
        if (reader.field().length != 32) throw const FormatException();
      } else {
        reader.positiveMpint();
        reader.positiveMpint();
      }
      if (!reader.atEnd) throw const FormatException();
      return 'SHA256:${base64Encode(sha256.convert(blob).bytes).replaceAll('=', '')}';
    } on FormatException {
      throw const HostFilesRefused('Choose a valid ssh-ed25519 or ssh-rsa signing public key (.pub).');
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

  /// Writes the machine contract with escaped, double-quoted YAML scalars only.
  static String machineYaml({
    required String project,
    required String url,
    required String fingerprint,
    List<HostKeyFile> keys = const [],
    bool? windows,
  }) {
    checkName(project);
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
    return 'project:\n'
        '  name: ${_scalar(project)}\n'
        '  url: ${_scalar(url)}\n'
        '  signed_by: ${_scalar(fingerprint)}\n'
        '${keys.isEmpty ? 'keys: []\n' : 'keys:\n'}'
        '${keys.map((key) => '  - { name: ${_scalar(key.name)}, path: ${_scalar('keys/${key.basename}')} }\n').join()}';
  }

  /// Reuses existing keys. Without a folder the host files are supplied manually.
  Future<HostTunnel> prepare({
    required String project,
    String? folder,
    required String url,
    required File signingKey,
    List<HostKeyFile> keys = const [],
  }) async {
    checkName(project);
    String? hostPrivate;
    if (folder != null) {
      if (url.trim().isEmpty || !signingKey.path.endsWith('.pub')) {
        throw const HostFilesRefused('Give the repository URL and signing public key (.pub).');
      }
      final yaml = machineYaml(
        project: project,
        url: url,
        fingerprint: signingFingerprint(await signingKey.readAsString()),
        keys: keys,
        windows: _writer.isWindows,
      );
      await _directory(Directory(folder), create: false);
      final root = Directory('$folder${Platform.pathSeparator}porelo-host');
      await _directory(root);
      final hostFile = File('${root.path}/wireguard.key');
      final existing = await FileSystemEntity.type(hostFile.path, followLinks: false);
      if (existing != FileSystemEntityType.notFound) {
        if (existing != FileSystemEntityType.file) _conflict(hostFile.path);
        hostPrivate = (await hostFile.readAsString()).trim();
        try {
          await publicKey(hostPrivate);
        } on HostFilesRefused {
          _conflict(hostFile.path);
        }
      }
      hostPrivate ??= await _privateKey();
      if (keys.isNotEmpty) await _directory(Directory('${root.path}/keys'));
      final contents = <String, List<int>>{
        '${root.path}/machine.yml': utf8.encode(yaml),
        hostFile.path: utf8.encode('$hostPrivate\n'),
        for (final key in keys) '${root.path}/keys/${key.basename}': await key.file.readAsBytes(),
      };
      for (final entry in contents.entries) {
        await _writer.check(File(entry.key), entry.value);
      }
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
      hostPublicKey: hostPrivate == null ? '' : await publicKey(hostPrivate),
      peerPublicKey: await publicKey(peerPrivate),
    );
  }

  /// Reads the person's private half only for the explicitly requested export.
  Future<void> exportTunnel({
    required String project,
    required HostTunnel tunnel,
    required String address,
    required File destination,
  }) async {
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
        '[Interface]\nPrivateKey = $privateKey\nAddress = 10.73.0.2/24\n\n'
        '[Peer]\nPublicKey = ${tunnel.hostPublicKey}\nEndpoint = $endpoint:51820\nAllowedIPs = 10.73.0.1/32\n',
      ),
    );
  }

  static Never _conflict(String path) => throw HostFilesRefused(
    '$path already exists and differs or is not a regular file. Remove it or choose another folder.',
  );

  static Future<void> _directory(Directory directory, {bool create = true}) async {
    final type = await FileSystemEntity.type(directory.path, followLinks: false);
    if (type != FileSystemEntityType.notFound && type != FileSystemEntityType.directory) _conflict(directory.path);
    if (create) await directory.create();
    if (!create && type != FileSystemEntityType.directory) _conflict(directory.path);
  }
}

/// OpenSSH fields carry their own lengths; no trailing byte belongs to a supported key.
class _SshBlob {
  _SshBlob(this.bytes);
  final List<int> bytes;
  int offset = 0;
  bool get atEnd => offset == bytes.length;

  List<int> field() {
    if (bytes.length - offset < 4) throw const FormatException();
    final size = (bytes[offset] << 24) | (bytes[offset + 1] << 16) | (bytes[offset + 2] << 8) | bytes[offset + 3];
    offset += 4;
    if (size > bytes.length - offset) throw const FormatException();
    final value = bytes.sublist(offset, offset + size);
    offset += size;
    return value;
  }

  void positiveMpint() {
    final value = field();
    if (value.isEmpty || value.first >= 128 || (value.first == 0 && (value.length == 1 || value[1] < 128))) {
      throw const FormatException();
    }
  }
}
