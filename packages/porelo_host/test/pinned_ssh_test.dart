import 'dart:io';

import 'package:porelo_host/porelo_host.dart';
import 'package:test/test.dart';

import 'support/pinned_ssh.dart';

void main() {
  // Harm: preparation could use a disk key, forward the agent, or corrupt the collection in transit.
  test('given preparation uses the pinned agent-only SSH policy and streams binary bytes', () async {
    final directory = await Directory.systemTemp.createTemp('agent-ssh-');
    addTearDown(() => directory.delete(recursive: true));
    final source = File('${directory.path}/collection.tar.gz');
    final received = File('${directory.path}/received');
    await source.writeAsBytes([0, 128, 255, 10]);
    final receiver = File('${directory.path}/receive.dart');
    await receiver.writeAsString(
      "import 'dart:io'; Future<void> main(List<String> args) async {"
      "final bytes = await stdin.expand((chunk) => chunk).toList();"
      "await File(args.single).writeAsBytes(bytes); }",
    );
    final commands = <List<String>>[];
    final remote = OpenSsh(
      knownHosts: File('${directory.path}/known_hosts'),
      identity: '',
      agentOnly: true,
      start: (program, args) {
        commands.add([program, ...args]);
        return Process.start(Platform.resolvedExecutable, [receiver.path, received.path]);
      },
    );
    await remote.run('192.0.2.7', 'root', 'true');
    expect((await remote.copy('192.0.2.7', 'root', source.path, '/var/tmp/porelo-host/collection.tar.gz')).exitCode, 0);
    expect(await received.readAsBytes(), await source.readAsBytes());
    expect(commands.map((c) => c.last), ['true', 'cat > /var/tmp/porelo-host/collection.tar.gz']);
    for (final command in commands) {
      expect(command.first, 'ssh');
      expect(
        command,
        containsAllInOrder(['-F', '/dev/null', '-o', 'IdentityFile=none', '-o', 'PreferredAuthentications=publickey']),
      );
      expect(
        command,
        containsAll(['BatchMode=yes', 'ForwardAgent=no', 'StrictHostKeyChecking=yes', 'GlobalKnownHostsFile=none']),
      );
      expect(command, isNot(contains('-i')));
      expect(command, contains('root@192.0.2.7'));
    }
  });

  // Harm: an early SSH refusal must retain its cause instead of escaping as a broken pipe.
  test('copy returns the remote refusal when SSH closes input early', () async {
    final directory = await Directory.systemTemp.createTemp('copy-refusal-');
    addTearDown(() => directory.delete(recursive: true));
    final source = File('${directory.path}/collection');
    await source.writeAsBytes([0, 128, 255, 10]);
    final remote = OpenSsh(
      knownHosts: File('${directory.path}/known_hosts'),
      identity: '',
      agentOnly: true,
      start: (_, _) async => _RefusedCopyProcess(),
    );
    final result = await remote.copy('192.0.2.7', 'root', source.path, '/destination');
    expect(result.exitCode, 65);
    expect(result.stderr, 'Remote copy refused.\n');
  });

  // Harm: teardown must not trust ambient keys or run against another account and billed host.
  test('card teardown pins the provider key and keeps the requested endpoint for ssh and scp', () async {
    final commands = <List<String>>[];
    final directory = await Directory.systemTemp.createTemp('card-teardown-');
    addTearDown(() => directory.delete(recursive: true));
    final config = File('${directory.path}/orchard.conf');
    await config.writeAsString(
      'Host orchard\n  HostName 198.51.100.9\n  User worker\n  Port 2222\n'
      '  IdentityFile /public/person.pub\n',
    );
    final remote = OpenSsh(
      knownHosts: File('/state/known_hosts'),
      identity: '',
      config: config.path,
      configHost: 'orchard',
      start: (program, arguments) {
        commands.add([program, ...arguments]);
        return Process.start(Platform.resolvedExecutable, ['--version']);
      },
      run: (program, arguments) async {
        commands.add([program, ...arguments]);
        return ProcessResult(0, 0, '', '');
      },
    );
    await remote.run('192.0.2.7', 'root', 'true');
    await remote.copy('192.0.2.7', 'root', '/public/file', '/destination');
    for (final command in commands) {
      for (final option in [
        'StrictHostKeyChecking=yes',
        'UserKnownHostsFile="/state/known_hosts"',
        'GlobalKnownHostsFile=none',
        'KnownHostsCommand=none',
        'BatchMode=yes',
        'ForwardAgent=no',
        'ControlMaster=no',
        'ControlPath=none',
      ]) {
        expect(command, contains(option), reason: 'teardown must use the provider pin despite the card config');
      }
      expect(command, containsAllInOrder(['-F', config.path]));
      expect(command, isNot(contains('')));
      expect(command, isNot(contains('-i')));
      expect(
        command,
        containsAllInOrder(['-o', 'HostName=192.0.2.7', '-o', 'User=root']),
        reason: 'config identity selection cannot replace the provider address or teardown login',
      );
    }
    for (final command in commands) {
      final options = command.first == 'ssh'
          ? command.sublist(1, command.length - 2)
          : command.sublist(1, command.indexOf('-q'));
      final effective = await Process.run('ssh', ['-G', ...options, 'orchard']);
      expect(effective.exitCode, 0, reason: '${effective.stderr}');
      final values = effective.stdout.toString().split('\n');
      expect(
        values,
        containsAll(['hostname 192.0.2.7', 'user root', 'port 22', 'identityfile /public/person.pub']),
        reason: 'both transports must reach the provider endpoint with the selected identity',
      );
    }
    expect(commands.first, contains('orchard'));
    expect(commands.last.last, 'orchard:/destination');
  });

  // Harm: wrong host config paths connect to a different host or bypass its selected agent identity.
  test('host configs use the platform config directory and reject unsafe names', () {
    expect(
      poreloHostSshConfig('orchard', environment: {'XDG_CONFIG_HOME': '/config'}, windows: false),
      '/config/porelo/ssh/orchard.conf',
    );
    expect(
      poreloHostSshConfig(
        'orchard',
        environment: {'XDG_CONFIG_HOME': 'relative', 'HOME': '/home/person'},
        windows: false,
      ),
      '/home/person/.config/porelo/ssh/orchard.conf',
    );
    expect(
      poreloHostSshConfig('orchard', environment: {'APPDATA': r'C:\Users\person\AppData\Roaming'}, windows: true),
      r'C:\Users\person\AppData\Roaming\porelo\ssh\orchard.conf',
    );
    for (final host in ['../other', '-option', 'Uppercase', 'a/b']) {
      expect(() => poreloHostSshConfig(host, environment: {'XDG_CONFIG_HOME': '/config'}), throwsFormatException);
    }
  });

  // Harm: teardown with an empty identity cannot authenticate to release a billed host.
  test('agent authentication never receives an empty identity override', () async {
    final commands = <List<String>>[];
    final remote = OpenSsh(
      knownHosts: File('/state/known_hosts'),
      identity: '',
      run: (program, arguments) async {
        commands.add([program, ...arguments]);
        return ProcessResult(0, 0, '', '');
      },
    );
    await remote.copy('192.0.2.7', 'root', '/public/file', '/destination');
    expect(commands.single, isNot(contains('')));
    expect(commands.single, isNot(contains('-i')));
    expect(
      commands.single,
      isNot(contains('IdentitiesOnly=yes')),
      reason: 'agent keys remain available when no identity is selected',
    );
    expect(commands.single, contains('StrictHostKeyChecking=yes'));
  });

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

class _RefusedCopyProcess implements Process {
  @override
  final IOSink stdin = _BrokenInput();
  @override
  Stream<List<int>> get stdout => const Stream.empty();
  @override
  Stream<List<int>> get stderr => Stream.value('Remote copy refused.\n'.codeUnits);
  @override
  Future<int> get exitCode async => 65;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _BrokenInput implements IOSink {
  @override
  Future<void> addStream(Stream<List<int>> stream) async => throw const SocketException('Broken pipe');
  @override
  Future<void> close() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
