import 'dart:io';

import 'package:porelo_host/porelo_host.dart';
import 'package:test/test.dart';

import 'support/pinned_ssh.dart';

void main() {
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
