import 'dart:async';
import 'dart:io';

import 'package:porelo_host/porelo_host.dart';
import 'package:test/test.dart';

import 'support/pinned_ssh.dart';

void main() {
  // Harm: a compromised host uses a forwarded agent or reaches the person's display.
  test('the pinned policy disables agent and display forwarding from SSH config', () async {
    final directory = await Directory.systemTemp.createTemp('ssh-forwarding-');
    addTearDown(() => directory.delete(recursive: true));
    final config = File('${directory.path}/config');
    await config.writeAsString('Host *\n    ForwardAgent yes\n    ForwardX11 yes\n');
    final ProcessResult result;
    try {
      result = await Process.run('ssh', <String>[
        '-G',
        '-F',
        config.path,
        ...pinnedHostSshOptions('${directory.path}/known_hosts', '${directory.path}/identity'),
        'someone@192.0.2.10',
      ]);
    } on ProcessException catch (error) {
      if (error.errorCode != 2) rethrow;
      markTestSkipped('No ssh binary is available to inspect its effective forwarding configuration.');
      return;
    }
    expect(result.exitCode, 0, reason: 'ssh -G must print effective settings: ${result.stderr}');
    final forwarding = <String, String>{};
    for (final line in (result.stdout as String).split('\n')) {
      final fields = line.trim().split(RegExp(r'\s+'));
      if (fields.length == 2 && const {'forwardagent', 'forwardx11'}.contains(fields.first)) {
        forwarding[fields.first] = fields.last;
      }
    }
    expect(forwarding, <String, String>{
      'forwardagent': 'no',
      'forwardx11': 'no',
    }, reason: 'host access must disable both forwarding channels despite permissive SSH config');
  });

  // Prevents trusting the person's keys through a shared but incorrect path helper.
  test('the trust file lives in the host command state directory on each platform', () {
    expect(
      poreloHostKnownHosts(
        environment: const <String, String>{'XDG_STATE_HOME': '/state', 'HOME': '/home/person'},
        windows: false,
      ),
      '/state/porelo-host/known_hosts',
    );
    expect(
      poreloHostKnownHosts(environment: const <String, String>{'HOME': '/home/person'}, windows: false),
      '/home/person/.local/state/porelo-host/known_hosts',
    );
    expect(
      poreloHostKnownHosts(
        environment: const <String, String>{'XDG_STATE_HOME': '', 'HOME': '/home/person'},
        windows: false,
      ),
      '/home/person/.local/state/porelo-host/known_hosts',
    );
    expect(
      poreloHostKnownHosts(
        environment: const <String, String>{'LOCALAPPDATA': r'C:\Users\person\AppData\Local'},
        windows: true,
      ),
      r'C:\Users\person\AppData\Local\porelo-host\known_hosts',
    );
  });

  // Prevents OpenSSH splitting the pinned trust path into several files in a profile with spaces.
  // Red: remove the config-syntax quotes from UserKnownHostsFile.
  test('a pinned trust path with spaces is one quoted OpenSSH config value', () {
    expect(pinnedHostSshOptions('C:/Users/A Person/host keys', '/keys/identity'), <String>[
      '-o',
      'StrictHostKeyChecking=yes',
      '-o',
      'UserKnownHostsFile="C:/Users/A Person/host keys"',
      '-o',
      'GlobalKnownHostsFile=none',
      '-o',
      'KnownHostsCommand=none',
      '-o',
      'VerifyHostKeyDNS=no',
      '-o',
      'UpdateHostKeys=no',
      '-o',
      'BatchMode=yes',
      '-o',
      'ForwardAgent=no',
      '-o',
      'ForwardX11=no',
      '-o',
      'IdentitiesOnly=yes',
      '-o',
      'ControlMaster=no',
      '-o',
      'ControlPath=none',
      '-i',
      '/keys/identity',
    ]);
  });

  // Prevents an earlier permissive option, config command, DNS or system keys overriding the pin.
  test('ssh and scp begin with the exact pinned trust policy without later trust options', () async {
    final commands = <List<String>>[];
    final ssh = OpenSsh(
      knownHosts: File('/trust/host_keys'),
      identity: '/keys/host identity',
      start: (executable, arguments) {
        commands.add(<String>[executable, ...arguments]);
        return Process.start(Platform.resolvedExecutable, <String>['--version']);
      },
      run: (executable, arguments) async {
        commands.add(<String>[executable, ...arguments]);
        return ProcessResult(0, 0, '', '');
      },
    );
    await ssh.run('host', 'account', 'true');
    await ssh.copy('host', 'account', '/from', '/to');
    expect(commands.map((c) => c.first), <String>['ssh', 'scp']);
    for (final command in commands) {
      expect(pinnedCommandProblems(command), isEmpty);
    }
  });

  // Harm: trimming the transport's stderr rewrites a host helper's refusal.
  test('a host refusal retains its complete stderr through SSH transport', () async {
    final ssh = OpenSsh(
      knownHosts: File('/trust/host_keys'),
      identity: '/keys/rental',
      start: (_, _) =>
          Process.start('/bin/sh', ['-c', "printf 'porelo-host-person: account is locked.\\n' >&2; exit 65"]),
    );
    final answer = await ssh.run('203.0.113.7', 'root', '/usr/local/sbin/porelo-host-person lock alice');
    expect(answer.exitCode, 65);
    expect(answer.stderr, 'porelo-host-person: account is locked.\n');
    // Linux: the stand-in for ssh is /bin/sh.
  }, tags: 'linux');

  // Harm: an echoed stdin credential escapes through callbacks or refusal diagnostics.
  test('stdin credentials never escape through echoed output or diagnostics', () async {
    final output = <String>[];
    final credential = String.fromCharCodes([115, 121, 110, 116, 104, 101, 116, 105, 99, 45, 111, 110, 108, 121]);
    final ssh = OpenSsh(
      knownHosts: File('/trust/host_keys'),
      identity: '/keys/person',
      start: (executable, arguments) {
        expect([executable, ...arguments].join(' '), isNot(contains(credential)));
        expect(Platform.environment.values, isNot(contains(credential)));
        return Process.start('/bin/sh', ['-c', 'cat >&2; printf "public answer\\n"; exit 65']);
      },
    );
    final answer = await ssh.run(
      'host',
      'person',
      'porelo-host-push example',
      input: '$credential\n',
      onLine: output.add,
    );
    expect(answer.exitCode, 65);
    expect(answer.stderr.contains(credential), isFalse, reason: 'refusal diagnostics must redact stdin');
    expect(output, ['public answer']);
  }, tags: 'linux'); // Linux: /bin/sh stands in for the SSH process.

  for (final code in [0, 65, 255]) {
    // Harm: a successful, refused or disconnected host echoes the vault token into public output.
    test('vault delivery stays on stdin for host exit $code including chunked echoes', () async {
      final folder = await Directory.systemTemp.createTemp('transfer-');
      addTearDown(() => folder.delete(recursive: true));
      final vault = _SyntheticVault();
      final output = <String>[];
      final ssh = OpenSsh(
        knownHosts: File('${folder.path}/known_hosts'),
        identity: '${folder.path}/identity',
        start: (executable, arguments) {
          expect(executable, 'ssh');
          expect(arguments.last, 'porelo-host-push --pull example api');
          expect(arguments.join(' ').contains(vault.value), isFalse);
          expect(Platform.environment.values.any((value) => value.contains(vault.value)), isFalse);
          // The stand-in sees only stdin, and deliberately echoes it on both channels.
          return Process.start('/bin/sh', [
            '-c',
            'IFS= read -r value; printf "%s" "\$value"; printf "\\n"; printf "%s" "\$value" >&2; exit $code',
          ]);
        },
      );
      final answer = await vault.deliver(
        (value) => ssh.run('alpha', '', 'porelo-host-push --pull example api', input: '$value\n', onLine: output.add),
      );
      expect(vault.reads, 1);
      expect(answer.exitCode, code);
      expect(output, ['[redacted]']);
      expect(answer.stderr, '[redacted]');
      expect(await folder.list().toList(), isEmpty, reason: 'delivery creates no credential or reply file');
    }, tags: 'linux'); // Linux: /bin/sh is the stand-in SSH command.
  }

  // Harm: process launch diagnostics can expose a credential and a hung write can be replayed.
  test('credential-bearing launch errors are public uncertainty without exception text', () async {
    final vault = _SyntheticVault();
    final ssh = OpenSsh(
      knownHosts: File('/trust/keys'),
      identity: '/keys/person',
      start: (_, _) async => throw ProcessException('ssh', [], vault.value),
    );
    final answer = await vault.deliver((value) => ssh.run('alpha', '', 'porelo-host-push example', input: '$value\n'));
    expect(answer.exitCode, 255);
    expect(answer.stderr.contains(vault.value), isFalse);
  });

  // Harm: a hung owned process keeps a transfer running indefinitely.
  test('a command deadline kills only its owned process and reports uncertainty', () async {
    final child = _WaitingProcess();
    final ssh = OpenSsh(
      knownHosts: File('/trust/keys'),
      identity: '/keys/person',
      start: (_, _) async => child,
      deadline: Duration.zero,
    );
    final answer = await ssh.run('alpha', '', 'porelo-host-push example', input: 'synthetic\n');
    expect(child.killed, isTrue);
    expect(answer.exitCode, 255);
    expect(answer.stderr, contains('unconfirmed'));
  });

  // Harm: a transfer switches accounts or falls back to a new connection outside its owned tunnel.
  test('shared-host transfers use only the imported config and captured admitted alias', () async {
    const key = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
    final card = HostCardSsh(
      name: 'alpha',
      address: 'alpha.example.org',
      sshPort: 2222,
      hostKey: key,
      login: 'alice',
      publicKey: key,
      uid: 1001,
      returnSocket: '/run/porelo-host/people/alice/messenger.sock',
      webPort: 18080,
      gitPort: 18081,
      matrixPort: 18082,
    );
    final commands = <List<String>>[];
    final ssh = OpenSsh.sharedHost(
      card: card,
      config: '/config/porelo/ssh/alpha.conf',
      environment: {'XDG_CONFIG_HOME': '/config'},
      start: (executable, arguments) {
        commands.add([executable, ...arguments]);
        return Process.start('/bin/sh', ['-c', 'cat >/dev/null; printf "approved main pushed\\n"']);
      },
    );
    await expectLater(ssh.run('other', '', 'true'), throwsFormatException);
    await expectLater(ssh.run('alpha', 'root', 'true'), throwsFormatException);
    expect(commands, isEmpty);
    final answer = await ssh.run(
      'alpha',
      '',
      projectTransferCommand(ProjectTransfer.push, 'example', ['api']),
      input: 'synthetic\n',
    );
    expect(answer.exitCode, 0);
    expect(commands.single, [
      'ssh',
      '-F',
      '/config/porelo/ssh/alpha.conf',
      '-o',
      'ControlMaster=no',
      '-o',
      'ProxyCommand=false',
      '-o',
      'ConnectTimeout=10',
      '-T',
      '--',
      'alpha',
      'exec "\${SHELL:-/bin/sh}" -lc \'porelo-host-push example api\'',
    ]);
  }, tags: 'linux'); // Linux: /bin/sh stands in for the shared-master SSH command.

  // Prevents an unsupported need from advertising a sign-in outside task start.
  // Red: print the per-agent ssh command again.
  test('an unknown agent need prints no sign-in command', () {
    final output = StringBuffer();
    final errors = StringBuffer();
    writeHostStep(
      const Step('person', StepState.waiting, needs: <String>['agent-login:pi']),
      output: output,
      errors: errors,
    );
    expect(errors.toString(), isNot(contains('ssh')));
    expect(Step.fromLine(output.toString().trim())!.needs, <String>['agent-login:pi']);
  });
}

class _SyntheticVault {
  int reads = 0;
  String get value => String.fromCharCodes([115, 121, 110, 116, 104, 101, 116, 105, 99, 45, 111, 110, 108, 121]);
  Future<T> deliver<T>(Future<T> Function(String) use) {
    reads++;
    return use(value);
  }
}

class _WaitingProcess implements Process {
  _WaitingProcess() {
    final input = StreamController<List<int>>();
    input.stream.listen((_) {});
    _stdin = IOSink(input.sink);
  }
  late final IOSink _stdin;
  final _out = StreamController<List<int>>();
  final _err = StreamController<List<int>>();
  final _exit = Completer<int>();
  bool killed = false;
  @override
  IOSink get stdin => _stdin;
  @override
  Stream<List<int>> get stdout => _out.stream;
  @override
  Stream<List<int>> get stderr => _err.stream;
  @override
  Future<int> get exitCode => _exit.future;
  @override
  int get pid => 1;
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    _out.close();
    _err.close();
    _exit.complete(137);
    return true;
  }
}
