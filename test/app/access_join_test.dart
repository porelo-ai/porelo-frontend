import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/access_join.dart';
import 'package:porelo_frontend/src/app/run_here.dart';

import '../support/host_admin.dart';
import '../support/host_matrix_ca.dart';

void main() {
  final keys = (ssh: hostValues()['ssh_host_key']! as String, wireguard: wireGuardKey);
  Map<String, Object?> answer() => {
    'host': Map.of(matrixHostValues())..remove('homeserver'),
    'developers': {
      'dev': {
        'forge_login': 'dev-forge',
        'laptops': [
          {
            'ssh_public_key': '${keys.ssh} a public comment',
            'wireguard_public_key': keys.wireguard,
            'vpn_address': '10.73.7.10',
          },
        ],
      },
    },
    'transports': {
      'matrix': {'homeserver': 'https://matrix.orchard.porelo.internal:8448'},
    },
  };

  // Harm: an account must be selected by both of this laptop's keys, never by a claimed name alone.
  test('the access reader selects a laptop only when both public halves agree', () {
    final access = AccessJoin.read(answer());
    expect(access.laptop(keys), (account: 'dev', address: '10.73.7.10'));
    expect(access.hostName, 'orchard');
    expect(
      () => access.laptop((ssh: keys.ssh, wireguard: base64Encode(List.filled(32, 2)))),
      throwsA(isA<WorkspaceRefused>()),
    );
    expect(() => access.laptop((ssh: '${keys.ssh}wrong', wireguard: keys.wireguard)), throwsA(isA<WorkspaceRefused>()));
  });

  // Harm: ambiguous allocations or unsafe identities could configure a wrong VPN or host account.
  for (final defect in [
    'duplicate address',
    'duplicate SSH',
    'duplicate WireGuard',
    'host address',
    'outside network',
    'root',
    'missing key',
    'private key',
  ]) {
    test('the access reader refuses $defect before selecting an account', () {
      final document = answer();
      final people = document['developers'] as Map;
      final developer = people['dev'] as Map;
      final laptops = developer['laptops'] as List;
      final laptop = laptops.single as Map;
      switch (defect) {
        case 'duplicate address' || 'duplicate SSH' || 'duplicate WireGuard':
          laptops.add(<String, String>{
            ...laptop.cast<String, String>(),
            if (defect != 'duplicate address') 'vpn_address': '10.73.7.11',
            if (defect != 'duplicate SSH')
              'ssh_public_key': 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEB',
            if (defect != 'duplicate WireGuard') 'wireguard_public_key': base64Encode(List.filled(32, 2)),
          });
        case 'host address':
          laptop['vpn_address'] = '10.73.7.1';
        case 'outside network':
          laptop['vpn_address'] = '10.73.8.10';
        case 'root':
          people['root'] = people.remove('dev');
        case 'missing key':
          laptop.remove('ssh_public_key');
        case 'private key':
          laptop['ssh_public_key'] = '-----BEGIN OPENSSH PRIVATE KEY-----';
      }
      expect(() => AccessJoin.read(document), throwsA(isA<WorkspaceRefused>()));
    });
  }
}
