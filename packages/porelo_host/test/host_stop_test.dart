// Linux: the stop's scripts run in bash in a pty driven by python3.
@Tags(<String>['linux'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:porelo_host/porelo_host.dart';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

const init = "'/usr/local/bin/porelo-host-stop' 'vault-new'";
const loginInit = "'/usr/local/bin/porelo-host-stop' '--email' 'me@example.org' 'drive' 'vault-new'";

void main() {
  // Harm: an unreviewed command or secret argument runs on the host instead of its requested setup steps.
  test('the stop script receives only known needs and a checked email as quoted arguments', () {
    final cases = <List<String>, String>{
      ['drive']: "'/usr/local/bin/porelo-host-stop' '--email' 'me+host@example.org' 'drive'",
      ['vault']: "'/usr/local/bin/porelo-host-stop' 'vault'",
      ['vault-new']: "'/usr/local/bin/porelo-host-stop' 'vault-new'",
      ['drive', 'vault']: "'/usr/local/bin/porelo-host-stop' '--email' 'me+host@example.org' 'drive' 'vault'",
      ['drive', 'vault-new']: "'/usr/local/bin/porelo-host-stop' '--email' 'me+host@example.org' 'drive' 'vault-new'",
    };
    for (final entry in cases.entries) {
      expect(
        hostStopCommand(entry.key, email: 'me+host@example.org'),
        entry.value,
        reason: 'the host script receives exactly the public arguments it requested',
      );
    }
    for (final needs in <List<String>>[
      [],
      ['unknown'],
      ['drive', 'vault', 'sentinel-secret'],
      ['vault; id'],
    ]) {
      expect(() => hostStopCommand(needs, email: 'me@example.org'), throwsFormatException);
    }
    expect(() => hostStopCommand(['drive'], email: 'sentinel-secret'), throwsFormatException);
    expect(
      hostStopCommand(['vault'], email: 'sentinel-secret'),
      "'/usr/local/bin/porelo-host-stop' 'vault'",
      reason: 'an email is never forwarded for a vault-only stop',
    );
  });
  final commands = <List<String>, String>{
    ['drive']: "'/usr/local/bin/porelo-host-stop' '--email' 'me@example.org' 'drive'",
    ['vault-new']: init,
    ['vault']: "'/usr/local/bin/porelo-host-stop' 'vault'",
    ['drive', 'vault-new']: loginInit,
    ['drive', 'vault']: "'/usr/local/bin/porelo-host-stop' '--email' 'me@example.org' 'drive' 'vault'",
  };
  // Harm: shell syntax in an e-mail executes an unintended command on the host.
  test('an unsafe or malformed e-mail cannot become a host command', () {
    for (final email in [
      "me'@example.org",
      r'me$(id)@example.org',
      'me;@example.org',
      'me @example.org',
      '-me@example.org',
      'me@example.org\n',
      '',
      'no-address',
      'me`id`@example.org',
      'me|id@example.org',
      'me&@example.org',
      'me\\@example.org',
    ]) {
      expect(isHostDriveEmail(email), isFalse, reason: email);
      expect(() => hostStopCommand(['drive'], email: email), throwsFormatException, reason: email);
    }
    expect(isHostDriveEmail('me+host@example.org'), isTrue);
  });
  // Harm: a secret reaches automation or a command runs beyond the steps the host requested.
  for (final entry in commands.entries) {
    test('the host command for ${entry.key} is exactly the requested prompts', () {
      expect(hostStopCommand(entry.key, email: 'me@example.org'), entry.value);
    });
  }

  final root = Directory('../..').absolute.path;
  late Directory scratch;
  late String ssh;
  late String host;
  setUpAll(() async {
    scratch = await Directory.systemTemp.createTemp('host-stop-');
    ssh = '${scratch.path}/ssh';
    host = '${scratch.path}/host';
    for (final entry in {'ssh_standin': ssh, 'host_standin': host}.entries) {
      final built = await Process.run(
        Platform.resolvedExecutable,
        ['compile', 'exe', '$root/tool/${entry.key}.dart', '-o', entry.value],
        environment: {'DASH__SUPPRESS_ANALYTICS': 'true'},
      );
      expect(built.exitCode, 0, reason: '${built.stdout}\n${built.stderr}');
    }
  });
  tearDownAll(() => scratch.delete(recursive: true));

  // Harm: the retired option reintroduces secrets into provisioning stdin.
  test('the CLI rejects answers-on-stdin even before a valued option', () async {
    for (final arguments in [
      ['up', '--answers-on-stdin'],
      ['up', '--answers-on-stdin', 'anything'],
      ['up', '--unknown', 'anything'],
    ]) {
      final result = await Process.run(
        Platform.resolvedExecutable,
        [
          'bin/porelo_host.dart',
          ...arguments,
          '--project',
          'demo',
          '--account',
          'person',
          '--public-key',
          '${scratch.path}/missing.pub',
          '--identity',
          'unused',
          '--collection',
          'unused',
          '--given',
          '192.0.2.10',
          '--host-key',
          'ssh-ed25519 AAAA',
        ],
        environment: {'DASH__SUPPRESS_ANALYTICS': 'true'},
      );
      expect(result.exitCode, Exit.usage, reason: '${result.stderr}');
      expect(result.stdout, isEmpty);
    }
    // Each CLI subprocess compiles from source, which can exceed the default timeout on CI.
  }, timeout: const Timeout(Duration(minutes: 2)));

  // Harm: the walk captures typed secrets in output, stderr or a file.
  for (final entry in commands.entries) {
    test('the ssh terminal for ${entry.key} prompts and discards every answer', () async {
      final folder = await Directory('${scratch.path}/case-${commands.keys.toList().indexOf(entry.key)}').create();
      final process = await Process.start(
        ssh,
        ['-i', '/walk/key', '-t', 'porelo@192.0.2.10', inTheLoginShell(entry.value)],
        workingDirectory: folder.path,
        environment: {'PORELO_WALK': folder.path},
      );
      final output = process.stdout.transform(utf8.decoder).join();
      final errors = process.stderr.transform(utf8.decoder).join();
      process.stdin.write('sentinel-password\nsentinel-code\nsentinel-passphrase\nsentinel-again\n');
      await process.stdin.close();
      expect(await process.exitCode.timeout(const Duration(seconds: 10)), 0);
      final words = await output;
      expect(await errors, isEmpty);
      expect(words, isNot(contains('sentinel-')));
      expect(await folder.list().toList(), isEmpty);
      final prompts = <String>[
        if (entry.key.contains('drive')) ...['Password: ', 'Enter your one-time password: '],
        if (entry.key.contains('vault-new')) ...[
          'New vault passphrase: ',
          'New vault passphrase again: ',
        ] else if (entry.key.contains('vault'))
          'Vault passphrase: ',
      ];
      var last = -1;
      for (final prompt in prompts) {
        final at = words.indexOf(prompt);
        expect(at, greaterThan(last), reason: '$prompt in $words');
        last = at;
      }
    });
  }

  // Harm: a password or vault passphrase is echoed before the stand-in hides terminal input.
  test('terminal echo hides passwords and passphrases but shows the one-time code', () async {
    final result = await Process.run('python3', [
      '-I',
      '-c',
      r''' 
import errno, json, os, pty, select, subprocess, sys, termios, time
master, slave = pty.openpty()
process = subprocess.Popen(sys.argv[1:], stdin=slave, stdout=slave, stderr=subprocess.PIPE)
transcript = b''
pending = b''
observed = []
prompts = [(b'Password: ', b'password-sentinel'),
           (b'Enter your one-time password: ', b'code-sentinel'),
           (b'New vault passphrase: ', b'passphrase-sentinel'),
           (b'New vault passphrase again: ', b'again-sentinel')]
deadline = time.monotonic() + 10
try:
    while prompts or process.poll() is None:
        if time.monotonic() > deadline:
            raise RuntimeError('the stand-in terminal did not finish its prompts')
        if not select.select([master], [], [], 0.1)[0]:
            continue
        try:
            chunk = os.read(master, 4096)
        except OSError as error:
            if error.errno == errno.EIO:
                break
            raise
        transcript += chunk
        pending += chunk
        if prompts and prompts[0][0] in pending:
            prompt, answer = prompts.pop(0)
            pending = pending.split(prompt, 1)[1]
            observed.append(bool(termios.tcgetattr(slave)[3] & termios.ECHO))
            os.write(master, answer + b'\n')
    print(json.dumps({'echo': observed, 'output': transcript.decode(),
                      'errors': process.stderr.read().decode(), 'exit': process.wait(timeout=2)}))
finally:
    if process.poll() is None:
        process.kill()
    process.wait()
    os.close(master)
    os.close(slave)
''',
      ssh,
      '-t',
      'porelo@192.0.2.10',
      inTheLoginShell(loginInit),
    ]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    final terminal = jsonDecode(result.stdout as String) as Map<String, dynamic>;
    expect(terminal['exit'], 0);
    expect(terminal['echo'], [false, true, false, false]);
    expect(terminal['errors'], isEmpty);
    expect(terminal['output'], contains('code-sentinel'));
    for (final secret in ['password-sentinel', 'passphrase-sentinel', 'again-sentinel']) {
      expect(terminal['output'], isNot(contains(secret)));
    }
  }, skip: !Platform.isLinux ? 'Terminal echo requires Linux PTYs.' : false);

  // Harm: the walk quietly accepts an arbitrary remote command instead of the host prompts.
  test('every other ssh terminal form is refused', () async {
    for (final arguments in [
      ['-t', 'porelo@host', 'bash'],
      ['-t', 'porelo@host', 'porelo vault init'],
      ['-t', 'porelo@host', inTheLoginShell('$init; touch unexpected')],
      ['-t', 'porelo@host', inTheLoginShell(init), 'extra'],
      ['-t', '-G', 'porelo@host', inTheLoginShell(init)],
      ['-t', 'porelo@host', inTheLoginShell(init), '-o', 'BatchMode=yes'],
    ]) {
      final result = await Process.run(ssh, arguments, workingDirectory: scratch.path);
      expect(result.exitCode, 255, reason: '$arguments');
      expect(result.stdout, isEmpty);
    }
  });

  // Harm: a missing destination or an answer channel prevents the walk from exercising host login.
  test('the host stand-in stops with the destination then goes on with plain up', () async {
    final state = File('${scratch.path}/host-standin.json');
    await state.writeAsString(jsonEncode({'situation': 'stop', 'state': 'new'}));
    final options = [
      'up',
      '--project',
      'demo',
      '--account',
      'person',
      '--public-key',
      'unused.pub',
      '--identity',
      'unused',
      '--collection',
      host,
      '--collection-sha256',
      sha256.convert(File(host).readAsBytesSync()).toString(),
      '--scaleway-project',
      'walk',
    ];
    final first = await Process.run(host, options, environment: {'PORELO_WALK': scratch.path});
    expect(first.exitCode, Exit.waiting);
    final stop = Step.fromLine(const LineSplitter().convert(first.stdout as String).last)!;
    expect(stop.address, '192.0.2.10');
    expect(stop.account, 'person');
    expect(stop.needs, ['drive', 'vault-new']);
    final second = await Process.run(host, options, environment: {'PORELO_WALK': scratch.path});
    expect(second.exitCode, Exit.done);
    expect(Step.fromLine(const LineSplitter().convert(second.stdout as String).last)!.step, 'up');
  });
}
