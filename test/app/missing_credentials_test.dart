import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/connections.dart' show inTheLoginShell;
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/missing_credentials.dart';

/// Where a host's command for a credential it lacks is run: on that host, and nowhere else.
void main() {
  const missing = MissingCredential(
    purpose: 'builds',
    credential: 'forge.person',
    storeCommand: <String>['porelo', 'host', 'forge-token'],
    afterStore: 'ask-again',
  );

  // Harm: run on this computer, the command reaches another vault than the host's, or makes a token there.
  test('the command runs over ssh on the host, in its login shell', () {
    const host = Machine(
      name: 'build',
      socketPath: '/tmp/build.sock',
      host: 'alice@build',
      remoteSocket: '/run/user/1000/porelo/porelod.sock',
    );
    final run = storedOnTheHost(host, missing)!;
    expect(run.first, endsWith('ssh'));
    expect(run, containsAllInOrder(<String>['-t', 'alice@build']));
    expect(run.last, inTheLoginShell('porelo host forge-token'));
  });

  // Harm: the same, for a daemon this window reaches without ssh of its own.
  test('nothing runs for this computer, a WSL distribution or a socket somebody else forwards', () {
    for (final machine in <Machine>[
      Machine(name: 'this computer', socketPath: Backend.local().socketPath),
      const Machine(name: 'forwarded', socketPath: '/tmp/forwarded.sock'),
      const Machine(
        name: 'wsl',
        socketPath: '/tmp/wsl.sock',
        kind: 'wsl',
        distribution: 'Ubuntu',
        host: 'alice@build',
        remoteSocket: '/run/user/1000/porelo/porelod.sock',
      ),
      // ssh would read it as an option, not a host.
      const Machine(
        name: 'dash',
        socketPath: '/tmp/dash.sock',
        host: '-oProxyCommand=sh',
        remoteSocket: '/run/user/1000/porelo/porelod.sock',
      ),
    ]) {
      expect(storedOnTheHost(machine, missing), isNull, reason: machine.name);
      expect(reachesTheHostItself(machine), isFalse, reason: '${machine.name}: no press is offered that runs nothing');
    }
  });

  // Harm: a command the machine never named, or one cut down to nothing, run on the host.
  test('nothing runs where the machine named no command', () {
    const host = Machine(name: 'build', socketPath: '/tmp/b.sock', host: 'alice@build', remoteSocket: '/run/p.sock');
    expect(storedOnTheHost(host, const MissingCredential(purpose: 'builds', credential: 'forge.person')), isNull);
  });
}
