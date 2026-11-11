// Linux: runs Bash terminal scripts with executable stand-ins for keepassxc-cli and ssh.
@Tags(['linux'])
library;

import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:porelo_host/porelo_host.dart';
import 'package:test/test.dart';

void main() {
  // Harm: a token goes to another account or verb than the one that waits for it, or stands on a command line.
  test('the central token reaches org refresh as root, on standard input only', () {
    final command = organizationRefreshFeedCommand(
      card: _card(),
      config: '/config/porelo/ssh/alpha.conf',
      token: SecretsFile('/home/alice/secrets.kdbx'),
      environment: {'XDG_CONFIG_HOME': '/config'},
    );
    final script = command.last;
    expect(script, contains('root@alpha'));
    expect(
      script,
      contains("'env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin LANG=C.UTF-8 /usr/sbin/porelo-host org refresh'"),
    );
    expect(script, contains(r'''{ printf '%s\n' "$transfer_token"; } |'''));
    expect(script, isNot(contains('__PORELO_CENTRAL')));
  });

  // Harm: a token kept on this computer reaches whoever answers there, or a command line.
  test('org refresh run directly pins the host, as root, and holds public values only', () {
    const config = '/config/porelo/ssh/alpha.conf';
    final arguments = organizationRefreshArguments(
      card: _card(),
      config: config,
      environment: {'XDG_CONFIG_HOME': '/config'},
    );
    final feeding = organizationRefreshFeedCommand(
      card: _card(),
      config: config,
      token: SecretsFile('/home/alice/secrets.kdbx'),
      environment: {'XDG_CONFIG_HOME': '/config'},
    ).last;
    expect(arguments.first, '/usr/bin/ssh');
    expect(arguments.sublist(1, 3), ['-F', config]);
    expect(arguments.sublist(arguments.length - 2), [
      'root@alpha',
      'env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin LANG=C.UTF-8 /usr/sbin/porelo-host org refresh',
    ]);
    // The same ssh as the way through a terminal, so neither pins less than the other.
    for (final each in arguments.skip(1).where((word) => word.contains('='))) {
      expect(feeding, contains(each));
    }
    expect(
      () => organizationRefreshArguments(card: _card(), config: '/elsewhere/alpha.conf'),
      throwsA(isA<HostFilesRefused>()),
    );
  });

  // Harm: the first token of a new host, which has made no account yet, needs a master nobody can raise, and never goes.
  test('the token to org refresh goes on its own connection, no master asked for', () {
    final script = organizationRefreshFeedCommand(
      card: _card(),
      config: '/config/porelo/ssh/alpha.conf',
      token: SecretsFile('/home/alice/secrets.kdbx'),
      environment: {'XDG_CONFIG_HOME': '/config'},
    ).last;
    expect(script, allOf(contains('ControlPath=none'), contains('ProxyCommand=none')));
    expect(script, isNot(contains('ProxyCommand=false')));
  });

  for (final code in [0, 65, 255]) {
    // Harm: the actual terminal feed sends the wrong token protocol or leaks an echoed token.
    test('the terminal feed keeps credentials off argv output and files for exit $code', () async {
      final fixture = await _Fixture.create();
      final before = {
        for (final entity in await fixture.folder.list().toList()) entity.path: await File(entity.path).readAsBytes(),
      };
      final result = await fixture.run(code: code, mode: 'echo');
      expect(result.exitCode, code, reason: '${result.stdout} ${result.stderr}');
      final text = '${result.stdout}${result.stderr}';
      final value = String.fromCharCodes([102, 105, 120, 116, 117, 114, 101]);
      expect(text.contains(value), isFalse, reason: 'the terminal must redact raw token echoes');
      expect(text.contains(base64.encode(utf8.encode(value))), isFalse, reason: 'the encoded line is also secret');
      expect(text, contains('host answer'));
      expect(text, contains(projectTransferSubmitted));
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

  // Harm: a missing keepassxc-cli is asked about as a wrong master password three times.
  test('a missing keepassxc-cli is said before any password is asked', () async {
    final fixture = await _Fixture.create();
    final result = await fixture.run(secrets: SecretsFile(fixture.file, cli: '${fixture.folder.path}/no-cli'));
    expect(result.exitCode, isNot(0));
    expect(result.stdout, isNot(contains(projectTransferSubmitted)));
    expect(result.stderr, contains('is not installed here'));
    expect(result.stderr, isNot(contains('master password')));
  });

  // Harm: EOF after partial password input submits despite cancellation.
  test('EOF at an unterminated password prompt never submits', () async {
    final fixture = await _Fixture.create();
    final result = await fixture.run(newline: false);
    expect(result.exitCode, isNot(0));
    expect(result.stdout, isNot(contains(projectTransferSubmitted)));
    expect(result.stdout, contains('\n$projectTransferNotSubmitted\n'));
  });

  // Harm: an encoding failure records submission and starts SSH with no usable token.
  test('a failed token encoder never submits or starts SSH', () async {
    final fixture = await _Fixture.create();
    final result = await fixture.run(secrets: _FailedEncoding(fixture.file, fixture.cli));
    expect(result.exitCode, isNot(0));
    expect(result.stdout, isNot(contains(projectTransferSubmitted)));
    expect(result.stdout, contains(projectTransferNotSubmitted));
    expect(result.stdout, isNot(contains('ssh started')));
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
      expect(await child.exitCode.timeout(const Duration(seconds: 40)), 0, reason: await err);
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
      // A runner of 4 CPUs among the other tests took over 7 s for a child to settle.
    }, timeout: const Timeout(Duration(minutes: 1)));
  }

  // Harm: org refresh takes the bare token line; anything else pushes with a token the forge refuses.
  test('the terminal reads the root token and feeds it as one bare line', () async {
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
    expect(await out, '$value\n');
  });

  // Harm: a token given by the environment is passed on to ssh, and to whatever it starts, or stands on its command line.
  test('a token from the environment reaches the host on standard input alone, with nothing asked', () async {
    final fixture = await _Fixture.create();
    final result = await fixture.run(
      secrets: EnvironmentCentralToken('CENTRAL_FIXTURE'),
      environment: {
        'CENTRAL_FIXTURE': String.fromCharCodes([102, 105, 120, 116, 117, 114, 101]),
      },
      newline: false,
      typed: '',
    );
    expect(result.exitCode, 0, reason: '${result.stdout} ${result.stderr}');
    expect(result.stderr, isNot(contains('master password')));
    expect(result.stdout, contains('host answer'));
  });

  // Harm: ssh starts and the host waits on a token that never comes, with no word why.
  for (final (what, value) in [('empty', ''), ('of two lines', 'one\ntwo')]) {
    test('a token from the environment that is $what stops before ssh', () async {
      final fixture = await _Fixture.create();
      final result = await fixture.run(
        secrets: EnvironmentCentralToken('CENTRAL_FIXTURE'),
        environment: {'CENTRAL_FIXTURE': value},
        newline: false,
        typed: '',
      );
      expect(result.exitCode, isNot(0));
      expect(result.stdout, isNot(contains('ssh started')));
      expect(result.stderr, contains('nothing was sent'));
    });
  }

  // Harm: a variable name that is shell text runs as code in the terminal.
  test('a variable that is no plain name is refused', () {
    expect(() => EnvironmentCentralToken(r'X;touch $HOME/y'), throwsFormatException);
  });

  // Harm: the person read the interface's own markers in the terminal.
  test('a terminal of its own shows the host lines without markers', () async {
    final fixture = await _Fixture.create();
    final submitted = await fixture.run(marked: false);
    expect(submitted.exitCode, 0, reason: '${submitted.stdout} ${submitted.stderr}');
    expect(submitted.stdout, contains('host answer'));
    expect('${submitted.stdout}', isNot(contains('__PORELO_')));
    final refused = await fixture.run(marked: false, mode: 'missing');
    expect(refused.exitCode, isNot(0));
    expect('${refused.stdout}${refused.stderr}', isNot(contains('__PORELO_')));
    expect(refused.stderr, contains('nothing was sent'));
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
print('ssh started', flush=True)
value = bytes([102,105,120,116,117,114,101])
encoded = base64.b64encode(value)
if any(value in x.encode() or encoded in x.encode() for x in sys.argv + list(os.environ.values())): sys.exit(90)
required = ['BatchMode=yes', 'StrictHostKeyChecking=yes', 'ForwardAgent=no', 'ProxyCommand=none', 'ControlPath=none',
    'ControlMaster=no',
    'UserKnownHostsFile="/config/porelo/ssh/alpha.conf.known_hosts"', 'GlobalKnownHostsFile=none',
    'KnownHostsCommand=none', 'VerifyHostKeyDNS=no', 'UpdateHostKeys=no', 'IdentitiesOnly=yes', 'ForwardX11=no']
if any(option not in sys.argv for option in required): sys.exit(91)
if ['-T', '--', 'root@alpha', 'env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin LANG=C.UTF-8 /usr/sbin/porelo-host org refresh'] != sys.argv[-4:]: sys.exit(92)
if os.environ.get('TRANSFER_MODE') == 'pty':
    tty = os.open('/dev/tty', os.O_RDWR)
    os.write(tty, b'ssh phase\n'); os.read(tty, 1024); os.close(tty)
data = sys.stdin.buffer.read()
if data != value + b'\n':
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

  List<String> command({CentralToken? secrets, bool marked = true}) => organizationRefreshFeedCommand(
    marked: marked,
    card: _card(),
    config: '/config/porelo/ssh/alpha.conf',
    token: secrets ?? SecretsFile(file, cli: cli),
    ssh: ssh,
    environment: {'XDG_CONFIG_HOME': '/config'},
  );
  Future<ProcessResult> run({
    String mode = '',
    int code = 0,
    CentralToken? secrets,
    Map<String, String> environment = const {},
    bool newline = true,
    bool marked = true,
    String typed = 'fixture master',
  }) async {
    final args = command(secrets: secrets, marked: marked);
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
        ...environment,
      },
    );
    final output = child.stdout.transform(utf8.decoder).join();
    final errors = child.stderr.transform(utf8.decoder).join();
    // A script that refuses at once has ended before the typed line arrives; the pipe it left is not the test's finding.
    try {
      child.stdin.write('$typed${newline ? '\n' : ''}');
      await child.stdin.close();
    } on SocketException {
      // Its exit code and words are what the test reads.
    }
    return ProcessResult(child.pid, await child.exitCode, await output, await errors);
  }
}

class _FailedCheck extends SecretsFile {
  _FailedCheck(super.file, String cli) : super(cli: cli);
  @override
  ({String check, String feed}) projectTransferScripts() =>
      (check: "false\ntransfer_encoded=ignored", feed: "printf '%s %s\\n' forge-central-token \"\$transfer_encoded\"");
}

class _FailedEncoding extends SecretsFile {
  _FailedEncoding(super.file, String cli) : super(cli: cli);

  @override
  ({String check, String feed}) projectTransferScripts() {
    final scripts = super.projectTransferScripts();
    return (check: scripts.check.replaceAll('/usr/bin/base64 -w0', '/bin/false'), feed: scripts.feed);
  }
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
limit = time.monotonic() + 30
again = None
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
                    elif action != 'phases':
                        os.killpg(child.pid, getattr(signal, 'SIG' + action))
                        again = time.monotonic() + 1
                    else: os.write(master, b'fixture master\n')
                else: os.write(master, b'unexpected typed input\n')
        # A signal between bash printing the prompt and reading waits until the read ends, so it comes again, as from a person.
        if again and time.monotonic() > again and child.poll() is None:
            os.killpg(child.pid, getattr(signal, 'SIG' + action))
            again = time.monotonic() + 1
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
