import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/connections.dart';
import 'package:porelo_frontend/src/app/desk.dart';
import 'package:porelo_frontend/src/app/host_keys.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/pty.dart';
import 'package:porelo_frontend/src/app/session.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/app/tunnel.dart';
import 'package:porelo_frontend/src/ui/machine_switcher.dart';

void main() {
  const machine = Machine(
    name: 'box',
    socketPath: '',
    host: 'user@box',
    remoteSocket: '/run/user/1000/porelo/porelod.sock',
  );
  const option = Machine(name: 'bad', socketPath: '', host: '-oProxyCommand=wrong', remoteSocket: '/s');
  late Desk previous;
  setUp(() {
    previous = desk;
    desk = Desk.of('windows', const <String, String>{'SystemRoot': r'D:\Windows'});
  });
  tearDown(() => desk = previous);

  // Prevents PATH from selecting a different ssh installation and authentication agent.
  test('Windows login uid and daemon commands use the system OpenSSH', () {
    const ssh = r'D:\Windows\System32\OpenSSH\ssh.exe';
    expect(Tunnels.loginUidCommandAt(machine.host).first, ssh);
    expect(Tunnels.startCommandFor(machine).first, ssh);
    expect(Tunnels.stopCommandFor(machine).first, ssh);
  });

  test('Windows refusal explanation reads configuration with the system OpenSSH', () async {
    final ran = <List<String>>[];
    final tunnels = Tunnels(
      run: (command) async {
        ran.add(command);
        return command.contains('-G')
            ? ProcessResult(0, 0, 'identityfile ~/.ssh/work\n', '')
            : ProcessResult(0, 255, '', 'Permission denied (publickey)');
      },
    );
    addTearDown(tunnels.dispose);
    expect(await tunnels.loginUidAt(machine.host), isNull);
    expect(ran.last.first, r'D:\Windows\System32\OpenSSH\ssh.exe');
    expect(tunnels.lastLoginRefusal, contains('~/.ssh/work'));
  });

  // Prevents an option supplied as a host from becoming a local ssh command.
  test('option hosts never start sessions or daemon commands', () async {
    expect(() => Tunnels.startCommandFor(option), throwsArgumentError);
    expect(() => Tunnels.stopCommandFor(option), throwsArgumentError);
    expect(() => Tunnels.loginUidCommandAt(option.host), throwsArgumentError);
    final session = Session(
      task: 'work',
      machine: option,
      open: (_, _, {columns = 80, rows = 24}) => fail('No terminal may open.'),
    );
    addTearDown(session.dispose);
    expect(() => session.command, throwsA(isA<PtyRefused>()));
    expect(option.canBeStartedHere, isFalse);
    final tunnels = Tunnels(run: (_) async => fail('No ssh may run.'));
    final machines = Machines(Settings(MemorySettingsStore()), tunnels: tunnels);
    addTearDown(machines.dispose);
    expect((await machines.startPoreloOn(option)).went, isFalse);
  });

  test('Windows commands without a terminal cannot wait for a prompt', () {
    expect(onTheMachine(machine, <String>['porelo', 'doctor'], terminal: false), contains('BatchMode=yes'));
    desk = Desk.of('linux', const <String, String>{});
    expect(onTheMachine(machine, <String>['porelo', 'doctor'], terminal: false), <String>[
      'ssh',
      machine.host,
      inTheLoginShell('porelo doctor'),
    ]);
  });

  test('host key tools terminate options before outside hostnames', () async {
    final ran = <List<String>>[];
    final keys = SshHostKeys(
      run: (command, {input}) async {
        ran.add(command);
        if (command.contains('-G')) return ProcessResult(0, 0, 'hostname -host\nport 22\n', '');
        return ProcessResult(0, 0, '', '');
      },
    );
    await keys.check('-destination');
    expect(ran.first.sublist(1), <String>['-G', '--', '-destination']);
    expect(ran.singleWhere((line) => line.first.endsWith('ssh-keyscan.exe')).sublist(1), <String>[
      '-T',
      '10',
      '-H',
      '-p',
      '22',
      '--',
      '-host',
    ]);
  });

  test('a refused Windows ssh socket still describes its transport as ssh', () {
    final machines = Machines(Settings(MemorySettingsStore()));
    addTearDown(machines.dispose);
    const refused = Machine(name: 'box', socketPath: '', host: 'box', remoteSocket: '/socket with space');
    expect(machineKind(machines, refused), contains('reached over ssh'));
    expect(refused.canBeStartedHere, isFalse);
  });
}
