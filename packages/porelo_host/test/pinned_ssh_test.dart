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
