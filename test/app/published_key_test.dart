@Tags(<String>['linux'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/wsl_setup.dart';

/// Holds the fingerprint this build carries to the key the package repository serves.
///
/// Skipped unless asked for, because it reaches the repository over the network:
///
/// ```bash
/// PORELO_PUBLISHED_KEY=1 flutter test test/app/published_key_test.dart
/// ```
///
/// **Every other test compares the fetched key with the carried fingerprint itself**, so a key
/// replaced at the repository passes them all while every setup in WSL stops at the check.
void main() {
  test(
    'the repository serves the key whose fingerprint this build carries',
    () async {
      final here = await Directory.systemTemp.createTemp('porelo-published-key-');
      addTearDown(() => here.delete(recursive: true));
      final key = File('${here.path}/key.asc');
      final fetched = await Process.run('curl', <String>['-fsSL', poreloKeyAddress, '-o', key.path]);
      expect(fetched.exitCode, 0, reason: 'curl $poreloKeyAddress: ${fetched.stderr}');

      final shown = await Process.run(
        'gpg',
        <String>['--show-keys', '--with-colons', key.path],
        environment: <String, String>{'GNUPGHOME': here.path},
      );
      expect(shown.exitCode, 0, reason: 'gpg --show-keys: ${shown.stderr}');
      final served = (shown.stdout as String)
          .split('\n')
          .where((line) => line.startsWith('fpr:'))
          .map((line) => line.split(':')[9])
          .first;

      expect(
        served,
        poreloKeyFingerprint,
        reason: '$poreloKeyAddress serves $served, and this build checks for $poreloKeyFingerprint',
      );
    },
    skip: Platform.environment['PORELO_PUBLISHED_KEY'] == '1'
        ? false
        : 'reaches the repository: set PORELO_PUBLISHED_KEY=1',
  );
}
