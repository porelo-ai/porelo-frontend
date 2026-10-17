import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/machines.dart';

import '../support/e2e.dart';

/// Usage: every reply it gives can be read
Future<void> everyReplyItGivesCanBeRead(WidgetTester tester) async {
  // Through the same forward the interface raised, so this reads what the window reads.
  final client = await PoreloClient.connect(
      Backend(socketPath: Machine.endpointFor(E2e.name), label: E2e.name));
  final tasks = await client.tasks();
  final projects = await client.projects();
  // Said, so a green run shows it read a real machine rather than an empty one.
  debugPrint('${E2e.name} answered: ${tasks.length} tasks, ${projects.length} projects');

  final missing = <String>[];
  Future<void> reads(String method, Future<Object?> Function() call) async {
    try {
      await call();
    } on FeatureNotSupported {
      // Older than this build: absent is allowed, unreadable is not.
      missing.add(method);
    }
  }

  await reads('Sets', client.sets);
  await reads('Agents', client.agents);
  await reads('Credentials', client.credentials);
  await reads('Doctor', client.doctor);
  await reads('Providers', client.providers);
  await reads('Node', client.node);
  await reads('the contract', client.contract);
  await reads('SshKeys', () async {
    final keys = await client.sshKeys();
    debugPrint('${E2e.name} has ${keys.length} ssh keys');
    for (final key in keys) {
      // Described, never read out: nothing of a key's body may come back in any field.
      final said = [key.path, key.type, key.fingerprint, key.comment, key.obstacle].join(' ');
      expect(said, isNot(contains('PRIVATE KEY')), reason: 'a value came back for ${key.path}');
      if (key.fingerprint.isNotEmpty) expect(key.fingerprint, startsWith('SHA256:'));
    }
    return keys;
  });
  if (missing.isNotEmpty) debugPrint('not on this daemon: ${missing.join(', ')}');
}
