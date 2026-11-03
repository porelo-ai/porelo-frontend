import 'dart:convert';

import 'package:crypto/crypto.dart' show Hmac, sha1;
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/host_organization.dart';
import 'package:porelo_frontend/src/app/organization_source.dart';
import 'package:porelo_frontend/src/app/porelo_organization_source.dart';
import 'package:yaml/yaml.dart';

const _key = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcH';
const _backup = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI';
const _forgeKey = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJ';

/// `porelo org --json` with a host admin's own key and backup key, as the contract's section 2 answers them.
String _answer(List<Map<String, Object?>> admins) => jsonEncode({
  'name': 'acme',
  'kept_in': 'the GitHub organization acme',
  'vouched_by': 'GitHub',
  'revision': '56420b3',
  'stale': false,
  'me': null,
  'owners': <Object?>[],
  'people': <Object?>[],
  'projects': <Object?>[],
  'hosts': [
    {
      'host': 'build',
      'address': null,
      'ssh_port': null,
      'ssh_host_key': null,
      'services': null,
      'admins': admins,
      'projects': <Object?>[],
    },
  ],
  'warnings': <Object?>[],
  'refusals': <Object?>[],
  'sole_without_backup': <Object?>[],
});

Future<OrganizationHost> _read(List<Map<String, Object?>> admins) async {
  final source = PoreloOrganizationSource(
    run: (program, arguments, {inDirectory, environment = const {}, input}) async =>
        (code: 0, out: _answer(admins), err: ''),
  );
  return (await source.read()).hosts.single;
}

