import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/connections.dart';
import 'package:porelo_frontend/src/app/desk.dart';
import 'package:porelo_frontend/src/app/pty.dart';
import 'package:porelo_frontend/src/app/session.dart';
import 'package:porelo_frontend/src/app/tunnel.dart';
import 'package:porelo_frontend/src/app/wsl.dart';
import 'package:porelo_host/porelo_host.dart' show HostCardSsh, inTheLoginShell;

/// The WSL distributions of a Windows user, read without starting any of them, and what the
/// interface says before it calls into one.
void main() {
  /// `wsl.exe` as a Windows in German answers it, by default in UTF-16.
  Wsl german({String? running = 'Ubuntu\r\n'}) => Wsl(
    run: (arguments) async {
      final text = switch (arguments.join(' ')) {
        '-l -q' => 'Ubuntu\r\nDebian\r\nOld\r\n',
        '-l --running -q' => running ?? '',
        '-l -v' =>
          '  NAME      STATUS            VERSION\r\n'
              '* Ubuntu    Wird ausgeführt   2\r\n'
              '  Debian    Beendet           2\r\n'
              '  Old       Beendet           1\r\n',
        _ => '',
      };
      return (code: 0, printed: _utf16(text));
    },
  );

  test('names, which run, the version and the default are read without the translated state column', () async {
    expect(await german().distributions(), <WslDistribution>[
      const WslDistribution(name: 'Ubuntu', running: true, version: 2, isDefault: true),
      const WslDistribution(name: 'Debian', running: false, version: 2),
      const WslDistribution(name: 'Old', running: false, version: 1),
    ]);
  });

  test('without WSL there are no distributions, and nothing is said to have failed', () async {
    final none = Wsl(run: (arguments) async => (code: 1, printed: <int>[]));

    expect(await none.distributions(), isEmpty);
    expect(await none.whyNotNow('Ubuntu'), contains('There is no WSL distribution called Ubuntu'));
  });

  test('a running WSL2 distribution is called into', () async {
    expect(await german().whyNotNow('Ubuntu'), isNull);
  });

  test('a stopped distribution is not, and the person is told to start it', () async {
    final said = await german().whyNotNow('Debian');

    expect(said, contains('Debian is stopped'));
    expect(said, contains('does not start it'));
  });

  test('a WSL1 distribution is not, with the conversion named and not run', () async {
    final said = await german(running: 'Ubuntu\r\nOld\r\n').whyNotNow('Old');

    expect(said, contains('WSL1'));
    expect(said, contains('wsl --set-version Old 2'));
  });

  test('UTF-8, as WSL_UTF8 asks for, reads the same as UTF-16', () {
    expect(decodeWsl(utf8.encode('Ubuntu\r\nDebian\r\n')), 'Ubuntu\nDebian\n');
    expect(decodeWsl(<int>[0xff, 0xfe, ..._utf16('Ubuntu\r\n')]), 'Ubuntu\n');
  });

  test('the relay is wsl.exe running porelo daemon connect in the distribution, with no shell', () {
    expect(Wsl.relayTo('Ubuntu 26.04'), <String>[
      'wsl.exe',
      '-d',
      'Ubuntu 26.04',
      '--exec',
      'porelo',
      'daemon',
      'connect',
    ]);
  });

  group('a machine in the list', () {
    const wsl = Machine(name: 'laptop', socketPath: '', kind: 'wsl', distribution: 'Ubuntu');
    const overSsh = Machine(
      name: 'box',
      socketPath: '/run/x.sock',
      host: 'me@box',
      remoteSocket: '/run/user/1000/porelo/porelod.sock',
    );
    const socket = Machine(name: 'here', socketPath: '/run/user/1000/porelo/porelod.sock');

    test('on Windows ssh must not be refused or prompt for a key', () {
      expect(wsl.whyNotReachableOn(windows: true), isNull);
      expect(overSsh.whyNotReachableOn(windows: true), isNull);
      expect(overSsh.relayOn(windows: true, environment: const <String, String>{})?.command, contains('BatchMode=yes'));
      expect(socket.whyNotReachableOn(windows: true), contains('socket on a Linux computer'));
    });

    test('an ssh relay must not send commands to WSL or raise a unix forward', () async {
      final previous = desk;
      desk = Desk.of('windows', const <String, String>{'SystemRoot': r'D:\Windows'});
      addTearDown(() => desk = previous);
      expect(overSsh.relay?.kind, 'ssh');
      expect(wsl.relay?.kind, 'wsl');
      expect(Machines.backendFor(overSsh).whyNotNow, isNull);
      expect(onTheMachine(overSsh, <String>['porelo', 'doctor'], terminal: true)?.take(3), <String>[
        r'D:\Windows\System32\OpenSSH\ssh.exe',
        '-t',
        overSsh.host,
      ]);
      expect(onTheMachineAsWritten(overSsh, 'porelo doctor')?.take(3), <String>[
        r'D:\Windows\System32\OpenSSH\ssh.exe',
        '-t',
        overSsh.host,
      ]);
      List<String>? opened;
      final session = Session(
        task: 'task with a quote',
        machine: overSsh,
        open: (executable, arguments, {columns = 80, rows = 24}) {
          opened = <String>[executable, ...arguments];
          throw const PtyRefused('No terminal in this test.');
        },
      );
      addTearDown(session.dispose);
      expect(opened?.take(3), <String>[r'D:\Windows\System32\OpenSSH\ssh.exe', '-t', overSsh.host]);
      final tunnels = Tunnels(start: (_) async => fail('A relay must not start a forward.'));
      addTearDown(tunnels.dispose);
      expect(await tunnels.raiseFor(overSsh), isTrue);
      expect(tunnels.manages(overSsh), isFalse);
    });

    test('Windows refuses socket characters that a non POSIX login shell could reinterpret', () {
      for (final path in <String>['/run/socket with space', "/run/socket'quote"]) {
        final machine = Machine(name: 'box', socketPath: '/local.sock', host: 'user@box', remoteSocket: path);
        expect(machine.whyNotReachableOn(windows: true), isNotNull);
        expect(machine.relayOn(windows: true, environment: const <String, String>{}), isNull);
        expect(machine.whyNotReachableOn(windows: false), isNull);
      }
    });

    test('Windows ssh bypasses PATH and refuses an option as a host', () {
      for (final root in <String>['', 'Windows', r'\\server\Windows', r'C:Windows']) {
        expect(
          overSsh.relayOn(windows: true, environment: <String, String>{'SystemRoot': root})?.command.first,
          r'C:\Windows\System32\OpenSSH\ssh.exe',
        );
      }
      expect(
        overSsh.relayOn(windows: true, environment: const <String, String>{'SystemRoot': r'D:\Windows'})?.command.first,
        r'D:\Windows\System32\OpenSSH\ssh.exe',
      );
      const option = Machine(name: 'bad', socketPath: '', host: '-oProxyCommand=wrong', remoteSocket: '/s');
      expect(option.whyNotReachableOn(windows: true), isNotNull);
      expect(option.whyNotReachableOn(windows: false), isNotNull);
    });

    // Harm: a host's card cannot be connected to from a Windows desktop, or its daemon is reached through a command
    // that can never connect there.
    test('a card machine on Windows reaches its daemon through a relay over its own config', () {
      const environment = <String, String>{'SystemRoot': r'D:\Windows', 'APPDATA': r'C:\Users\Alice\AppData\Roaming'};
      final card = HostCardSsh(
        name: 'alpha',
        address: 'alpha.example.org',
        sshPort: 2222,
        hostKey: _publicKey,
        login: 'alice',
        publicKey: _publicKey,
        webPort: 18080,
        gitPort: 18081,
        matrixPort: 18082,
      );
      final config = card.configPath(environment: environment, windows: true);
      final machine = Machine.fromHostCard(card, socketPath: '', sshConfig: config);

      expect(machine.whyNotReachableOn(windows: true), isNull);
      expect(machine.relayOn(windows: true, environment: environment)?.command, <String>[
        r'D:\Windows\System32\OpenSSH\ssh.exe',
        '-F',
        config,
        '-T',
        '-o',
        'ServerAliveInterval=15',
        '--',
        'alpha',
        inTheLoginShell("porelo daemon connect --socket '/run/porelo-host/people/alice/porelod.sock'"),
      ], reason: 'no master to keep out and no ProxyCommand that ends every connection of its own');
      expect(machine.loginSshOptionsOn(environment: environment, windows: true), <String>['-F', config]);
      expect(machine.loginSshOptionsOn(environment: environment, windows: false), <String>[
        '-F',
        config,
        '-o',
        'ControlMaster=no',
        '-o',
        'ProxyCommand=false',
      ], reason: 'on Linux every command still goes through the master');
      expect(machine.relayOn(windows: false, environment: environment), isNull);
    });

    test('on Linux the Linux ways are reached, and a WSL distribution is said not to be', () {
      expect(wsl.whyNotReachableOn(windows: false), contains('reached from Windows'));
      expect(overSsh.whyNotReachableOn(windows: false), isNull);
      expect(socket.whyNotReachableOn(windows: false), isNull);
    });
  });
}

const _publicKey = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

List<int> _utf16(String text) => <int>[
  for (final unit in text.codeUnits) ...<int>[unit & 0xff, unit >> 8],
];
