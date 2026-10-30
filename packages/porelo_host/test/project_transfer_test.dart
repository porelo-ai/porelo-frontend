// Linux: runs Bash terminal scripts with executable stand-ins for keepassxc-cli and ssh.
@Tags(['linux'])
library;

import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:porelo_host/porelo_host.dart';
import 'package:test/test.dart';

void main() {
  for (final code in [0, 65, 255]) {
    // Harm: the actual terminal feed sends the wrong token protocol or leaks an echoed token.
    test('terminal push and pull keep credentials off argv output and files for exit $code', () async {
      final fixture = await _Fixture.create();
      final before = {
        for (final entity in await fixture.folder.list().toList()) entity.path: await File(entity.path).readAsBytes(),
      };
      for (final direction in ProjectTransfer.values) {
        final result = await fixture.run(code: code, mode: 'echo', direction: direction);
        expect(result.exitCode, code, reason: '${result.stdout} ${result.stderr}');
        final text = '${result.stdout}${result.stderr}';
        final value = String.fromCharCodes([102, 105, 120, 116, 117, 114, 101]);
        expect(text.contains(value), isFalse, reason: 'the terminal must redact raw token echoes');
        expect(text.contains(base64.encode(utf8.encode(value))), isFalse, reason: 'the encoded line is also secret');
        expect(text, contains('host answer'));
        expect(text, contains(projectTransferSubmitted));
      }
      final after = {
        for (final entity in await fixture.folder.list().toList()) entity.path: await File(entity.path).readAsBytes(),
      };
      expect(after, before, reason: 'the command must create or change no local token files');
    });
  }

  for (final mode in ['locked', 'missing', 'empty', 'multiline', 'read-error']) {
    // Harm: local credential refusal still starts a host command, or discloses entry content.
    test('a $mode local entry refuses before host submission', () async {
      final fixture = await _Fixture.create();
      final result = await fixture.run(mode: mode);
      expect(result.exitCode, isNot(0));
      expect('${result.stdout}', isNot(contains(projectTransferSubmitted)));
      expect('${result.stderr}', isNotEmpty);
      final value = String.fromCharCodes([102, 105, 120, 116, 117, 114, 101]);
      expect('${result.stdout}${result.stderr}', isNot(contains(value)));
    });
  }

  // Harm: failed checks continue to SSH because a conditional shell suppresses errexit.
  test('an unexpected credential-check failure never submits or feeds SSH', () async {
    final fixture = await _Fixture.create();
    final result = await fixture.run(secrets: _FailedCheck(fixture.file, fixture.cli));
    expect(result.exitCode, isNot(0));
    expect(result.stdout, isNot(contains(projectTransferSubmitted)));
    expect(result.stdout, contains(projectTransferNotSubmitted));
  });

  // Harm: EOF after partial password input submits despite cancellation.
  test('EOF at an unterminated password prompt never submits', () async {
    final fixture = await _Fixture.create();
    final result = await fixture.run(newline: false);
    expect(result.exitCode, isNot(0));
    expect(result.stdout, isNot(contains(projectTransferSubmitted)));
    expect(result.stdout, contains('\n$projectTransferNotSubmitted\n'));
  });

  for (final action in ['phases', 'EOF', 'INT', 'TERM', 'HUP']) {
    // Harm: PTY echo discloses pasted input during unlock or SSH; signals leave echo disabled or submit early.
    test('the real PTY protects input and restores echo for $action', () async {
      final fixture = await _Fixture.create();
      final command = fixture.command();
      final child = await Process.start(
        '/usr/bin/python3',
        ['-c', _ptyHarness, action],
        environment: {'TRANSFER_MODE': action == 'phases' ? 'pty' : ''},
      );
      child.stdin.writeln(jsonEncode(command));
      await child.stdin.close();
      final out = child.stdout.transform(utf8.decoder).join();
      final err = child.stderr.transform(utf8.decoder).join();
      expect(await child.exitCode.timeout(const Duration(seconds: 10)), 0, reason: await err);
      final answer = jsonDecode(await out) as Map<String, dynamic>;
      expect(answer['echoChecks'], everyElement(false), reason: 'no input phase may echo');
      expect(answer['restored'], isTrue);
      if (action == 'phases') {
        expect(answer['phases'], containsAll(['prompt', 'unlock', 'ssh']));
        expect(answer['submitted'], isTrue);
        expect(answer['echoed'], isFalse);
      } else {
        expect(answer['submitted'], isFalse);
        expect(answer['notSubmitted'], isTrue);
      }
    });
  }

  // Harm: the interface reads the wrong token entry or sends the wrong stdin protocol.
  test('the terminal reads the root token and feeds the agreed encoded line', () async {
    final folder = await Directory.systemTemp.createTemp('central-transfer-');
    addTearDown(() => folder.delete(recursive: true));
    final file = File('${folder.path}/secrets.kdbx');
    await file.writeAsString('test fixture placeholder');
    final cli = File('${folder.path}/keepass');
    await cli.writeAsString(r'''#!/bin/bash
IFS= read -r master
case "$1" in
  ls) if [[ " $* " == *' -f '* ]]; then printf 'forge-central-token\n'; fi ;;
  show)
    [ "${@: -1}" = 'forge-central-token' ] || exit 1
    printf '\146\151\170\164\165\162\145\n'
    ;;
  *) exit 1 ;;
esac
''');
    final chmod = await Process.run('/bin/chmod', ['700', cli.path]);
    expect(chmod.exitCode, 0);
    final scripts = SecretsFile(file.path, cli: cli.path).projectTransferScripts();
    final child = await Process.start('/bin/bash', [
      '--noprofile',
      '--norc',
      '-c',
      '${scripts.check}\n${scripts.feed}',
    ]);
    final out = child.stdout.transform(utf8.decoder).join();
    final err = child.stderr.transform(utf8.decoder).join();
    child.stdin.writeln('fixture master');
    await child.stdin.close();
    final code = await child.exitCode;
    final diagnostic = await err;
    expect(code, 0, reason: 'the root entry must be used: $diagnostic');
    final value = String.fromCharCodes([102, 105, 120, 116, 117, 114, 101]);
    expect(await out, 'forge-central-token ${base64.encode(utf8.encode(value))}\n');
  });
}