void main() {
  group('the pin of a first up', () {
    // Harm: a host trusts too few: the person holding only the backup key is locked out of the host for good.
    test('a backup row stands in the pin and among no holders', () async {
      final host = await _read([
        {'login': 'hank', 'key': _key, 'fingerprint': 'SHA256:h', 'backup': false},
        {'login': 'hank', 'key': _backup, 'fingerprint': 'SHA256:b', 'backup': true},
      ]);
      expect(host.admins, ['hank']);
      expect(hostPin(host), 'hank $_key\nhank $_backup\n');
    });

    // Harm: a pin one row short is taken as whole, and the host trusts fewer people than the organization says.
    test('a row with no key refuses the whole pin', () async {
      final host = await _read([
        {'login': 'hank', 'key': _key, 'backup': false},
        {'login': 'ida', 'key': null, 'backup': false},
      ]);
      expect(host.admins, ['hank', 'ida'], reason: "the organization's pages still read the answer");
      expect(
        () => hostPin(host),
        throwsA(isA<HostAccessRefused>().having((refused) => refused.words, 'words', contains('ida'))),
      );
    });

    // Harm: a key with a line break in it writes a second, forged line into root's pin.
    test('a value that would break out of its line refuses the whole pin', () {
      for (final row in [
        HostAdminKey(login: 'hank', key: '$_key\nmallory $_backup'),
        const HostAdminKey(login: 'hank mallory', key: _key),
      ]) {
        expect(() => hostPin(OrganizationHost(name: 'build', adminKeys: [row])), throwsA(isA<HostAccessRefused>()));
      }
    });

    // Harm: a host with no admin at all can never be reached or changed.
    test('no admin row at all refuses', () {
      expect(() => hostPin(const OrganizationHost(name: 'build')), throwsA(isA<HostAccessRefused>()));
    });
  });

  group('the central forge in known_hosts', () {
    // Harm: a forge off port 22 has no key to hand on, so no host can be prepared for it, or takes one of another port.
    test('a forge on another ssh port is found under the name ssh writes for it, and only there', () {
      final named = forgeInKnownHosts('forge.example.org', 'ssh://git@forge.example.org:2222/team/org.git');
      expect(named, '[forge.example.org]:2222');
      expect(centralForgeKnownHosts(named, '$named $_forgeKey\n'), '$named $_forgeKey\n');
      expect(() => centralForgeKnownHosts(named, 'forge.example.org $_forgeKey\n'), throwsA(isA<HostAccessRefused>()));
      expect(forgeInKnownHosts('[2001:db8::1]', 'ssh://git@[2001:db8::1]:2222/team/org.git'), '[2001:db8::1]:2222');
      expect(forgeInKnownHosts('forge.example.org', 'git+ssh://git@forge.example.org:2222/o.git'), named);
      for (final address in [
        'ssh://git@forge.example.org/team/org.git',
        'ssh://git@forge.example.org:22/team/org.git',
        'git@forge.example.org:team/org.git',
        null,
      ]) {
        expect(forgeInKnownHosts('forge.example.org', address), 'forge.example.org', reason: '$address');
      }
    });

    // Harm: a host takes the first key the forge shows, so whoever stands in between serves it the organization.
    test('no line of that forge stops in words', () {
      expect(
        () => centralForgeKnownHosts('forge.example.org', 'other.example.org $_forgeKey\n# forge.example.org\n'),
        throwsA(
          isA<HostAccessRefused>().having(
            (refused) => refused.words,
            'words',
            allOf(contains('forge.example.org'), contains('first use is not trusted')),
          ),
        ),
      );
      expect(() => centralForgeKnownHosts('forge.example.org', ''), throwsA(isA<HostAccessRefused>()));
    });

    // Harm: another machine's key is pinned as the forge's, or the person's whole file leaves this computer.
    // Harm: a forge key the person's own ssh rejects is handed to a host as trusted.
    test('a wildcard revocation of this forge stops, and a negated one leaves its keys', () {
      const forge = 'forge.example.org';
      expect(
        () => centralForgeKnownHosts(forge, '$forge $_forgeKey\n@revoked *.example.org $_forgeKey\n'),
        throwsA(isA<HostAccessRefused>()),
      );
      expect(
        centralForgeKnownHosts(forge, '$forge $_forgeKey\n@revoked *.example.org,!forge.example.org $_backup\n'),
        '$forge $_forgeKey\n',
      );
    });

    // Harm: a line ssh would not apply to this forge is handed on as pinning it.
    test('a name negated by a wildcard on its own line pins nothing', () {
      const forge = 'forge.example.org';
      expect(
        () => centralForgeKnownHosts(forge, 'forge.example.org,!*.example.org $_forgeKey\n'),
        throwsA(isA<HostAccessRefused>()),
      );
    });

    test("only that forge's own keys are handed on", () {
      expect(
        centralForgeKnownHosts(
          'forge.example.org',
          'other.example.org $_forgeKey\nforge.example.org,192.0.2.1 $_forgeKey mia@laptop\n',
        ),
        'forge.example.org $_forgeKey\n',
      );
    });

    test('a hashed line of that forge counts, as ssh writes it by default on many systems', () {
      final salt = List<int>.generate(20, (index) => index);
      final hash = Hmac(sha1, salt).convert(utf8.encode('forge.example.org')).bytes;
      final line = '|1|${base64Encode(salt)}|${base64Encode(hash)} $_forgeKey';
      expect(centralForgeKnownHosts('forge.example.org', line), 'forge.example.org $_forgeKey\n');
      expect(() => centralForgeKnownHosts('other.example.org', line), throwsA(isA<HostAccessRefused>()));
    });

    // Harm: a wildcard or a certificate authority passes for a pin of this forge, or a revoked key is handed on.
    test('what pins no key of this forge by name does not count, and a revoked key stops', () {
      for (final line in [
        '*.example.org $_forgeKey',
        '@cert-authority forge.example.org $_forgeKey',
        '!forge.example.org,forge.example.org $_forgeKey',
      ]) {
        expect(() => centralForgeKnownHosts('forge.example.org', line), throwsA(isA<HostAccessRefused>()));
      }
      expect(
        () => centralForgeKnownHosts(
          'forge.example.org',
          'forge.example.org $_forgeKey\n@revoked forge.example.org $_key',
        ),
        throwsA(isA<HostAccessRefused>()),
      );
    });
  });

  // Harm: `up` finds no organization part, or a value breaks out of its line, and only after the server is rented.
  test("the machine file is read back as the keys up reads, whatever the values hold", () {
    final read = loadYaml(
      hostMachineFile(
        settings: 'adapter: git\nsettings:\n  repository: "x"\n',
        knownHosts: 'forge.example.org $_forgeKey\n',
        pin: 'hank $_key\nhank $_backup\n',
      ),
    );
    expect(read['organization']['settings'], 'adapter: git\nsettings:\n  repository: "x"\n');
    expect(read['organization']['known_hosts'], 'forge.example.org $_forgeKey\n');
    expect(read['organization']['pin'], 'hank $_key\nhank $_backup\n');
  });
}
