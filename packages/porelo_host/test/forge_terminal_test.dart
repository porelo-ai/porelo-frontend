import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

// The desktop command is pure Dart and is exercised here without a Flutter engine.
// ignore: avoid_relative_lib_imports
import '../../../lib/src/app/host_stop_feed.dart';

void main() {
  // A late reader or an early SSH exit must not leave typed credentials visible.
  test('forge feed disables echo before SSH and restores it after early exit', () async {
    final scratch = await Directory.systemTemp.createTemp('forge-terminal-');
    addTearDown(() => scratch.delete(recursive: true));
    final ssh = File('${scratch.path}/ssh');
    await ssh.writeAsString(r'''#!/usr/bin/python3 -I
import json, os, termios
fd = os.open('/dev/tty', os.O_RDWR)
echo = bool(termios.tcgetattr(fd)[3] & termios.ECHO)
with open(os.environ['OBSERVED'], 'w') as out:
    json.dump(echo, out)
''');
    final stty = File('${scratch.path}/stty');
    await stty.writeAsString(r'''#!/bin/bash
if [ "$PPID" != "$FEED_PARENT" ] && [ "$1" = -echo ]; then
  while [ ! -f "$OBSERVED" ]; do /usr/bin/sleep 0.01; done
fi
exec /usr/bin/stty "$@"
''');
    for (final file in [ssh, stty]) {
      expect((await Process.run('/usr/bin/chmod', ['700', file.path])).exitCode, 0);
    }
    final database = File('${scratch.path}/secrets.kdbx');
    await database.writeAsString('stand-in encrypted database');
    final cli = File('${scratch.path}/keepassxc-cli');
    await cli.writeAsString(r'''#!/usr/bin/python3 -I
import sys
sys.stdin.readline()
if sys.argv[1] == 'show':
    print('fixture-forge-password')
''');
    expect((await Process.run('/usr/bin/chmod', ['700', cli.path])).exitCode, 0);
    final command = hostForgePasswordFeedCommand(
      secretsFile: database.path,
      cli: cli.path,
      ssh: ssh.path,
      sshOptions: const [],
      host: 'person@203.0.113.7',
    );
    command[command.length - 1] = 'export FEED_PARENT=\$\$\n${command.last.replaceAll('/usr/bin/stty', stty.path)}';
    final process = await Process.start(
      '/usr/bin/python3',
      [
        '-I',
        '-c',
        r'''
import fcntl, json, os, pty, subprocess, sys, termios, time
command = json.load(sys.stdin)
master, slave = pty.openpty()
mode = termios.tcgetattr(slave)
mode[3] |= termios.ECHO
termios.tcsetattr(slave, termios.TCSANOW, mode)
def terminal():
    os.setsid()
    fcntl.ioctl(0, termios.TIOCSCTTY, 0)
child = subprocess.Popen(command, stdin=slave, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, preexec_fn=terminal)
deadline = time.monotonic() + 10
try:
    while not os.path.exists(os.environ['OBSERVED']) or termios.tcgetattr(slave)[3] & termios.ECHO:
        if time.monotonic() > deadline:
            raise RuntimeError('the hidden password reader did not start')
        time.sleep(0.01)
    os.write(master, b'fixture-master\n')
    child.wait(timeout=10)
finally:
    if child.poll() is None:
        child.kill()
        child.wait()
with open(os.environ['OBSERVED']) as source:
    before = json.load(source)
print(json.dumps({'echo_at_ssh': before, 'echo_after': bool(termios.tcgetattr(slave)[3] & termios.ECHO)}))
os.close(slave)
os.close(master)
''',
      ],
      environment: {'OBSERVED': '${scratch.path}/observed'},
    );
    process.stdin.write(jsonEncode(command));
    await process.stdin.close();
    final output = process.stdout.transform(utf8.decoder).join();
    final errors = process.stderr.transform(utf8.decoder).join();
    expect(await process.exitCode, 0, reason: await errors);
    final observed = jsonDecode(await output) as Map;
    expect(observed['echo_at_ssh'], isFalse, reason: 'the parent must hide input before forking SSH');
    expect(observed['echo_after'], isTrue, reason: 'the parent restores echo even if the reader loses its pipe');
  });
}
