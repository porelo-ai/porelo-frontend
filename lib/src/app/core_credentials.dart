import 'dart:convert';

import 'run_here.dart';

/// One SSH key offered by a host, without trusting it.
typedef OfferedHostKey = ({String type, String fingerprint});

/// Core's credential commands, with checked JSON answers and no private diagnostics.
class CoreCredentials {
  /// Uses the ordinary process boundary, replaceable in tests.
  CoreCredentials({RunHere? run}) : _run = run ?? runHere;

  final RunHere _run;

  /// Refuses anything that could become an option or name more than one SSH destination.
  static String host(String value) {
    final match = RegExp(r'^([A-Za-z0-9][A-Za-z0-9.-]*)(?::([0-9]{1,5}))?$').firstMatch(value);
    final port = match?.group(2);
    if (match == null || port != null && (int.parse(port) < 1 || int.parse(port) > 65535)) {
      throw const WorkspaceRefused('The SSH host address could not be read.');
    }
    return value;
  }

  static OfferedHostKey _key(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['type'] is! String ||
        !RegExp(r'^[a-zA-Z0-9@._+-]+$').hasMatch(value['type'] as String) ||
        value['fingerprint'] is! String ||
        !RegExp(r'^SHA256:[A-Za-z0-9+/]{43}$').hasMatch(value['fingerprint'] as String)) {
      throw const WorkspaceRefused('Porelo did not answer a readable SSH host key.');
    }
    return (type: value['type'] as String, fingerprint: value['fingerprint'] as String);
  }

  Future<Map<String, dynamic>> _call(List<String> arguments, {String? input}) async {
    final Ran ran;
    try {
      ran = await _run('porelo', [...arguments, '--json'], input: input);
    } on Exception {
      throw const WorkspaceRefused('Porelo could not be asked. Its result is unconfirmed.');
    }
    // Neither output stream is diagnostic material: a faulty helper may echo its input.
    if (ran.code != 0) {
      throw const WorkspaceRefused('Porelo did not confirm this change. Ask again before continuing.');
    }
    try {
      final answer = jsonDecode(ran.out);
      if (answer is Map<String, dynamic>) return answer;
    } on FormatException {
      // A malformed answer says nothing about whether a write happened.
    }
    throw const WorkspaceRefused('Porelo gave an answer that could not be read. Its result is unconfirmed.');
  }

  /// Fetches keys without recording any of them.
  Future<({List<OfferedHostKey> keys, bool known})> offered(String destination) async {
    final answer = await _call(['credentials', 'trust-host', host(destination)]);
    final keys = answer['keys'];
    if (answer['host'] != destination || answer['known'] is! bool || keys is! List || keys.isEmpty) {
      throw const WorkspaceRefused('Porelo cannot say which SSH host key is offered.');
    }
    return (keys: List<OfferedHostKey>.unmodifiable(keys.map(_key)), known: answer['known'] as bool);
  }

  /// Records only the exact key the person compared, and checks Core's echo.
  Future<void> trust(String destination, OfferedHostKey key) async {
    _key({'type': key.type, 'fingerprint': key.fingerprint});
    final answer = await _call(['credentials', 'trust-host', host(destination), '--fingerprint=${key.fingerprint}']);
    if (answer['host'] != destination || _key(answer['recorded']) != key) {
      throw const WorkspaceRefused('Porelo did not confirm the SSH host key you chose.');
    }
  }

  /// Hands a token to the vault through standard input alone; unchanged is also a confirmed put.
  Future<void> putToken(String name, String token) async {
    if (!RegExp(r'^git\.token\.[a-zA-Z0-9.-]+$').hasMatch(name) || token.trim().isEmpty) {
      throw const WorkspaceRefused('No forge token can be handed to the vault.');
    }
    final answer = await _call(['vault', 'put', name], input: token);
    if (answer['name'] != name || answer['stored'] is! bool) {
      throw const WorkspaceRefused('Porelo did not confirm storing the forge token.');
    }
  }
}
