@Tags(<String>['keystore'])
library;

import 'dart:io';

import 'package:porelo_host/porelo_host.dart';
import 'package:test/test.dart';

/// Against the store of the system the test runs on, never a stand-in: the point is that the
/// value goes into the system's store and comes out of it again.
void main() {
  final store = SecretStore.forThisSystem();
  final name = 'porelo-host-test/$pid';
  final other = 'porelo-host-test/$pid-other';

  tearDown(() async {
    await store.remove(name);
    await store.remove(other);
  });

  tearDownAll(store.close);

  test('a value kept under a name comes back under that name and no other', () async {
    await store.write(name, 'key-one');

    expect(await store.read(name), 'key-one');
    expect(await store.read(other), isNull, reason: 'a name is its own entry');
  });

  test('a second write replaces the first', () async {
    await store.write(name, 'key-one');
    await store.write(name, 'key-two');

    expect(await store.read(name), 'key-two');
  });

  test('a removed value is gone, and removing nothing is no fault', () async {
    await store.write(name, 'key-one');
    await store.remove(name);

    expect(await store.read(name), isNull);
    await store.remove(name);
  });

  test('a value with every kind of character comes back byte for byte', () async {
    const value = 'scw-Ünïcödé key: "quoted" \'single\' \$dollar \\ back\nslash and tab\t';
    await store.write(name, value);

    expect(await store.read(name), value);
  });

  test('key set takes the key from standard input only, and key forget removes it', () async {
    final provider = 'test-provider-$pid';
    final dart = Platform.resolvedExecutable;
    final setting = await Process.start(dart, <String>['run', 'bin/porelo_host.dart', 'key', 'set', provider]);
    setting.stdin.writeln('cli-key-value');
    await setting.stdin.close();
    final out = setting.stdout.drain<void>();
    final said = await setting.stderr.transform(const SystemEncoding().decoder).join();
    await out;
    expect(await setting.exitCode, 0, reason: said);
    expect(said, isNot(contains('cli-key-value')), reason: 'the key is never said back');
    expect(await store.read(providerKeyName(provider)), 'cli-key-value');

    final forgetting = await Process.run(dart, <String>['run', 'bin/porelo_host.dart', 'key', 'forget', provider]);
    expect(forgetting.exitCode, 0, reason: '${forgetting.stderr}');
    expect(await store.read(providerKeyName(provider)), isNull);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
