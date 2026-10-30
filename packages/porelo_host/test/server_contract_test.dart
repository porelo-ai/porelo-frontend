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
