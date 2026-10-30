// Runtime identities and VPN exports use chmod; OpenSSH validates the generated identity.
@Tags(['linux'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/join_keys.dart';
import 'package:porelo_frontend/src/app/run_here.dart';
import 'package:porelo_host/porelo_host.dart';
import 'package:yaml/yaml.dart';

import '../support/host_admin.dart';

void main() {
  // Harm: keys for another laptop or host would make admission fail or share a private identity.
  test('copy reuses this laptop’s host keys and copies only their public halves', () async {
    final store = MemorySecrets();
    final keys = JoinKeys(store);
    final block = await keys.block('orchard');
    final values = Map.of(store.values);
    expect(await keys.block('orchard'), block);
    expect(store.values, values);
    final copied = loadYaml(block) as Map;
    expect(copied.keys.toSet(), {'ssh_public_key', 'wireguard_public_key'});
    checkedEd25519(copied['ssh_public_key'] as String);
    checkWireGuardPublicKey(copied['wireguard_public_key'] as String);
    expect(copied['wireguard_public_key'], await HostFiles.publicKey(values[HostFiles.keyName('orchard')]!));
    for (final secret in values.values) {
      expect(block, isNot(contains(secret)));
    }
    final other = await keys.block('garden');
    expect(other, isNot(block));
    expect(store.values.length, 4);
  });

  // Harm: a join must not silently replace a missing laptop identity after an admin admitted a different one.
  test('reading absent join keys does not create secret-store entries', () async {
    final store = MemorySecrets();
    await expectLater(JoinKeys(store).publicKeys('orchard'), throwsA(isA<WorkspaceRefused>()));
    expect(store.values, isEmpty);
  });

  // Harm: a serialized SSH key that OpenSSH cannot use strands an admitted laptop.
  test('the runtime identity is readable by OpenSSH and agrees with the copied public key', () async {
    final scratch = await Directory.systemTemp.createTemp('join-identity-');
    addTearDown(() => scratch.delete(recursive: true));
    await Process.run('/usr/bin/chmod', ['700', scratch.path]);
    final store = MemorySecrets();
    final keys = JoinKeys(store);
    final public = await keys.publicKeys('orchard', create: true);
    final identity = await keys.identity('orchard', environment: {'XDG_RUNTIME_DIR': scratch.path});
    expect((await File(identity).stat()).mode & 0x1ff, 0x180);
    final read = await Process.run('/usr/bin/ssh-keygen', ['-y', '-f', identity]);
    expect(read.exitCode, 0, reason: '${read.stderr}');
    expect('${read.stdout}'.trim(), public.ssh);
    expect(await keys.identity('orchard', environment: {'XDG_RUNTIME_DIR': scratch.path}), identity);
  });

  // Harm: an unsafe runtime directory could expose a private SSH half to other accounts.
  test('an unsafe runtime directory is refused before exporting an identity', () async {
    final scratch = await Directory.systemTemp.createTemp('join-unprotected-');
    addTearDown(() => scratch.delete(recursive: true));
    await Process.run('/usr/bin/chmod', ['755', scratch.path]);
    final keys = JoinKeys(MemorySecrets());
    await keys.block('orchard');
    await expectLater(
      keys.identity('orchard', environment: {'XDG_RUNTIME_DIR': scratch.path}),
      throwsA(isA<WorkspaceRefused>()),
    );
    expect(await scratch.list().toList(), isEmpty);
  });

  // Harm: the old fixed .2 address would collide with another laptop instead of using the signed allocation.
  test('the VPN export uses this laptop’s listed address and refuses another host network', () async {
    final scratch = await Directory.systemTemp.createTemp('join-vpn-');
    addTearDown(() => scratch.delete(recursive: true));
    final store = MemorySecrets();
    final public = await JoinKeys(store).publicKeys('orchard', create: true);
    final files = HostFiles(store);
    final tunnel = HostTunnel(hostPublicKey: wireGuardKey, peerPublicKey: public.wireguard);
    final destination = File('${scratch.path}/vpn.conf');
    await files.exportTunnel(
      project: 'orchard',
      tunnel: tunnel,
      address: '203.0.113.7',
      networkNumber: 7,
      peerAddress: '10.73.7.10',
      destination: destination,
    );
    final lines = await destination.readAsLines();
    expect(lines, contains('Address = 10.73.7.10/24'));
    expect(lines, contains('AllowedIPs = 10.73.7.1/32'));
    expect((await destination.stat()).mode & 0x1ff, 0x180);
    for (final bad in [
      '10.73.8.10',
      '10.73.7.1',
      '10.73.7.0',
      '10.73.7.255',
      '10.73.7.010',
      '10.73.7.10\nPostUp = evil',
    ]) {
      final refused = File('${scratch.path}/refused.conf');
      await expectLater(
        files.exportTunnel(
          project: 'orchard',
          tunnel: tunnel,
          address: '203.0.113.7',
          networkNumber: 7,
          peerAddress: bad,
          destination: refused,
        ),
        throwsA(isA<HostFilesRefused>()),
      );
      expect(await refused.exists(), isFalse);
    }
  });
}
