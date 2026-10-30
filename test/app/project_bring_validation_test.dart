import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/project_bring.dart';
import 'package:porelo_frontend/src/app/own_host_vpn.dart';
import 'package:porelo_frontend/src/app/join_keys.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/run_here.dart';
import 'package:porelo_host/porelo_host.dart';

import '../support/host_admin.dart';
import '../support/host_matrix_ca.dart';
import '../features/support/world.dart';

class _Following extends FakeBackend {
  _Following(this.project) : super(const []);
  final String project;
  @override
  Future<List<Followed>> following() async => [
    Followed(name: project, url: 'https://example.org/project.git', commit: 'a' * 40),
  ];
}

class _Source extends HostFiles {
  _Source() : super(MemorySecrets());
  var requests = 0;
  @override
  Future<({List<int> bytes, String projectYaml})> createProjectSetup({
    required String project,
    required String url,
    required String commit,
    required File signingKey,
  }) async {
    requests++;
    throw const WorkspaceRefused('source boundary reached');
  }
}

void main() {
  // Harm: a new machine must not publish access or bring before it verifies this host's fetched CA.
  for (final wrongCa in [true, false]) {
    test(
      wrongCa
          ? 'a fetched CA mismatch shows both fingerprints and prevents the bring'
          : 'a new bring connects the supplied laptop address and pasted host before constructing its source',
      () async {
        final scratch = Directory.systemTemp.createTempSync('bring-vpn-');
        addTearDown(() => scratch.deleteSync(recursive: true));
        final signing = File('${scratch.path}/signer.pub')..writeAsStringSync(hostValues()['ssh_host_key']! as String);
        final identity = File('${scratch.path}/identity')..writeAsStringSync('identity fixture');
        final host = PreparedHost.read({...matrixHostValues(), if (wrongCa) 'ca_sha256': '0' * 64});
        final settings = Settings(MemorySettingsStore());
        addTearDown(settings.dispose);
        final files = _Source();
        final activations = <({PreparedHost host, JoinPublicKeys keys, String address, String? ca})>[];
        final keys = (ssh: host.values['ssh_host_key']!, wireguard: wireGuardKey);
        final remote = HelperRemote(response: hostMatrixCa.trimRight());
        final knownHosts = '${scratch.path}/known_hosts.orchard';
        final bring = ProjectBring(
          project: 'demo',
          backend: _Following('demo'),
          machine: Machine(name: 'own account', socketPath: '', host: 'admin@10.73.7.1', identity: identity.path),
          host: host,
          knownHosts: knownHosts,
          secretsFile: '${scratch.path}/secrets.kdbx',
          signingKey: signing,
          accessRoot: '${scratch.path}/access',
          remote: remote,
          files: files,
          setForgePassword: (_, _) async => true,
          connectVpn: () => connectOwnHostVpn(
            host: host,
            account: 'admin',
            keys: keys,
            address: '10.73.7.10',
            settings: settings,
            activate: (host, keys, address, ca) async {
              activations.add((host: host, keys: keys, address: address, ca: ca));
              expect(settings.hostUp('orchard'), isNull, reason: 'recording must follow verified trust');
              expect(files.requests, 0, reason: 'bringing must follow VPN and CA verification');
              return true;
            },
            fetchCa: () => fetchOwnHostCa(host: host, account: 'admin', knownHosts: knownHosts, remote: remote),
          ),
        );
        addTearDown(bring.dispose);
        await bring.bring();
        if (wrongCa) {
          expect(bring.problem, contains('Expected SHA-256: ${'0' * 64}'));
          expect(bring.problem, contains('Received SHA-256: $hostMatrixCaSha256'));
          expect(activations.map((entry) => entry.ca), [null], reason: 'an unverified CA must never reach trust');
          expect(settings.hostUp('orchard'), isNull);
          expect(files.requests, 0);
          expect(Directory('${scratch.path}/access').existsSync(), isFalse);
        } else {
          expect(activations, [
            (host: host, keys: keys, address: '10.73.7.10', ca: null),
            (host: host, keys: keys, address: '10.73.7.10', ca: hostMatrixCa),
          ]);
          expect(files.requests, 1);
          expect(settings.hostUp('orchard')!.vpnPeerAddress, '10.73.7.10/32');
          expect(settings.hostUp('orchard')!.forgeCa, hostMatrixCa);
        }
        expect(remote.commands, ['/usr/bin/cat /etc/porelo-host/forge/ca.pem']);
        expect(File(knownHosts).readAsStringSync(), '10.73.7.1 ${host.values['ssh_host_key']}\n');
      },
      tags: 'linux',
    );
  }

  // Harm: unsafe project identifiers must stop before source construction, private Git, or host operations.
  for (final name in ['a..b', 'trailing.', 'a' * 65]) {
    test('invalid project $name is refused before constructing or publishing its setup', () async {
      final scratch = Directory.systemTemp.createTempSync('bring-preflight-');
      addTearDown(() => scratch.deleteSync(recursive: true));
      final public = File('${scratch.path}/signer.pub')..writeAsStringSync(hostValues()['ssh_host_key']! as String);
      File('${scratch.path}/identity').writeAsStringSync('identity fixture');
      final files = _Source();
      final bring = ProjectBring(
        project: name,
        backend: _Following(name),
        targetBackend: _Following(name),
        machine: Machine(
          name: 'own account',
          socketPath: '',
          kind: 'host',
          host: 'admin@10.73.7.1',
          identity: '${scratch.path}/identity',
        ),
        host: PreparedHost.read(matrixHostValues()),
        knownHosts: '${scratch.path}/known_hosts.orchard',
        secretsFile: '${scratch.path}/secrets.kdbx',
        signingKey: public,
        accessRoot: '${scratch.path}/access',
        remote: HelperRemote(),
        files: files,
        setForgePassword: (_, _) async => true,
        forgeCa: hostMatrixCa,
      );
      addTearDown(bring.dispose);
      await bring.bring();
      expect(files.requests, 0);
      expect(Directory('${scratch.path}/access').existsSync(), isFalse);
    });
  }

  // Harm: an unrelated preflight refusal must not make the unsafe-name guards pass without reaching source validation.
  // Linux only: bringing a project onto a host is not offered on Windows, and its preflight takes POSIX paths.
  test('a valid project with complete inputs reaches the signed source boundary', () async {
    final scratch = Directory.systemTemp.createTempSync('bring-valid-preflight-');
    addTearDown(() => scratch.deleteSync(recursive: true));
    final public = File('${scratch.path}/signer.pub')..writeAsStringSync(hostValues()['ssh_host_key']! as String);
    File('${scratch.path}/identity').writeAsStringSync('identity fixture');
    final files = _Source();
    final bring = ProjectBring(
      project: 'demo',
      backend: _Following('demo'),
      targetBackend: _Following('demo'),
      machine: Machine(
        name: 'own account',
        socketPath: '',
        host: 'admin@10.73.7.1',
        identity: '${scratch.path}/identity',
      ),
      host: PreparedHost.read(matrixHostValues()),
      knownHosts: '${scratch.path}/known_hosts.orchard',
      secretsFile: '${scratch.path}/secrets.kdbx',
      signingKey: public,
      accessRoot: '${scratch.path}/access',
      remote: HelperRemote(),
      files: files,
      setForgePassword: (_, _) async => true,
      forgeCa: hostMatrixCa,
    );
    addTearDown(bring.dispose);
    await bring.bring();
    expect(files.requests, 1);
    expect(bring.problem, 'source boundary reached');
  }, tags: 'linux');
}
