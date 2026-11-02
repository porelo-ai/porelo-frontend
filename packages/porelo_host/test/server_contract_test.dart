import 'package:porelo_host/porelo_host.dart';
import 'package:test/test.dart';

const sshKey = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
Map<String, Object?> hostValues() => {
  'name': 'orchard',
  'address': '203.0.113.7',
  'ssh_port': 22,
  'ssh_host_key': sshKey,
  'services': {
    'forge': {'web_port': 8081, 'git_port': 8082},
    'matrix': {'port': 8083},
  },
};
void main() {
  // Harm: a private rental cannot finish when the reader demands retired host fields.
  test('Machines completion accepts a private rental without retired fields', () {
    final host = PreparedHost.read({
      'address': '192.0.2.24',
      'ssh_host_key': sshKey,
      'homeserver': 'orchard',
      'services': {
        'forge': {'web_port': 8080, 'git_port': 2222},
      },
    }, hostName: 'orchard');
    expect(host.name, 'orchard');
    expect(host.sshPort, 22);
    expect(host.services, PreparedHost.defaultLocalServices);
    expect(host.address, '192.0.2.24');
  });

  // Harm: an obsolete field directs a newly prepared server's SSH connection to another service.
  test('Machines completion cannot override the preparation SSH port', () {
    final result = PreparedHost.read({...hostValues(), 'ssh_port': 2222}, hostName: 'orchard');
    expect(result.sshPort, 22);
  });

  // Harm: unusable SSH targets are accepted for signed host cards.
  for (final address in [
    '127.0.0.1',
    '0.0.0.0',
    '0.0.0.1',
    '224.0.0.1',
    '240.0.0.1',
    '255.255.255.255',
    '::ffff:0:1',
    '::ffff:ffff:ffff',
    'localhost',
    'orchard.localhost',
    '::1',
    '::',
    'ff02::1',
    '::ffff:7f00:1',
    '-oProxyCommand=x',
    '2001:db8::7%eth0',
  ]) {
    test('completion refuses unusable SSH address $address', () {
      expect(() => PreparedHost.read({...hostValues(), 'address': address}), throwsFormatException);
    });
  }

  // Harm: a saved card or given server by name or IPv6 address, which Core's card takes, stops reading back.
  for (final address in ['orchard.example.org', 'orchard', '2001:db8::7', '::ffff:c000:207', '203.0.113.7']) {
    test('a saved card reads back at $address', () {
      final saved = PreparedHost.read({...hostValues(), 'name': 'orchard', 'address': address});
      expect(saved.address, address);
      expect(PreparedHost.read(saved.stored).address, address);
    });
  }

  // Harm: Core's host card is misread, so its host is taken from another field than Core names it in, or an address
  // Core's card takes refuses every joinable project.
  test('Core\'s host card is read with Core\'s fields and every address form its card takes', () {
    Map<String, Object?> card(String address) => {
      'host': 'orchard',
      'address': address,
      'ssh_port': 2222,
      'ssh_host_key': sshKey,
      'services': {
        'forge': {'web_port': 8081, 'git_port': 8082},
        'matrix': {'port': 8083},
      },
      'signed_by': 'SHA256:${'A' * 43}',
    };
    for (final address in ['203.0.113.7', 'orchard.example.org', 'orchard', '2001:db8::7', '::1', '127.0.0.1']) {
      final host = PreparedHost.card(card(address));
      expect((host.name, host.address, host.sshPort), ('orchard', address, 2222), reason: address);
    }
    expect(() => PreparedHost.card({...card('203.0.113.7'), 'host': null, 'name': 'orchard'}), throwsFormatException);
    for (final address in ['', '0177.0.0.1', '127.1', 'a b', 'fe80::1%eth0', '[::1]', 'host:22', '-oProxy', 'x.0x7f']) {
      expect(() => PreparedHost.card(card(address)), throwsFormatException, reason: address);
    }
  });

  // Harm: invalid limits or port collisions can exhaust a host or connect to the wrong service.
  test('preparation settings reject invalid limits and round trip the optional role defaults', () {
    expect(const HostPreparationSettings().roleSettings, isEmpty);
    final choices = HostPreparationSettings.read({
      'forge_runner_capacity': 1,
      'forge_job_cpus': 1,
      'forge_job_memory': '768m',
      'forge_web_port': 3100,
      'forge_git_port': 3101,
      'matrix_port': 8548,
    });
    expect(HostPreparationSettings.read(choices.stored).stored, choices.stored);
    for (final patch in <Map<String, Object?>>[
      {'forge_runner_capacity': 0},
      {'forge_job_cpus': -1},
      {'forge_job_cpus': '1'},
      {'forge_job_memory': '768m;touch file'},
      {'forge_job_memory': '0m'},
      {'forge_web_port': 0},
      {'forge_git_port': 65536},
      {'matrix_port': 3000},
    ]) {
      expect(() => HostPreparationSettings.read(patch), throwsFormatException, reason: '$patch must not reach setup');
    }
  });

  // Harm: shell syntax or an extra authorized key reaches root's bootstrap command.
  test('bootstrap takes exactly one checked card key into a separate-terminal instruction', () {
    expect(
      hostRootBootstrapCommand(sshKey),
      contains("printf '%s\\n' '$sshKey' | sudo tee /root/.ssh/authorized_keys"),
    );
    expect(() => hostRootBootstrapCommand('$sshKey\n$sshKey'), throwsFormatException);
  });

  // Harm: a malformed service endpoint or host key redirects trust before publication.
  test('SSH completion round trips its checked public fields and rejects malformed endpoints', () {
    final json = <String, Object?>{
      'name': 'orchard',
      'address': '203.0.113.7',
      'ssh_port': 22,
      'ssh_host_key': sshKey,
      'services': {
        'forge': {'web_port': 3000, 'git_port': 3001},
        'matrix': {'port': 8448},
      },
    };
    final host = PreparedHost.read(json);
    expect(host.stored, json);
    expect(Step.fromLine(Step('host', StepState.host, host: host).toLine())!.host!.stored, json);
    for (final patch in <Map<String, Object?>>[
      {'ssh_port': '22'},
      {'ssh_port': 0},
      {'ssh_host_key': '$sshKey comment'},
      {'name': '../elsewhere'},
      {
        'services': {
          'forge': {'web_port': 3000, 'git_port': 3000},
          'matrix': {'port': 8448},
        },
      },
      {
        'services': {
          'forge': {'web_port': 3000},
          'matrix': {'port': 8448},
        },
      },
    ]) {
      expect(() => PreparedHost.read({...json, ...patch}), throwsFormatException);
    }
  });

  // Harm: malformed host endpoints can redirect a person's SSH connection or browser to another service.
  test('the SSH completion refuses missing or malformed public fields', () {
    for (final field in hostValues().keys) {
      final raw = hostValues()..remove(field);
      expect(() => PreparedHost.read(raw), throwsFormatException, reason: 'the completion must supply $field');
    }
    for (final invalid in [0, -1, 65536, '22']) {
      expect(() => PreparedHost.read({...hostValues(), 'ssh_port': invalid}), throwsFormatException);
    }
    expect(() => PreparedHost.read({...hostValues(), 'name': '-option'}), throwsFormatException);
    expect(() => PreparedHost.read({...hostValues(), 'ssh_host_key': 'ssh-ed25519 malformed'}), throwsFormatException);
    expect(
      () => PreparedHost.read({
        ...hostValues(),
        'services': {
          'forge': {'web_port': 8081, 'git_port': 8081},
          'matrix': {'port': 8083},
        },
      }),
      throwsFormatException,
    );
  });
}
