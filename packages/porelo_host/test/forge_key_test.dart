import 'dart:io';
import 'dart:convert';

import 'package:porelo_host/porelo_host.dart';

import 'package:test/test.dart';

void main() {
  // Harm: inconsistent entry names would store the token where the interface cannot read it.
  test('forge entries share the normalized host name and scaleway keeps its own entry', () {
    expect(providerKeyName('Git.Example.org'), 'porelo-forge-token:git.example.org');
    expect(providerKeyName('scaleway'), 'porelo-host/scaleway');
    for (final host in [
      'https://github.com',
      'github.com/other',
      'github.com\n',
      'user@github.com',
      'github.com:443',
      '-github.com',
      'github..com',
      'a.${'b' * 64}',
      '${'a.' * 127}b',
    ]) {
      expect(
        () => providerKeyName(host),
        throwsFormatException,
        reason: 'a public host name cannot carry shell syntax or an arbitrary store key',
      );
    }
  });

  // Harm: echoing a token exposes it in the terminal transcript and screen captures.
  test('the forge prompt reads from its terminal with echo disabled and restores echo', () async {
    final result = await Process.run('python3', [
      '-c',
      r'''import errno, json, os, pty, select, subprocess, sys, termios, time
master, slave = pty.openpty()
process = subprocess.Popen(sys.argv[1:], stdin=slave, stdout=slave, stderr=slave)
transcript = b''
echo = None
deadline = time.monotonic() + 15
try:
    while process.poll() is None:
        if time.monotonic() > deadline:
            raise RuntimeError('the forge prompt did not finish')
        if not select.select([master], [], [], .1)[0]:
            continue
        transcript += os.read(master, 4096)
        if echo is None and b'Token for github.com: ' in transcript:
            echo = bool(termios.tcgetattr(slave)[3] & termios.ECHO)
            os.write(master, b'\n')
    print(json.dumps({'echo': echo, 'restored': bool(termios.tcgetattr(slave)[3] & termios.ECHO), 'exit': process.returncode}))
finally:
    if process.poll() is None:
        process.kill()
    process.wait()
    os.close(master)
    os.close(slave)
''',
      Platform.resolvedExecutable,
      'bin/porelo_host.dart',
      'key',
      'set',
      'github.com',
    ]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    final terminal = jsonDecode(result.stdout as String) as Map<String, dynamic>;
    expect(terminal['echo'], isFalse);
    expect(terminal['restored'], isTrue);
    expect(terminal['exit'], 64, reason: 'an empty terminal answer is refused without opening the store');
  }, skip: !Platform.isLinux ? 'Terminal echo requires Linux PTYs.' : false);

  // Harm: piped input can route a secret through an interface instead of its terminal.
  test('setting a forge token refuses redirected standard input before opening the store', () async {
    final process = await Process.start(Platform.resolvedExecutable, [
      'bin/porelo_host.dart',
      'key',
      'set',
      'github.com',
    ]);
    await process.stdin.close();
    final output = process.stdout.transform(const SystemEncoding().decoder).join();
    final errors = await process.stderr.transform(const SystemEncoding().decoder).join();
    expect(await process.exitCode, 64, reason: errors);
    expect(errors, contains('terminal'), reason: 'a prompt on a terminal is the only input channel');
    expect(await output, isEmpty);
  });

  // Harm: an argument value would expose a token through process listings.
  test('setting a forge token refuses an argument value without repeating it', () async {
    final result = await Process.run(Platform.resolvedExecutable, [
      'bin/porelo_host.dart',
      'key',
      'set',
      'github.com',
      'fixture-secret',
    ]);
    expect(result.exitCode, 64);
    expect('${result.stdout}${result.stderr}', isNot(contains('fixture-secret')));
  });
}
