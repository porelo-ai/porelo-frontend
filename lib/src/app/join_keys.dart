import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as path;
import 'package:porelo_host/porelo_host.dart';

import 'access_checkout.dart';
import 'run_here.dart';

/// This laptop's public SSH and WireGuard halves for one host.
typedef JoinPublicKeys = ({String ssh, String wireguard});

/// Keeps each host's laptop keys in the system secret store.
class JoinKeys {
  /// Uses the same store and WireGuard entry as the existing host VPN.
  JoinKeys(this.store);

  /// The encrypted system store, never an operation record or clipboard.
  final SecretStore store;

  static String _sshName(String host) => 'porelo-host/ssh-$host';

  /// Whether an identity uses the join's private runtime layout for this host.
  static bool isRuntimeIdentity(String identity, String host) =>
      path.basename(identity) == 'identity' && path.basename(path.dirname(identity)) == 'porelo-join-$host';

  /// Reads existing keys, creating them only for the explicit public-key copy action.
  Future<JoinPublicKeys> publicKeys(String host, {bool create = false}) async {
    checkHostName(host);
    var seed = await store.read(_sshName(host));
    if (seed == null && create) {
      final pair = await Ed25519().newKeyPair();
      try {
        seed = base64Encode(await pair.extractPrivateKeyBytes());
        await store.write(_sshName(host), seed);
        if (await store.read(_sshName(host)) != seed) throw const SecretStoreFailed('The SSH key was not kept.');
      } finally {
        pair.destroy();
      }
    }
    if (seed == null) throw const WorkspaceRefused('Copy my public keys for this host first.');
    final pair = await _sshPair(seed);
    final String ssh;
    try {
      ssh = 'ssh-ed25519 ${base64Encode(_publicBlob((await pair.extractPublicKey()).bytes))}';
    } finally {
      pair.destroy();
    }
    final wireguard = create
        ? (await HostFiles(store).prepare(project: host, url: '', signingKey: File(''))).peerPublicKey
        : await _wireguard(host);
    return (ssh: ssh, wireguard: wireguard);
  }

  Future<String> _wireguard(String host) async {
    final private = await store.read(HostFiles.keyName(host));
    if (private == null) throw const WorkspaceRefused('Copy my public keys for this host first.');
    return HostFiles.publicKey(private);
  }

  /// Copies only the two public fields that the admin's developer list needs.
  Future<String> block(String host) async {
    final keys = await publicKeys(host, create: true);
    return 'ssh_public_key: "${keys.ssh}"\nwireguard_public_key: "${keys.wireguard}"\n';
  }

  /// Restores an SSH identity only into this user's private runtime directory.
  ///
  /// The stable runtime path lets the watched host reuse it; the secret store remains its lasting source.
  Future<String> identity(String host, {Map<String, String>? environment}) async {
    checkHostName(host);
    final runtime = (environment ?? Platform.environment)['XDG_RUNTIME_DIR'];
    const refused = WorkspaceRefused('The join needs XDG_RUNTIME_DIR owned by this user with permissions 0700.');
    if (runtime == null ||
        !path.isAbsolute(runtime) ||
        await FileSystemEntity.type(runtime, followLinks: false) != FileSystemEntityType.directory) {
      throw refused;
    }
    final owner = await runHere('/usr/bin/id', ['-u']);
    final stat = await runHere('/usr/bin/stat', ['-c', '%u %a', '--', runtime]);
    if (owner.code != 0 || stat.code != 0 || stat.out.trim() != '${owner.out.trim()} 700') throw refused;
    final seed = await store.read(_sshName(host));
    if (seed == null) throw const WorkspaceRefused('Copy my public keys for this host first.');
    final pair = await _sshPair(seed);
    try {
      final public = (await pair.extractPublicKey()).bytes;
      final private = await pair.extractPrivateKeyBytes();
      final folder = Directory(path.join(runtime, 'porelo-join-$host'));
      await privateDirectory(folder);
      final identity = File(path.join(folder.path, 'identity'));
      if (await FileSystemEntity.type(identity.path, followLinks: false) == FileSystemEntityType.link) throw refused;
      await HostFileWriter().write(identity, utf8.encode(_openSsh(private, public)));
      return identity.path;
    } finally {
      pair.destroy();
    }
  }

  Future<SimpleKeyPair> _sshPair(String seed) async {
    try {
      final bytes = base64Decode(seed);
      if (bytes.length != 32 || base64Encode(bytes) != seed) throw const FormatException();
      return await Ed25519().newKeyPairFromSeed(bytes);
    } on FormatException {
      throw const SecretStoreFailed('The stored SSH key is not valid.');
    }
  }

  static List<int> _number(int number) => (ByteData(4)..setUint32(0, number)).buffer.asUint8List();
  static List<int> _field(List<int> bytes) => [..._number(bytes.length), ...bytes];
  static List<int> _publicBlob(List<int> public) => [..._field(utf8.encode('ssh-ed25519')), ..._field(public)];

  static String _openSsh(List<int> seed, List<int> public) {
    const check = 0;
    final private = <int>[
      ..._number(check),
      ..._number(check),
      ..._publicBlob(public),
      ..._field([...seed, ...public]),
      ..._field(const []),
    ];
    for (var pad = 1; private.length % 8 != 0; pad++) {
      private.add(pad);
    }
    final bytes = [
      ...utf8.encode('openssh-key-v1\x00'),
      ..._field(utf8.encode('none')),
      ..._field(utf8.encode('none')),
      ..._field(const []),
      ..._number(1),
      ..._field(_publicBlob(public)),
      ..._field(private),
    ];
    final body = base64Encode(bytes).replaceAllMapped(RegExp('.{1,70}'), (match) => '${match[0]}\n');
    return '-----BEGIN OPENSSH PRIVATE KEY-----\n$body-----END OPENSSH PRIVATE KEY-----\n';
  }
}