const _publicKey = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

HostCardSsh _card() => HostCardSsh(
  name: 'alpha',
  address: 'alpha.example.org',
  sshPort: 22,
  hostKey: _publicKey,
  login: 'alice',
  publicKey: _publicKey,
  uid: 1001,
  returnSocket: '/run/porelo-host/people/alice/messenger.sock',
  webPort: 18080,
  gitPort: 18081,
  matrixPort: 18082,
);

class _Fixture {
  _Fixture(this.folder);
  final Directory folder;
  String get file => '${folder.path}/secrets.kdbx';
  String get cli => '${folder.path}/keepass';
  String get ssh => '${folder.path}/ssh';
  static Future<_Fixture> create() async {
    final fixture = _Fixture(await Directory.systemTemp.createTemp('transfer-feed-'));
    addTearDown(() => fixture.folder.delete(recursive: true));
    await File(fixture.file).writeAsString('encrypted file placeholder');
    await File(fixture.cli).writeAsString(r'''#!/usr/bin/python3
import os, sys
master = sys.stdin.readline()
mode = os.environ.get('TRANSFER_MODE', '')
if mode == 'locked': sys.exit(1)
if sys.argv[1] == 'ls':
    if mode == 'pty':
        tty = os.open('/dev/tty', os.O_RDWR)
        os.write(tty, b'unlocking\n'); os.read(tty, 1024); os.close(tty)
    if '-f' in sys.argv and mode != 'missing': print('forge-central-token')
    sys.exit(0)
if sys.argv[1] != 'show' or sys.argv[-1] != 'forge-central-token' or mode == 'read-error': sys.exit(1)
value = bytes([102,105,120,116,117,114,101]).decode()
if mode == 'multiline': value += '\nsecond'
if mode == 'empty': value = ''
print(value)
''');
    await File(fixture.ssh).writeAsString(r'''#!/usr/bin/python3
import base64, os, sys
value = bytes([102,105,120,116,117,114,101])
encoded = base64.b64encode(value)
if any(value in x.encode() or encoded in x.encode() for x in sys.argv + list(os.environ.values())): sys.exit(90)
required = ['BatchMode=yes', 'StrictHostKeyChecking=yes', 'ForwardAgent=no', 'ProxyCommand=false', 'ControlMaster=no',
    'UserKnownHostsFile="/config/porelo/ssh/alpha.conf.known_hosts"', 'GlobalKnownHostsFile=none',
    'KnownHostsCommand=none', 'VerifyHostKeyDNS=no', 'UpdateHostKeys=no', 'IdentitiesOnly=yes', 'ForwardX11=no']
if any(option not in sys.argv for option in required): sys.exit(91)
if ['-T', '--', 'alpha'] != sys.argv[-4:-1]: sys.exit(92)
if os.environ.get('TRANSFER_MODE') == 'pty':
    tty = os.open('/dev/tty', os.O_RDWR)
    os.write(tty, b'ssh phase\n'); os.read(tty, 1024); os.close(tty)
data = sys.stdin.buffer.read()
if data != b'forge-central-token ' + encoded + b'\n':
    print('invalid token protocol', file=sys.stderr)
    sys.exit(93)
if os.environ.get('TRANSFER_MODE') == 'echo':
    sys.stdout.buffer.write(value[:3]); sys.stdout.buffer.flush()
    sys.stdout.buffer.write(value[3:] + b'\r\n')
    sys.stderr.buffer.write(data)
print('host answer')
sys.exit(int(os.environ.get('TRANSFER_CODE', '0')))
''');
    final chmod = await Process.run('/bin/chmod', ['700', fixture.cli, fixture.ssh]);
    expect(chmod.exitCode, 0);
    return fixture;
  }

