import 'dart:convert';

import 'package:porelo_host/porelo_host.dart';

/// A public WireGuard key shared by the app's host setup fixtures.
final wireGuardKey = base64Encode(List.filled(32, 1));

/// The public completion values produced by the app's server fixture.
Map<String, Object?> hostValues() => {
  'address': '203.0.113.7',
  'endpoint': '203.0.113.7:51820',
  'wireguard_public_key': wireGuardKey,
  'network': '10.73.7.0/24',
  'ssh_host_key': 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
  'ca_sha256': 'a' * 64,
  'homeserver': 'matrix.orchard.porelo.internal',
};

/// An in-memory store that performs the app tests' actual reads and writes.
class MemorySecrets implements SecretStore {
  /// The fixture's current entries.
  final values = <String, String>{};

  @override
  Future<String?> read(String name) async => values[name];

  @override
  Future<void> write(String name, String value) async {
    values[name] = value;
  }

  @override
  Future<void> remove(String name) async => values.remove(name);

  @override
  Future<void> close() async {}
}

/// A root helper whose response is supplied by the app test.
class HelperRemote implements Remote {
  /// Answers each run with the supplied public reply or refusal.
  HelperRemote({this.response = '', this.code = 0, this.errors = ''});

  /// The public JSON response to emit.
  final String response;

  /// The helper's exit code.
  final int code;

  /// Its verbatim refusal on standard error.
  final String errors;

  /// The remote commands requested by the app.
  final commands = <String>[];

  @override
  Future<RemoteResult> run(
    String host,
    String user,
    String command, {
    String? input,
    void Function(String)? onLine,
  }) async {
    commands.add(command);
    if (response.isNotEmpty) onLine?.call(response);
    return RemoteResult(code, errors);
  }

  @override
  Future<RemoteResult> copy(String host, String user, String from, String to) =>
      throw UnsupportedError('The helper fixture copies no files.');
}
