import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/access_developers.dart';
import 'package:porelo_frontend/src/app/project_developers.dart';

const ssh = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
final wg = base64Encode(List.filled(32, 1));
String accessFile({String network = '10.77.0.0/29', String developers = '{}'}) =>
    'host: {network: $network, ssh_host_key: "$ssh"}\ndevelopers: $developers\n';
String developer(String account, String address) =>
    '''
  $account:
    laptops:
      - ssh_public_key: "$ssh"
        wireguard_public_key: "$wg"
        vpn_address: $address
''';

void main() {
  // Harm: assigning the host or another laptop address disrupts VPN admission.
  test('address allocation reads the actual host network and all listed laptops', () {
    final access = parseAccessDevelopers(
      accessFile(developers: '\n${developer('alice', '10.77.0.2')}${developer('bob', '10.77.0.4')}'),
    );
    expect(access.hostAddress, '10.77.0.1');
    expect(access.nextAddress(), '10.77.0.3');
    expect(access.nextAddress(reserved: ['10.77.0.3']), '10.77.0.5');
    for (final address in [
      '10.77.0.0',
      '10.77.0.1',
      '10.77.0.2',
      '10.77.0.4',
      '10.77.0.7',
      '10.73.0.2',
      '010.77.0.3',
    ]) {
      expect(() => access.checkAddress(address), throwsFormatException, reason: '$address is unavailable');
    }
  });

  // Harm: malformed access or repeated addresses can revoke or route someone else's laptop.
  for (final (index, developers) in [
    '[]',
    '{alice: {laptops: []}}',
    '\n${developer('alice', '10.77.0.2')}${developer('bob', '10.77.0.2')}',
    '\n${developer('alice', '10.77.0.1')}',
    '\n${developer('alice', '10.77.0.2')}    forge_login: "../elsewhere"\n',
  ].indexed) {
    test('invalid developer mapping is refused without exposing contents (case $index)', () {
      expect(
        () => parseAccessDevelopers(accessFile(developers: developers)),
        throwsA(isA<FormatException>().having((e) => e.message, 'safe reason', isNot(contains(wg)))),
      );
    });
  }

  // Harm: a secret or an unchecked key can enter the signed access repository.
  test('public key parsing strips SSH comments and refuses private or malformed keys', () {
    final public = parseLaptopPublicKeys(
      'ssh_public_key: "$ssh private-comment"\nwireguard_public_key: "$wg"',
      '10.77.0.2',
    );
    expect(public.sshPublicKey, ssh);
    for (final block in [
      '-----BEGIN OPENSSH PRIVATE KEY-----\nsensitive-fixture\n-----END OPENSSH PRIVATE KEY-----',
      'ssh_public_key: "$ssh"\nwireguard_private_key: "$wg"',
      'ssh_public_key: "ssh-ed25519 AAAA"\nwireguard_public_key: "$wg"',
      'ssh_public_key: "$ssh"\nwireguard_public_key: "bad-key"',
      'ssh_public_key: "$ssh"\nwireguard_public_key: "$wg"\ntoken: sensitive-fixture',
    ]) {
      expect(
        () => parseLaptopPublicKeys(block, '10.77.0.2'),
        throwsA(isA<FormatException>().having((e) => e.message, 'safe reason', isNot(contains('sensitive-fixture')))),
      );
    }
  });

  // Harm: a full network must not yield an address outside its subnet.
  test('an exhausted network refuses allocation', () {
    final access = parseAccessDevelopers(
      accessFile(network: '10.77.0.0/30', developers: '\n${developer('alice', '10.77.0.2')}'),
    );
    expect(access.nextAddress, throwsFormatException);
  });

  // Harm: unrelated comments or access entries are destroyed when one laptop is removed.
  test('removing one laptop preserves the other developer and remaining laptop comments', () {
    final source = accessFile(developers: '\n${developer('alice', '10.77.0.2')}${developer('bob', '10.77.0.3')}')
        .replaceFirst('  bob:', '  # Bob stays\n  bob:')
        .replaceFirst(
          'vpn_address: 10.77.0.2',
          'vpn_address: 10.77.0.2 # Alice laptop\n      - ssh_public_key: "$ssh"\n        wireguard_public_key: "$wg"\n        vpn_address: 10.77.0.4 # Lost laptop',
        );
    final alice = parseAccessDevelopers(source).developers['alice']!;
    final written = writeAccessDeveloper(source, 'alice', AccessDeveloper('alice', null, [alice.laptops.first]));
    expect(written, contains('# Alice laptop'));
    expect(written, contains('# Bob stays'));
    final parsed = parseAccessDevelopers(written);
    expect(parsed.developers['alice']!.laptops.map((l) => l.vpnAddress), ['10.77.0.2']);
    expect(parsed.developers['bob']!.laptops.single.vpnAddress, '10.77.0.3');
  });

  // Harm: untrusted sync output can make an unconfirmed or different project look admitted.
  test('sync replies require both revisions and coherent account and laptop lists', () {
    final answer = <String, Object>{
      'project': 'demo',
      'commit': 'a' * 40,
      'access_commit': 'b' * 40,
      'added': ['alice'],
      'dropped': ['bob'],
      'unchanged': ['carol'],
      'laptops_added': ['alice/l1'],
      'laptops_dropped': <String>[],
    };
    final parsed = DeveloperSyncAnswer.read(jsonEncode(answer), 'demo');
    expect(parsed.state('alice'), 'admitted by last sync');
    expect(parsed.state('bob'), 'dropped by last sync');
    expect(parsed.state('carol'), 'unchanged at last sync');
    for (final edit in <Map<String, Object>>[
      {'project': 'other'},
      {'access_commit': 'bad'},
      {'commit': ''},
      {
        'added': ['../unsafe'],
      },
      {
        'dropped': ['alice'],
      },
      {
        'laptops_added': ['alice/../l1'],
      },
    ]) {
      expect(() => DeveloperSyncAnswer.read(jsonEncode({...answer, ...edit}), 'demo'), throwsFormatException);
    }
  });
}