  List<String> command({ProjectTransfer direction = ProjectTransfer.push, SecretsFile? secrets}) =>
      projectTransferFeedCommand(
        direction: direction,
        project: 'example',
        repositories: ['api'],
        card: _card(),
        config: '/config/porelo/ssh/alpha.conf',
        secretsFile: secrets ?? SecretsFile(file, cli: cli),
        ssh: ssh,
        environment: {'XDG_CONFIG_HOME': '/config'},
      );
  Future<ProcessResult> run({
    String mode = '',
    int code = 0,
    ProjectTransfer direction = ProjectTransfer.push,
    SecretsFile? secrets,
    bool newline = true,
  }) async {
    final args = command(direction: direction, secrets: secrets);
    final child = await Process.start(
      args.first,
      args.skip(1).toList(),
      environment: {
        'TRANSFER_MODE': mode,
        'TRANSFER_CODE': '$code',
        'MASTER': 'inherited',
        'transfer_token': 'inherited',
        'transfer_encoded': 'inherited',
        'transfer_line': 'inherited',
      },
    );
    final output = child.stdout.transform(utf8.decoder).join();
    final errors = child.stderr.transform(utf8.decoder).join();
    child.stdin.write('fixture master${newline ? '\n' : ''}');
    await child.stdin.close();
    return ProcessResult(child.pid, await child.exitCode, await output, await errors);
  }
}

class _FailedCheck extends SecretsFile {
  _FailedCheck(super.file, String cli) : super(cli: cli);
  @override
  ({String check, String feed}) projectTransferScripts() =>
      (check: "false\ntransfer_encoded=ignored", feed: "printf '%s %s\\n' forge-central-token \"\$transfer_encoded\"");
}

const _ptyHarness = r'''import os, sys, json, pty, subprocess, termios, fcntl, signal, select, time
command = json.loads(sys.stdin.readline())
action = sys.argv[1]
master, slave = pty.openpty()
def controlling():
    os.setsid()
    fcntl.ioctl(0, termios.TIOCSCTTY, 0)
child = subprocess.Popen(command, stdin=slave, stdout=slave, stderr=slave, preexec_fn=controlling)
checks, phases, output = [], [], b''
limit = time.monotonic() + 7
try:
    while time.monotonic() < limit:
        if select.select([master], [], [], 0.02)[0]:
            data = os.read(master, 65536)
            output += data
            phase = 'prompt' if b'master password' in data else 'unlock' if b'unlocking' in data else 'ssh' if b'ssh phase' in data else None
            if phase:
                phases.append(phase)
                checks.append(bool(termios.tcgetattr(slave)[3] & termios.ECHO))
                if phase == 'prompt':
                    if action == 'EOF': os.write(master, b'\x04')
                    elif action != 'phases': os.killpg(child.pid, getattr(signal, 'SIG' + action))
                    else: os.write(master, b'fixture master\n')
                else: os.write(master, b'unexpected typed input\n')
        if child.poll() is not None:
            while select.select([master], [], [], 0)[0]: output += os.read(master, 65536)
            break
    else: raise RuntimeError('child did not settle')
    print(json.dumps({'echoChecks': checks, 'phases': phases,
        'restored': bool(termios.tcgetattr(slave)[3] & termios.ECHO),
        'submitted': b'__PORELO_CENTRAL_TRANSFER_SUBMITTED__' in output,
        'notSubmitted': b'\n__PORELO_CENTRAL_TRANSFER_NOT_SUBMITTED__' in output,
        'echoed': b'unexpected typed input' in output}))
finally:
    if child.poll() is None: os.killpg(child.pid, signal.SIGKILL); child.wait()
    os.close(master); os.close(slave)
''';
