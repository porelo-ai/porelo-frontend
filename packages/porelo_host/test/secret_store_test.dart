@Tags(<String>['keystore'])
library;

import 'dart:io';
import 'dart:convert';

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

  // Harm: a forge token must enter only through its hidden terminal prompt and share the API store entry.
  test(
    'key set takes the token from its terminal prompt and key forget removes it',
    () async {
      final provider = 'test-$pid.example.org';
      final dart = Platform.resolvedExecutable;
      final setting = await Process.run('python3', <String>[
        '-c',
        r'''import json, os, pty, select, subprocess, sys, termios, time
master, slave = pty.openpty()
process = subprocess.Popen(sys.argv[1:], stdin=slave, stdout=slave, stderr=slave)
transcript = b''
sent = False
deadline = time.monotonic() + 15
try:
    while process.poll() is None:
        if time.monotonic() > deadline:
            raise RuntimeError('the store command did not finish')
        if not select.select([master], [], [], .1)[0]:
            continue
        transcript += os.read(master, 4096)
        if not sent and b'Token for ' in transcript:
            if termios.tcgetattr(slave)[3] & termios.ECHO:
                raise RuntimeError('the token prompt echoes input')
            os.write(master, b'cli-key-value\n')
            sent = True
    print(json.dumps({'output': transcript.decode(), 'exit': process.returncode}))
finally:
    if process.poll() is None:
        process.kill()
    process.wait()
    os.close(master)
    os.close(slave)
''',
        dart,
        'bin/porelo_host.dart',
        'key',
        'set',
        provider,
      ]);
      expect(setting.exitCode, 0, reason: '${setting.stderr}');
      final terminal = jsonDecode(setting.stdout as String) as Map<String, dynamic>;
      expect(terminal['exit'], 0, reason: '${terminal['output']}');
      expect(terminal['output'], isNot(contains('cli-key-value')), reason: 'the key is never said back');
      expect(await store.read(providerKeyName(provider)), 'cli-key-value');

      final forgetting = await Process.run(dart, <String>['run', 'bin/porelo_host.dart', 'key', 'forget', provider]);
      expect(forgetting.exitCode, 0, reason: '${forgetting.stderr}');
      expect(await store.read(providerKeyName(provider)), isNull);
    },
    timeout: const Timeout(Duration(minutes: 3)),
    skip: !Platform.isLinux ? 'CLI prompt requires Linux PTYs.' : false,
  );
}
