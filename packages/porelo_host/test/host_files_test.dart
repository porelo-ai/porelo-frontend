import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import 'package:porelo_host/porelo_host.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

const signingKey = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAABAgMEBQYHCAkKCwwNDg8QERITFBUWFxgZGhscHR4f fixture';
const fingerprint = 'SHA256:ZkAslGjFiUHdGf/WUL8rQvkib4PTvQatUV0OUQSncCA';

void main() {
  late Directory scratch;
  late File signing;
  late MemorySecrets store;
  late HostFiles files;
  setUp(() async {
    scratch = await Directory.systemTemp.createTemp('host-files-');
    signing = await File(path.join(scratch.path, 'signing.pub')).writeAsString(signingKey);
    store = MemorySecrets();
    files = HostFiles(store);
  });
  tearDown(() => scratch.delete(recursive: true));
  Future<HostTunnel> prepare({String url = 'https://example.org/demo.git', List<HostKeyFile> keys = const []}) =>
      files.prepare(project: 'demo', folder: scratch.path, url: url, signingKey: signing, keys: keys);

  // Harm: an incompatible key prevents the tunnel from authenticating.
  // Red: reverse the seed before deriving the public key.
  test('WireGuard public derivation matches RFC 7748 Alice', () async {
    List<int> hex(String text) => [
      for (var i = 0; i < text.length; i += 2) int.parse(text.substring(i, i + 2), radix: 16),
    ];
    final private = hex('77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a');
    final public = hex('8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a');
    expect(await HostFiles.publicKey(base64Encode(private)), base64Encode(public));
    for (final invalid in ['bad', base64Encode(List.filled(31, 0))]) {
      await expectLater(HostFiles.publicKey(invalid), throwsA(isA<HostFilesRefused>()));
    }
  });

  // Harm: trusting a different signing key lets the host accept the wrong commits.
  // Red: hash the base64 text instead of the decoded key blob.
  test('signing fingerprint matches the fixed ssh-keygen output', () {
    // ssh-keygen -lf: 256 SHA256:ZkAslGjFiUHdGf/WUL8rQvkib4PTvQatUV0OUQSncCA fixture (ED25519)
    expect(HostFiles.signingFingerprint(signingKey), fingerprint);
    for (final invalid in ['private-key', 'ssh-rsa !!!!', 'ssh-rsa ${signingKey.split(' ')[1]}']) {
      expect(() => HostFiles.signingFingerprint(invalid), throwsA(isA<HostFilesRefused>()));
    }
  });

  // Harm: malformed YAML changes which repository or vault entry the host trusts.
  // Red: interpolate a scalar without jsonEncode, or add tasks/agents.
  test('machine file is exactly the quoted host contract', () {
    expect(
      HostFiles.machineYaml(
        project: 'demo',
        url: 'git:"remote":\nnext',
        fingerprint: fingerprint,
        keys: [HostKeyFile('entry:"name"\nnext', File('/input/key.pem'))],
      ),
      'project:\n  name: "demo"\n  url: "git:\\"remote\\":\\u000anext"\n'
      '  signed_by: "$fingerprint"\nkeys:\n'
      '  - { name: "entry:\\"name\\"\\u000anext", path: "keys/key.pem" }\n',
    );
    expect(HostFiles.machineYaml(project: 'demo', url: 'url', fingerprint: fingerprint), endsWith('keys: []\n'));
  });

  // Harm: YAML line folding can change repository URLs or entry names before the host reads them.
  // Red: omit escaping for newlines or YAML Unicode line separators.
  test('quoted scalars survive YAML parsing byte for byte', () {
    const value = 'quoted" : value\nnext\r\t\u0085\u2028\u2029';
    final yaml = HostFiles.machineYaml(
      project: 'demo',
      url: value,
      fingerprint: fingerprint,
      keys: [HostKeyFile(value, File('/input/key'))],
    );
    final decoded = loadYaml(yaml) as YamlMap;
    expect((decoded['project'] as YamlMap)['url'], value);
    expect(((decoded['keys'] as YamlList).single as YamlMap)['name'], value);
    expect(decoded.keys.toSet(), {'project', 'keys'});
    expect((decoded['project'] as YamlMap).keys.toSet(), {'name', 'url', 'signed_by'});
  });

  // Harm: hostile names escape the folder or feed options to host-side commands.
  // Red: remove checkName for either the vault entry or base name.
  test('hostile names and duplicate destinations are refused', () {
    for (final name in ['../escape', '-option', 'a/b', r'a\b', 'a..b', '', 'a\x00b']) {
      expect(
        () => HostFiles.machineYaml(
          project: 'demo',
          url: 'url',
          fingerprint: fingerprint,
          keys: [HostKeyFile(name, File('/input/key'))],
        ),
        throwsA(isA<HostFilesRefused>()),
      );
    }
    for (final path in ['/input/-option', '/input/a..b']) {
      expect(
        () => HostFiles.machineYaml(
          project: 'demo',
          url: 'url',
          fingerprint: fingerprint,
          keys: [HostKeyFile('entry', File(path))],
        ),
        throwsA(isA<HostFilesRefused>()),
      );
    }
    expect(
      () => HostFiles.machineYaml(
        project: 'demo',
        url: 'url',
        fingerprint: fingerprint,
        keys: [HostKeyFile('one', File('/a/key')), HostKeyFile('two', File('/b/key'))],
      ),
      throwsA(isA<HostFilesRefused>()),
    );
  });

  // Harm: a second setup rotates a key, leaks it into metadata, or writes the person's key to the drive.
  // Red: regenerate an existing key, print a private half, or write the person key into metadata or a file.
  test('two pairs are reused and private keys stay out of metadata and arguments', () async {
    final source = await File(path.join(scratch.path, 'vault-input')).writeAsString('vault-bytes');
    final logLines = <String>[];
    final tunnel = await runZoned(
      () => prepare(keys: [HostKeyFile('credential', source)]),
      zoneSpecification: ZoneSpecification(print: (_, _, _, line) => logLines.add(line)),
    );
    final hostFile = File(path.join(scratch.path, 'porelo-host', 'wireguard.key'));
    final hostPrivate = (await hostFile.readAsString()).trim();
    final peerPrivate = store.values[HostFiles.keyName('demo')]!;
    expect(hostPrivate.length, 44);
    expect(peerPrivate.length, 44);
    expect(hostPrivate, isNot(peerPrivate));
    expect(tunnel.hostPublicKey, await HostFiles.publicKey(hostPrivate));
    expect(tunnel.peerPublicKey, await HostFiles.publicKey(peerPrivate));
    expect(tunnel.arguments, ['--vpn-peer-public-key', tunnel.peerPublicKey, '--vpn-peer-address', '10.73.0.2/32']);
    final repeated = await prepare(keys: [HostKeyFile('credential', source)]);
    expect(repeated.hostPublicKey, tunnel.hostPublicKey);
    expect(repeated.peerPublicKey, tunnel.peerPublicKey);
    expect(store.writes, 1);
    final metadata = await File(path.join(scratch.path, 'porelo-host', 'machine.yml')).readAsString();
    for (final secret in [hostPrivate, peerPrivate]) {
      expect(metadata, isNot(contains(secret)));
      expect(logLines.join('\n'), isNot(contains(secret)), reason: 'preparation must never log either private half');
      expect(tunnel.arguments.join(' '), isNot(contains(secret)));
    }
    expect(await File(path.join(scratch.path, 'porelo-host', 'keys', 'vault-input')).readAsString(), 'vault-bytes');
    await for (final entity in scratch.list(recursive: true)) {
      if (entity is File) expect(await entity.readAsString(), isNot(contains(peerPrivate)), reason: entity.path);
    }
    if (Platform.isLinux) expect((await hostFile.stat()).mode & 0x1ff, 0x180);
  });

  // Harm: the host's private key lies in the clear on the drive once the secrets file keeps it.
  test(
    'with the host key in the secrets file, no wireguard.key goes to the drive and its public half is used',
    () async {
      final hostPrivate = base64Encode(List<int>.generate(32, (index) => index + 1));
      final hostPublic = await HostFiles.publicKey(hostPrivate);

      final tunnel = await files.prepare(
        project: 'demo',
        folder: scratch.path,
        url: 'https://example.org/demo.git',
        signingKey: signing,
        hostPublicKey: hostPublic,
      );

      expect(await File(path.join(scratch.path, 'porelo-host', 'wireguard.key')).exists(), isFalse);
      expect(tunnel.hostPublicKey, hostPublic, reason: 'the half the secrets file gave');
      expect(await File(path.join(scratch.path, 'porelo-host', 'machine.yml')).exists(), isTrue);
    },
  );

  // Harm: a malformed public key reaches the tunnel's configuration and the host's arguments.
  test('a host public key that is not one is refused', () async {
    expect(
      () => files.prepare(
        project: 'demo',
        folder: scratch.path,
        url: 'https://example.org/demo.git',
        signingKey: signing,
        hostPublicKey: 'not a key',
      ),
      throwsA(isA<HostFilesRefused>()),
    );
  });

  // Harm: private material is exported without consent or with world-readable permissions.
  // Red: export the host private key, omit chmod, or export automatically during prepare.
  test('only explicit wg-quick export writes the stored person key with 0600', () async {
    final tunnel = await prepare();
    final destination = File(path.join(scratch.path, 'asked-for.conf'));
    final private = store.values[HostFiles.keyName('demo')]!;
    expect(await destination.exists(), isFalse);
    final readsBefore = store.reads;
    await files.exportTunnel(project: 'demo', tunnel: tunnel, address: '203.0.113.8', destination: destination);
    expect(store.reads, greaterThan(readsBefore));
    final configuration = await destination.readAsString();
    expect(configuration.contains('PrivateKey = $private\n'), isTrue, reason: 'only the person key is exported');
    expect(configuration.contains('PublicKey = ${tunnel.hostPublicKey}\n'), isTrue);
    expect(configuration.contains('Endpoint = 203.0.113.8:51820\n'), isTrue);
    expect(
      configuration.contains('PersistentKeepalive = 25\n'),
      isTrue,
      reason: 'the NATed peer must keep the tunnel reachable',
    );
    if (Platform.isLinux) expect((await destination.stat()).mode & 0x1ff, 0x180);
    await destination.writeAsString('keep');
    await expectLater(
      files.exportTunnel(project: 'demo', tunnel: tunnel, address: '203.0.113.8', destination: destination),
      throwsA(isA<HostFilesRefused>()),
    );
    expect(await destination.readAsString(), 'keep');
  });

  // Harm: a conflict destroys existing configuration or credential bytes.
  // Red: skip preflight and open an existing file in write mode.
  test('every differing destination is named and preserved before other files are written', () async {
    for (final name in ['machine.yml', 'wireguard.key', path.join('keys', 'vault-input')]) {
      final root = Directory(path.join(scratch.path, 'porelo-host'));
      if (await root.exists()) await root.delete(recursive: true);
      await Directory(path.join(root.path, 'keys')).create(recursive: true);
      final destination = await File(path.join(root.path, name)).writeAsString('keep');
      final source = await File(path.join(scratch.path, 'vault-input')).writeAsString('new');
      await expectLater(
        prepare(keys: [HostKeyFile('entry', source)]),
        throwsA(isA<HostFilesRefused>().having((e) => e.message, 'conflicting path', contains(destination.path))),
      );
      expect(await destination.readAsString(), 'keep');
      expect(store.values, isEmpty);
      final actual = await root.list(recursive: true).where((e) => e is File).map((e) => e.path).toList();
      expect(actual, [destination.path]);
    }
  });

  // Harm: a link redirects writes outside the chosen tresor.
  // Red: follow links when checking destination types.
  test('symlink destinations and keys directory are refused', () async {
    final root = await Directory(path.join(scratch.path, 'porelo-host')).create();
    final expected = HostFiles.machineYaml(
      project: 'demo',
      url: 'https://example.org/demo.git',
      fingerprint: fingerprint,
    );
    final outside = await File(path.join(scratch.path, 'outside')).writeAsString(expected);
    final link = await Link(path.join(root.path, 'machine.yml')).create(outside.path);
    await expectLater(prepare(), throwsA(isA<HostFilesRefused>()));
    expect(await outside.readAsString(), expected);
    await link.delete();
    await Link(path.join(root.path, 'keys')).create(scratch.path);
    await expectLater(prepare(keys: [HostKeyFile('entry', outside)]), throwsA(isA<HostFilesRefused>()));
  }, skip: Platform.isWindows ? 'Creating symlinks needs Windows privileges.' : false);
}

class MemorySecrets implements SecretStore {
  final values = <String, String>{};
  int reads = 0;
  int writes = 0;
  @override
  Future<String?> read(String name) async {
    reads++;
    return values[name];
  }

  @override
  Future<void> write(String name, String value) async {
    writes++;
    values[name] = value;
  }

  @override
  Future<void> remove(String name) async => values.remove(name);
  @override
  Future<void> close() async {}
}
