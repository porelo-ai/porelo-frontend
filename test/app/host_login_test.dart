import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/connections.dart';
import 'package:porelo_frontend/src/app/desk.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/login_forward.dart';
import 'package:porelo_frontend/src/app/session.dart';
import 'package:porelo_frontend/src/app/tunnel.dart';
import 'package:porelo_host/porelo_host.dart' show poreloHostKnownHosts;
import 'package:porelo_frontend/src/app/host_keys.dart';

import '../../packages/porelo_host/test/support/pinned_ssh.dart';

import '../features/support/world.dart';

void main() {
  const host = Machine(
    name: 'demo server',
    kind: 'host',
    socketPath: '/tmp/host.sock',
    host: 'porelo@203.0.113.7',
    remoteSocket: '/run/user/1007/porelo/porelod.sock',
    identity: '/keys/host identity',
  );

  // Harm: an empty identity disables agent authentication for every one-click host command.
  test('a one-click host uses its written config and never an empty identity', () {
    const machine = Machine(
      name: 'one click',
      kind: 'host',
      hostProject: 'orchard',
      host: 'worker@orchard',
      socketPath: '/unused',
      remoteSocket: '/run/user/1007/porelo',
    );
    final command = onTheMachine(machine, ['porelo', 'agents'], terminal: false)!;
    expect(command, isNot(contains('')), reason: 'OpenSSH must never receive an empty identity path');
    expect(command, isNot(contains('-i')));
    expect(command, contains('-F'));
    expect(command[command.indexOf('-F') + 1], endsWith('/porelo/ssh/orchard.conf'));
  });

  // Harm: an address that misses the config's Host stanza must never use default trust.
  test('an address outside the host alias still uses only the card pin', () async {
    final scratch = await Directory.systemTemp.createTemp('card-pin-');
    addTearDown(() => scratch.delete(recursive: true));
    final directory = await Directory('${scratch.path}/literal%h').create();
    final previous = desk;
    desk = LinuxDesk({'XDG_CONFIG_HOME': directory.path});
    addTearDown(() => desk = previous);
    final config = File('${directory.path}/porelo/ssh/orchard.conf');
    await config.parent.create(recursive: true);
    await config.writeAsString(
      'Host orchard\n  StrictHostKeyChecking yes\n'
      '  UserKnownHostsFile "${config.path.replaceAll('%', '%%')}.known_hosts"\n'
      '  GlobalKnownHostsFile none\n  BatchMode yes\n  ForwardAgent no\n',
    );
    const machine = Machine(
      name: 'one click',
      kind: 'host',
      hostProject: 'orchard',
      host: 'worker@192.0.2.7',
      socketPath: '',
      remoteSocket: '/run/user/1007/porelo',
    );
    final command = onTheMachine(machine, ['true'], terminal: false)!;
    final result = await Process.run(command.first, ['-G', ...command.skip(1)]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    final effective = result.stdout.toString().split('\n');
    for (final setting in [
      'stricthostkeychecking true',
      'userknownhostsfile ${config.path}.known_hosts',
      'globalknownhostsfile none',
      'batchmode yes',
      'forwardagent no',
      'controlmaster false',
    ]) {
      expect(effective, contains(setting), reason: 'the card pin must apply when the alias does not match');
    }
    expect(command, containsAll(['KnownHostsCommand=none', 'ControlPath=none']));
  });

  // Harm: a refused legacy account or missing config must not open a relay or crash startup.
  test('Windows relay refuses unreachable host entries before building SSH options', () {
    for (final machine in [
      const Machine(
        name: 'missing config',
        kind: 'host',
        host: 'worker@192.0.2.7',
        socketPath: '',
        remoteSocket: '/run/user/1007/porelo',
      ),
      const Machine(
        name: 'legacy',
        kind: 'host',
        hostProject: 'orchard',
        legacyHost: true,
        host: 'worker@192.0.2.7',
        socketPath: '',
        remoteSocket: '/run/user/1007/porelo',
      ),
      host,
    ]) {
      expect(machine.relayOn(windows: true, environment: const {}), isNull);
    }
  });

  // Harm: consulting the runner's Linux environment selects another person's Windows config.
  test('Windows relay uses its supplied platform and environment for host config', () {
    const machine = Machine(
      name: 'one click',
      kind: 'host',
      hostProject: 'orchard',
      host: 'worker@orchard',
      socketPath: '',
      remoteSocket: '/run/user/1007/porelo',
    );
    final command = machine
        .relayOn(windows: true, environment: const {'APPDATA': r'D:\Profile\Config', 'SystemRoot': r'D:\Windows'})!
        .command;
    expect(command.first, r'D:\Windows\System32\OpenSSH\ssh.exe');
    expect(command[command.indexOf('-F') + 1], r'D:\Profile\Config\porelo\ssh\orchard.conf');
    expect(command, contains(r'UserKnownHostsFile="D:\Profile\Config\porelo\ssh\orchard.conf.known_hosts"'));
  });

  // Prevents every access path from trusting a key outside the pin or using the wrong identity.
  // Red: remove the pinned prefix from each of these builders in turn, or append a trust option.
  test('all host ssh commands begin with the pinned policy without later trust options', () {
    final session = Session(
      task: 'task',
      machine: host,
      open: (exe, args, {columns = 80, rows = 24}) => FakeTerminal(<String>[exe, ...args]),
    );
    addTearDown(session.dispose);
    final commands = <String, List<String>>{
      'tunnel': Tunnel(host).command,
      'terminal': session.command,
      'forward': loginForwardCommand(host, 42017),
      'command': onTheMachine(host, <String>['porelo', 'vault', 'login', 'pi'], terminal: true)!,
      'batch command': onTheMachine(host, <String>['porelo', 'agents'], terminal: false)!,
      'written command': onTheMachineAsWritten(host, 'porelo agents')!,
      'start daemon': Tunnels.startCommandFor(host),
      'stop daemon': Tunnels.stopCommandFor(host),
      'uid': Tunnels.loginUidCommandFor(host),
    };
    expect(commands.keys, <String>[
      'tunnel',
      'terminal',
      'forward',
      'command',
      'batch command',
      'written command',
      'start daemon',
      'stop daemon',
      'uid',
    ]);
    for (final entry in commands.entries) {
      expect(
        pinnedCommandProblems(entry.value, knownHosts: poreloHostKnownHosts(), identity: host.identity),
        isEmpty,
        reason: entry.key,
      );
      expect(entry.value, contains(host.host), reason: entry.key);
    }
    expect(commands['command']!.last, inTheLoginShell('porelo vault login pi'));
    expect(
      onTheMachine(host, <String>['porelo', 'vault', 'login', 'pi; touch x'], terminal: true)!.last,
      inTheLoginShell("porelo vault login 'pi; touch x'"),
    );
  });

  // Prevents diagnostic SSH and uid probes from reverting to the person's trust policy.
  // Red: drop the pin in loginUidOn or explainRefusal before constructing ssh -G.
  test('host uid and refusal probes also use the pin', () async {
    final ran = <List<String>>[];
    final tunnels = Tunnels(
      run: (command) async {
        ran.add(command);
        return ProcessResult(0, 0, command.last == 'id -u' ? '1007\n' : 'identityfile /keys/host identity\n', '');
      },
    );
    addTearDown(tunnels.dispose);
    expect(await tunnels.loginUidOn(host), 1007);
    await tunnels.explainRefusal('Permission denied (publickey)', host.host, options: host.loginSshOptions);
    expect(ran, hasLength(2));
    for (final command in ran) {
      expect(pinnedCommandProblems(command, knownHosts: poreloHostKnownHosts(), identity: host.identity), isEmpty);
    }
    expect(ran.last, contains('-G'));
  });

  // Prevents loss of the host's identity path and unchecked settings values causing a crash.
  // Red: omit identity from storage, or cast a stored number to String.
  test('stored host identity round trips and wrong types refuse access', () {
    expect(Machine.fromStored(host.stored), host);
    expect(host.stored['identity'], host.identity);
    expect(Machine.fromStored(host.stored).unknownFields, isNot(contains('identity')));
    for (final wrong in <Object?>[
      null,
      7,
      true,
      <String>['key'],
      <String, String>{'key': 'value'},
    ]) {
      final read = Machine.fromStored(<String, Object?>{...host.stored, 'identity': wrong});
      expect(read.identity, isEmpty);
      expect(read.whyNotReachableHere, isNotNull);
    }
  });

  // Prevents accepting an attacker's key into the person's trust file for a managed host.
  // Red: remove the host-kind refusal from checkMachine or the accept guard.
  test('host keys neither scans nor writes trust for a host machine', () async {
    final keys = SshHostKeys(run: (command, {input}) async => fail('No key command may run for a managed host.'));
    final check = await keys.checkMachine(host);
    expect(check.known, isFalse);
    expect(check.problem, contains('Only porelo-host'));
    expect(check.scanned, isEmpty);
    expect(() => keys.accept(check), throwsStateError);
  });

  // Prevents a general terminal from opening ports, or a login forward from outliving its terminal.
  // Red: honor forwarding OSC outside login terminals, or omit close on terminal exit.
  test('only the host login terminal forwards a reply and closes it when it ends', () async {
    final previous = raiseLoginForward;
    addTearDown(() => raiseLoginForward = previous);
    final raised = <Machine>[];
    var closed = 0;
    raiseLoginForward = (destination, port) async {
      expect(port, 42017);
      raised.add(destination);
      return _Forward(() => closed++);
    };
    final terminals = <FakeTerminal>[];
    Session open(bool login) => Session(
      task: 'login',
      machine: host,
      run: onTheMachine(host, <String>['porelo', 'vault', 'login', 'pi'], terminal: true)!,
      forwardsALoginReply: login,
      open: (executable, arguments, {columns = 80, rows = 24}) {
        final far = FakeTerminal(<String>[executable, ...arguments]);
        terminals.add(far);
        return far;
      },
    );
    final ordinary = open(false);
    final login = open(true);
    addTearDown(ordinary.dispose);
    addTearDown(login.dispose);
    terminals.first.prints('\x1b]5379;forward;42017\x1b\\');
    await pumpEventQueue();
    expect(raised, isEmpty);
    terminals.last.prints('\x1b]5379;forward;42017\x1b\\');
    await pumpEventQueue();
    expect(raised, <Machine>[host]);
    terminals.last.endsWith(0);
    await pumpEventQueue();
    expect(closed, 1);
    final ended = open(true);
    addTearDown(ended.dispose);
    terminals.last.endsWith(0);
    await pumpEventQueue();
    terminals.last.prints('\x1b]5379;forward;42017\x1b\\');
    await pumpEventQueue();
    expect(raised, <Machine>[host], reason: 'an ended terminal cannot ask for a new forward');
  });
  // Prevents a forward that finishes opening late from surviving the login it was meant to serve.
  // Red: keep a late forward after its terminal has ended.
  test('a reply forward still opening when the login ends is closed on arrival', () async {
    final previous = raiseLoginForward;
    addTearDown(() => raiseLoginForward = previous);
    final pending = Completer<HeldForward>();
    raiseLoginForward = (_, _) => pending.future;
    late FakeTerminal far;
    final session = Session(
      task: 'login',
      machine: host,
      run: onTheMachine(host, <String>['porelo', 'vault', 'login', 'pi'], terminal: true)!,
      forwardsALoginReply: true,
      open: (executable, arguments, {columns = 80, rows = 24}) =>
          far = FakeTerminal(<String>[executable, ...arguments]),
    );
    addTearDown(session.dispose);
    far.prints('\x1b]5379;forward;42017\x1b\\');
    await pumpEventQueue();
    far.endsWith(0);
    await pumpEventQueue();
    var closed = 0;
    pending.complete(_Forward(() => closed++));
    await pumpEventQueue();
    expect(closed, 1, reason: 'an ended login has no listener for a late forward');
  });
}

class _Forward implements HeldForward {
  _Forward(this.onClose);
  final void Function() onClose;
  @override
  Future<void> close() async => onClose();
}
