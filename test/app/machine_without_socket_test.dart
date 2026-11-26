@Tags(<String>['linux'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/tunnel.dart';

void main() {
  const runtime = <String, String>{'XDG_RUNTIME_DIR': '/run/user/4242'};

  // Prevents a machine set up elsewhere, with a host and no socket, from being listed with an empty path.
  test('a stored machine with a host and no socket gets this window own endpoint, and a save keeps it', () {
    final machine = Machine.fromStored(const <String, Object?>{
      'name': 'walk box',
      'host': 'me@walk.example',
      'remoteSocket': '/run/user/1000/porelo/porelod.sock',
    }, environment: runtime);

    expect(machine.socketPath, '/run/user/4242/porelo-tunnel-walk-box.sock');
    expect(machine.needsATunnel, isTrue);
    expect(machine.stored['socket'], machine.socketPath);
    expect(Machine.fromStored(machine.stored, environment: runtime), machine);
  });

  // Prevents an endpoint nobody serves from being made up and saved for an entry that has a host and no remote socket.
  test('a host with no remote socket and no card gets no endpoint, and its card names the remoteSocket', () {
    final machine = Machine.fromStored(const <String, Object?>{
      'name': 'walk box',
      'host': 'me@walk.example',
    }, environment: runtime);

    expect(machine.socketPath, isEmpty);
    expect(machine.whyNotReachableHere, 'walk box names a host but no remoteSocket in frontend.json.');
    expect(machine.whyNotReachableOn(windows: true), contains('remoteSocket'));
    expect(machine.stored.containsKey('socket') ? machine.stored['socket'] : '', isEmpty);
  });

  // Prevents a server prepared with no project from being given an endpoint it never serves.
  test('a prepared server with no daemon keeps no socket', () {
    final machine = Machine.fromStored(const <String, Object?>{
      'name': 'bare',
      'kind': 'host',
      'host': 'me@bare.example',
    }, environment: runtime);

    expect(machine.socketPath, isEmpty);
    expect(machine.serverOnly, isTrue);
  });

  // Prevents a stored socket from being replaced by the window's own endpoint.
  test('a stored socket is kept as it is', () {
    final machine = Machine.fromStored(const <String, Object?>{
      'name': 'kept',
      'host': 'me@kept.example',
      'socket': '/somewhere/else.sock',
      'remoteSocket': '/run/user/1000/porelo/porelod.sock',
    }, environment: runtime);

    expect(machine.socketPath, '/somewhere/else.sock');
  });

  // Prevents an entry with neither host nor socket from reaching the person as an empty path.
  test('an entry with neither host nor socket says which fields are missing', () {
    final machine = Machine.fromStored(const <String, Object?>{'name': 'porelo-walk'}, environment: runtime);

    expect(machine.socketPath, isEmpty);
    expect(machine.whyNotReachableHere, 'porelo-walk names neither a host nor a socket in frontend.json.');
  });

  // Prevents the tunnel from naming a folder of an empty path, or starting ssh for it.
  test('the tunnel refuses an empty socket path in words naming the field and starts no ssh', () async {
    var started = 0;
    final tunnel = Tunnel(
      const Machine(name: 'empty', socketPath: '', host: 'me@h', remoteSocket: '/run/user/1/porelo/porelod.sock'),
      start: (_) async {
        started++;
        return Process.start('true', const <String>[]);
      },
    );

    await tunnel.raise();

    expect(tunnel.state, TunnelState.down);
    expect(tunnel.problem, allOf(contains('socket'), contains('frontend.json'), isNot(contains('folder of'))));
    expect(started, 0);
  });
}
