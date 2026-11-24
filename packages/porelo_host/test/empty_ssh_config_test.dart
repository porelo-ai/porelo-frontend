import 'dart:io';

import 'package:porelo_host/porelo_host.dart';
import 'package:test/test.dart';

void main() {
  // Harm: ssh reads the person's own configuration where it must not, or a pin left beside it outlives its call.
  test('an empty ssh config lies in a private folder of its own, gone after its action', () async {
    File? seen;
    final answer = await withEmptySshConfig(prefix: 'porelo-test-', (config) async {
      seen = config;
      expect(await config.readAsString(), '');
      if (Platform.isLinux) {
        expect((await config.parent.stat()).mode & 0x1ff, 0x1c0, reason: 'the folder must be private');
      }
      return 7;
    });
    expect(answer, 7);
    expect(await seen!.parent.exists(), isFalse);
  });

  // Harm: an action that fails leaves its config and the files beside it, such as a pinned known_hosts, behind.
  test('the folder, with what the action put beside the config, is gone after the action throws', () async {
    File? knownHosts;
    await expectLater(
      withEmptySshConfig<void>(prefix: 'porelo-test-', (config) async {
        knownHosts = File('${config.parent.path}${Platform.pathSeparator}known_hosts');
        await knownHosts!.writeAsString('192.0.2.7 ssh-ed25519 AAAA\n');
        throw StateError('refused');
      }),
      throwsA(isA<StateError>()),
    );
    expect(await knownHosts!.exists(), isFalse);
    expect(await knownHosts!.parent.exists(), isFalse);
  });
}
