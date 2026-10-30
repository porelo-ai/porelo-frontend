import 'package:porelo_host/porelo_host.dart';

/// A public Ed25519 test key with a complete SSH blob.
const personKey = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

/// The agreed public SSH completion fixture.
Map<String, Object?> hostValues() => {
  'name': 'orchard',
  'address': '203.0.113.7',
  'ssh_port': 22,
  'ssh_host_key': personKey,
  'services': {
    'forge': {'web_port': 8081, 'git_port': 8082},
    'matrix': {'port': 8083},
  },
};

/// An in-memory encrypted-store boundary performing actual reads and writes.
class MemorySecrets implements SecretStore {
  /// The test's current entries.
  final values = <String, String>{};
  @override
  Future<String?> read(String name) async => values[name];
  @override
  Future<void> write(String name, String value) async {
    values[name] = value;
  }

  @override
  Future<void> remove(String name) async {
    values.remove(name);
  }

  @override
  Future<void> close() async {}
}
