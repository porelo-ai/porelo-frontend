import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/connection_trial.dart';
import 'package:porelo_frontend/src/app/desk.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/tunnel.dart';
import 'package:porelo_host/porelo_host.dart' show poreloHostKnownHosts;

import '../../packages/porelo_host/test/support/pinned_ssh.dart';
import '../features/support/world.dart';

void main() {
  const host = Machine(
    name: 'server',
    socketPath: '/tmp/server.sock',
    kind: 'host',
    host: 'porelo@203.0.113.7',
    remoteSocket: '/run/user/1007/porelo/porelod.sock',
    identity: '/keys/host identity',
    distribution: 'kept distribution',
    unknownFields: <String, Object?>{'future': 'kept'},
  );
  late Desk previous;
  setUp(() {
    previous = desk;
    desk = Desk.of('linux', const <String, String>{});
  });
  tearDown(() => desk = previous);

  // Prevents a temporary trial or vault tunnel bypassing the host's pinned key and identity.
  // Red: rebuild either target with only name, socketPath, host and remoteSocket.
  for (final vault in <bool>[false, true]) {
    test('a ${vault ? 'vault' : 'connection'} trial keeps every host field and pins its tunnel', () async {
      final tunnels = _Trials();
      addTearDown(tunnels.dispose);
      final reached = <Machine>[];
      FakeBackend reach(Machine machine) {
        reached.add(machine);
        return FakeBackend(const <Task>[]);
      }

      if (vault) {
        expect(await countKeyslots(host, reach: reach, tunnels: tunnels), 1);
      } else {
        expect((await tryAMachine(host, reach: reach, tunnels: tunnels)).reached, isTrue);
      }
      final target = tunnels.tried.single;
      expect(reached, <Machine>[target]);
      expect(target.socketPath, isNot(host.socketPath));
      expect(target.stored, <String, Object?>{...host.stored, 'socket': target.socketPath});
      expect(
        pinnedCommandProblems(Tunnel(target).command, knownHosts: poreloHostKnownHosts(), identity: host.identity),
        isEmpty,
      );
      expect(tunnels.dropped, <Machine>[target]);
    }, tags: 'linux');
  }

  // Prevents both the uid command and its failed-login diagnostic from using personal trust.
  // Red: omit options at loginUidOn, loginUidCommandAt or the failed uid's _explainSshRefusal call.
  test('a failed host uid probe keeps the pin at every call site', () async {
    final ran = <List<String>>[];
    final tunnels = _Trials(
      run: (command) async {
        ran.add(command);
        return command.contains('-G')
            ? ProcessResult(0, 0, 'identityfile /keys/host identity\n', '')
            : ProcessResult(0, 255, '', 'Permission denied (publickey)');
      },
    );
    addTearDown(tunnels.dispose);
    final result = await tryAMachine(
      host,
      reach: (_) => FakeBackend(const <Task>[])..absent = const VarlinkDisconnected('Connection refused'),
      tunnels: tunnels,
    );
    expect(result.nothingServing, isTrue);
    expect(ran, hasLength(2));
    expect(ran.first.last, 'id -u');
    expect(ran.last, contains('-G'));
    for (final command in ran) {
      expect(pinnedCommandProblems(command, knownHosts: poreloHostKnownHosts(), identity: host.identity), isEmpty);
    }
  }, tags: 'linux');

  // Prevents the relay trial's explainRefusal call from losing the host trust policy.
  // Red: drop options: machine.loginSshOptions at that call in tryAMachine.
  test('a host relay trial explains an SSH refusal using the pin', () async {
    desk = Desk.of('windows', const <String, String>{'SystemRoot': r'C:\Windows'});
    final ran = <List<String>>[];
    final tunnels = Tunnels(
      run: (command) async {
        ran.add(command);
        return ProcessResult(0, 0, 'identityfile /keys/host identity\n', '');
      },
    );
    addTearDown(tunnels.dispose);
    final result = await tryAMachine(
      host,
      reach: (_) => FakeBackend(const <Task>[])..absent = const RelayDisconnected('Permission denied (publickey)', 255),
      tunnels: tunnels,
    );
    expect(result.reached, isFalse);
    expect(ran.single, contains('-G'));
    expect(pinnedCommandProblems(ran.single, knownHosts: poreloHostKnownHosts(), identity: host.identity), isEmpty);
  });
}

class _Trials extends Tunnels {
  _Trials({super.run});
  final tried = <Machine>[];
  final dropped = <Machine>[];
  @override
  Future<Tunnel> trial(Machine machine) async {
    tried.add(machine);
    return _Trial(machine, dropped)..state = TunnelState.up;
  }
}

class _Trial extends Tunnel {
  _Trial(super.machine, this.dropped);
  final List<Machine> dropped;
  @override
  Future<void> drop() async => dropped.add(machine);
}
