// Linux only: it forwards unix sockets with ssh and sh, which dart:io cannot open on Windows.
@Tags(<String>['linux'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/connections.dart';
import 'package:porelo_frontend/src/app/desk.dart';
import 'package:porelo_frontend/src/app/ending_signals.dart';
import 'package:porelo_frontend/src/app/forward_records.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/own_sockets.dart';
import 'package:porelo_frontend/src/app/tunnel.dart';
import 'package:porelo_host/porelo_host.dart' show poreloHostKnownHosts;

import '../../packages/porelo_host/test/support/pinned_ssh.dart';
import '../support/other_sockets.dart';

/// Forwards this interface raises and owns.
///
/// Held against **real processes and real sockets**, with a stand-in in place of `ssh`. There is
/// no remote host to reach and there does not need to be: everything this class decides is about
/// a process that either binds a socket or dies saying why, and both are producible here. A test
/// that mocked the process away would prove the arrangement of the code and nothing about the
/// thing that goes wrong.
void main() {
  late Directory where;

  setUp(() {
    where = Directory.systemTemp.createTempSync('tn-');
    // This account's alone, as the runtime directory is: the one place a socket the window made is later removed.
    Process.runSync('chmod', <String>['700', where.path]);
    addTearDown(() {
      if (where.existsSync()) where.deleteSync(recursive: true);
    });
  });

  Machine machineAt(String socket) => Machine(
    name: 'the build machine',
    socketPath: socket,
    host: 'user@build',
    remoteSocket: '/run/user/1001/porelo/porelod.sock',
  );

  // Prevents one host's service URL from silently reaching another host.
  test('cards sharing a service port name both hosts before publishing or launching the second', () async {
    final commands = <List<String>>[];
    final tunnels = Tunnels(
      configEnvironment: {'XDG_CONFIG_HOME': where.path},
      keyAvailable: (_) async => true,
      portsAvailable: (_) async {},
      run: (_) async => ProcessResult(0, 1, '', ''),
      start: (command) async {
        commands.add(command);
        final process = _ControlledProcess();
        process.end('Connection closed');
        return process;
      },
    );
    addTearDown(tunnels.dispose);
    addTearDown(tunnels.dropEverything);
    Machine card(String name) => Machine.fromStored(<String, Object?>{
      'name': name,
      'kind': 'host',
      'host': name,
      'identity': '${where.path}/$name.pub',
      'socket': '${where.path}/$name.sock',
      'remoteSocket': '/run/user/1001/porelo/porelod.sock',
      'sshConfig': '${where.path}/porelo/ssh/$name.conf',
      'hostCard': <String, Object?>{
        'name': name,
        'address': '$name.example.org',
        'ssh_port': 22,
        'host_key': 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
        'login': 'alice',
        'public_key': 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
        'uid': 1001,
        'return_socket': '/run/porelo-host/people/alice/messenger.sock',
        'services': <String, Object?>{
          'forge': <String, Object?>{'web_port': 18080, 'git_port': 18081},
          'matrix': <String, Object?>{'port': 18082},
        },
      },
    });
    await tunnels.raiseFor(card('alpha'));
    final before = commands.length;
    expect(before, 1, reason: 'the first nonconflicting host really launched');
    expect(File('${where.path}/porelo/ssh/alpha.conf').existsSync(), isTrue);

    final beta = card('beta');
    expect(await tunnels.raiseFor(beta), isFalse);
    expect(tunnels.of(beta)!.problem, allOf(contains('alpha'), contains('beta'), contains('18080')));

    expect(commands, hasLength(before), reason: 'the conflicting host must never launch');
    expect(
      File('${where.path}/porelo/ssh/beta.conf').existsSync(),
      isFalse,
      reason: 'the conflicting config must not be published',
    );
  });

  /// A stand-in for `ssh` that binds the socket and stays up, as a working forward does.
  Future<Process> Function(List<String>) bindsAndStays(String socket) =>
      (_) => Process.start('sh', <String>[
        '-c',
        // A real unix socket, made by something other than this test, then held open. `nc -lU`
        // is not everywhere; a two-line python is. **`exec`**, so that killing the process
        // this returns kills the server: without it the shell dies and its child goes on
        // serving, which is not how killing `ssh` behaves.
        'exec python3 -c "'
            'import socket,time;'
            's=socket.socket(socket.AF_UNIX);'
            's.bind(\'$socket\');'
            's.listen(1);'
            'time.sleep(300)"',
      ]);

  /// A stand-in that fails the way `ssh` fails: nothing bound, a sentence on stderr, non-zero.
  Future<Process> Function(List<String>) failsSaying(String words) =>
      (_) => Process.start('sh', <String>['-c', 'echo "$words" >&2; exit 255']);

  // Prevents a forward nobody holds any more from being raised by a reconnect queued behind its drop.
  test('a reconnect queued behind a drop raises nothing', () async {
    final socket = '${where.path}/queued.sock';
    final machine = machineAt(socket);
    var started = 0;
    final binds = bindsAndStays(socket);
    final tunnels = Tunnels(
      start: (command) {
        started++;
        return binds(command);
      },
    );
    addTearDown(tunnels.dispose);
    addTearDown(tunnels.dropEverything);
    expect(await tunnels.raiseFor(machine), isTrue);

    final dropping = tunnels.dropFor(machine);
    final reconnecting = tunnels.raiseAgainIfItDropped(machine);
    await dropping;
    await reconnecting;

    expect(tunnels.of(machine)?.state, isNot(TunnelState.up), reason: 'the machine was let go');
    expect(started, 1, reason: 'only the first raise started ssh');
  });

  // Measured: under a person's ControlMaster the forward lived in their master, and
  // letting go of this process left it answering. The command line wins over their config.
  test("the forward is a connection of its own, never through the person's ssh master", () {
    final command = Tunnel(machineAt('/tmp/x.sock')).command;
    String option(String name) =>
        command[command.indexWhere((each) => each.startsWith('$name=')).clamp(0, command.length - 1)];

    expect(option('ControlMaster'), 'ControlMaster=no');
    expect(option('ControlPath'), 'ControlPath=none');
    expect(
      command.indexOf('ControlMaster=no'),
      lessThan(command.indexOf('-L')),
      reason: 'options before the forward, as ssh reads them',
    );
  });

  test('a forward that binds is up, and the endpoint exists', () async {
    final socket = '${where.path}/up.sock';
    final tunnel = Tunnel(machineAt(socket), start: bindsAndStays(socket));
    addTearDown(tunnel.drop);

    await tunnel.raise();

    expect(tunnel.state, TunnelState.up);
    expect(File(socket).existsSync(), isTrue);
    expect(tunnel.problem, isNull);
  });

  test('a forward that is refused says what the transport said', () async {
    final hostKey = Tunnel(
      machineAt('${where.path}/refused.sock'),
      start: failsSaying('Host key verification failed.'),
    );
    await hostKey.raise();

    // "Host key verification failed" is a different problem from a machine that is not there, and
    // reporting the second sends somebody looking in the wrong place.
    expect(hostKey.state, TunnelState.down);
    expect(hostKey.problem, contains('host key'));

    final raw = Tunnel(
      machineAt('${where.path}/raw.sock'),
      start: failsSaying('remote port forwarding failed for listen path'),
    );
    await raw.raise();

    expect(raw.state, TunnelState.down);
    expect(raw.problem, contains('remote port forwarding failed'));
  });

  test('a forward whose login is refused explains why and names the key ssh would use', () async {
    final tunnel = Tunnel(
      machineAt('${where.path}/denied.sock'),
      start: failsSaying('user@build: Permission denied (publickey).'),
      run: (command) async => ProcessResult(
        0,
        0,
        command.contains('-G') ? 'identityfile ~/.ssh/porelo-build-agent\nidentityfile ~/.ssh/id_ed25519\n' : '',
        '',
      ),
    );

    await tunnel.raise();

    expect(tunnel.state, TunnelState.down);
    expect(tunnel.problem, contains('user@build accepted none of the keys your ssh agent offered'));
    expect(
      tunnel.problem,
      contains(
        "It would log in with ~/.ssh/porelo-build-agent; "
        "that key's public half must be in the account's authorized_keys.",
      ),
    );
  });

  test('a refused login with only default ssh keys says no key is named for the host', () async {
    const defaults =
        'identityfile ~/.ssh/id_rsa\n'
        'identityfile ~/.ssh/id_ecdsa\n'
        'identityfile ~/.ssh/id_ecdsa_sk\n'
        'identityfile ~/.ssh/id_ed25519\n'
        'identityfile ~/.ssh/id_ed25519_sk\n';
    final tunnel = Tunnel(
      machineAt('${where.path}/defaults.sock'),
      start: failsSaying('user@build: Permission denied (publickey).'),
      run: (command) async => ProcessResult(0, 0, command.contains('-G') ? defaults : '', ''),
    );

    await tunnel.raise();

    expect(tunnel.problem, contains('user@build accepted none of the keys your ssh agent offered'));
    expect(tunnel.problem, contains('No key is named for user@build'));
  });

  // A failed ssh -G knows nothing of the keys: saying none is named would send somebody to edit a
  // configuration that may well name one.
  test('a refused login says nothing about keys when ssh -G itself fails', () async {
    final tunnel = Tunnel(
      machineAt('${where.path}/no-config.sock'),
      start: failsSaying('user@build: Permission denied (publickey).'),
      run: (command) async => ProcessResult(0, command.contains('-G') ? 255 : 0, '', 'ssh: bad configuration'),
    );

    await tunnel.raise();

    expect(tunnel.problem, contains('user@build accepted none of the keys your ssh agent offered'));
    expect(tunnel.problem, isNot(contains('No key is named')));
    expect(tunnel.problem, isNot(contains('It would log in with')));
  });

  // Prevents a failed host tunnel's diagnostic SSH from reverting to personal trust.
  // Red: omit options: machine.loginSshOptions in Tunnel._itEnded.
  test('a failed host tunnel explains its refusal with the pinned policy', () async {
    final process = _ControlledProcess();
    final ran = <List<String>>[];
    final machine = Machine(
      name: 'host',
      kind: 'host',
      socketPath: '${where.path}/host.sock',
      host: 'user@host',
      remoteSocket: '/run/user/1001/porelo/porelod.sock',
      identity: '/keys/host identity',
    );
    final tunnel = Tunnel(
      machine,
      start: (_) async {
        process.end('Permission denied (publickey).');
        return process;
      },
      run: (command) async {
        ran.add(command);
        return ProcessResult(0, 0, 'identityfile /keys/host identity\n', '');
      },
    );
    addTearDown(tunnel.drop);
    await tunnel.raise();
    expect(tunnel.problem, contains('accepted none'));
    expect(ran.single, contains('-G'));
    expect(
      pinnedCommandProblems(
        ran.single,
        knownHosts: poreloHostKnownHosts(environment: desk.environment, windows: false),
        identity: machine.identity,
      ),
      isEmpty,
    );
  });

  // A delayed explanation must not prevent recovery or overwrite a recovered forward.
  test('a dropped forward is down with raw words while ssh config is pending', () async {
    final config = Completer<ProcessResult>();
    final asked = Completer<void>();
    final process = _ControlledProcess();
    final socket = '${where.path}/pending.sock';
    final tunnels = Tunnels(
      start: (_) async {
        process.end('Permission denied (publickey).');
        return process;
      },
      run: (command) {
        if (!command.contains('-G')) return Process.run(command.first, command.sublist(1));
        asked.complete();
        return config.future;
      },
    );
    late final Future<bool> raising;
    addTearDown(() async {
      if (!config.isCompleted) config.complete(ProcessResult(0, 0, '', ''));
      await raising;
      await tunnels.dropEverything();
      tunnels.dispose();
    });
    final machine = machineAt(socket);
    final changes = <String?>[];
    final explained = Completer<void>();
    tunnels.addListener(() {
      final problem = tunnels.of(machine)?.problem;
      changes.add(problem);
      if (problem != null && problem.contains('accepted none') && !explained.isCompleted) explained.complete();
    });
    raising = tunnels.raiseFor(machine);
    await asked.future;

    expect(tunnels.of(machine)!.state, TunnelState.down);
    expect(tunnels.of(machine)!.problem, 'Permission denied (publickey).');
    expect(changes, contains('Permission denied (publickey).'));
    config.complete(ProcessResult(0, 0, 'identityfile ~/.ssh/build-key\n', ''));
    await explained.future.timeout(const Duration(milliseconds: 500));
    expect(changes.last, contains('It would log in with ~/.ssh/build-key'));
  });

  // An unresponsive ssh config command must not hold a failed raise open.
  test('ssh config that never answers leaves raw words after the bound', () async {
    final process = _ControlledProcess();
    final tunnel = Tunnel(
      machineAt('${where.path}/bounded.sock'),
      start: (_) async {
        process.end('Permission denied (publickey).');
        return process;
      },
      run: (_) => Completer<ProcessResult>().future,
      appears: const Duration(milliseconds: 100),
      explains: const Duration(milliseconds: 5),
    );
    addTearDown(tunnel.drop);

    await tunnel.raise().timeout(const Duration(milliseconds: 500));

    expect(tunnel.state, TunnelState.down);
    expect(tunnel.problem, 'Permission denied (publickey).');
  });

  test('an old refusal explanation cannot overwrite a newer raise', () async {
    final config = Completer<ProcessResult>();
    final asked = Completer<void>();
    final first = _ControlledProcess();
    final next = Completer<Process>();
    final second = _ControlledProcess();
    final socket = '${where.path}/generation.sock';
    var attempt = 0;
    final tunnel = Tunnel(
      machineAt(socket),
      start: (command) async {
        if (++attempt > 1) return next.future;
        first.end('Permission denied (publickey).');
        return first;
      },
      run: (command) {
        if (!command.contains('-G')) return Process.run(command.first, command.sublist(1));
        asked.complete();
        return config.future;
      },
      appears: const Duration(milliseconds: 300),
    );
    addTearDown(tunnel.drop);
    final raising = tunnel.raise();
    await asked.future;
    final refusal = tunnel.problem;
    final reraising = tunnel.raise();
    addTearDown(() async {
      if (!next.isCompleted) next.complete(second);
      if (!second._exit.isCompleted) second.end('Connection closed');
      await Future.wait(<Future<void>>[raising, reraising]);
    });
    await Future<void>.delayed(Duration.zero);
    expect(tunnel.state, TunnelState.raising);

    config.complete(ProcessResult(0, 0, 'identityfile ~/.ssh/build-key\n', ''));
    await Future<void>.delayed(Duration.zero);

    expect(tunnel.state, TunnelState.raising);
    expect(tunnel.problem, refusal, reason: 'the retry keeps its refusal until it has a new answer');
    next.complete(second);
    second.end('Connection closed');
    await Future.wait(<Future<void>>[raising, reraising]);
  });

  test('a command that does not exist is a refusal, not a crash', () async {
    final tunnel = Tunnel(
      machineAt('${where.path}/missing.sock'),
      start: (command) => Process.start('definitely-not-a-command-here', const <String>[]),
    );

    await tunnel.raise();

    expect(tunnel.state, TunnelState.down);
    expect(tunnel.problem, isNotNull);
  });

  test('a forward that never binds gives up and says so', () async {
    final tunnel = Tunnel(
      machineAt('${where.path}/never.sock'),
      // Up, and nothing bound: the shape ExitOnForwardFailure exists to prevent, produced here
      // by a process that simply sits there.
      start: (_) => Process.start('sh', const <String>['-c', 'sleep 30']),
      appears: const Duration(milliseconds: 300),
    );
    addTearDown(tunnel.drop);

    await tunnel.raise();

    expect(tunnel.state, TunnelState.down);
    expect(tunnel.problem, contains('not ready'));
  });

  test('a plain file where the socket goes is not a forward', () async {
    // Anything at that path would read as a working forward if existence were the test, and a
    // leftover from a run that died is exactly a file at that path. It has to be a socket.
    final socket = '${where.path}/not-a-socket.sock';
    final tunnel = Tunnel(
      machineAt(socket),
      start: (_) => Process.start('sh', <String>['-c', 'touch $socket; sleep 30']),
      appears: const Duration(milliseconds: 400),
    );
    addTearDown(tunnel.drop);

    await tunnel.raise();

    expect(tunnel.state, TunnelState.down);
    expect(tunnel.problem, contains('not ready'));
  });

  test('a socket left by a run that died is taken over, not surrendered to', () async {
    // Otherwise one crash means the machine can never be opened again without somebody knowing to
    // delete a file they have never heard of. ssh refuses to bind a path that exists.
    final socket = '${where.path}/leftover.sock';
    leftBehindAt(socket);
    final tunnel = Tunnel(machineAt(socket), start: bindsAndStays(socket));
    addTearDown(tunnel.drop);

    await tunnel.raise();

    expect(tunnel.state, TunnelState.up, reason: tunnel.problem ?? '');
  });

  // Harm: a file of somebody's at the socket path is deleted, since a connect to a file is refused as to a dead socket.
  test('a plain file at the socket path survives raise and drop', () async {
    final socket = '${where.path}/a-file.sock';
    File(socket).writeAsStringSync('somebody else\'s');
    var started = false;
    final tunnel = Tunnel(
      machineAt(socket),
      start: (command) {
        started = true;
        return bindsAndStays(socket)(command);
      },
    );

    await tunnel.raise();
    await tunnel.drop();

    expect(File(socket).readAsStringSync(), 'somebody else\'s');
    expect(started, isFalse, reason: 'nothing can bind over a file');
  });

  // Harm: the socket another program put at the path after this window's ssh made its own is deleted by drop or by a
  // reconnect, as if it were the one ssh made.
  test('a socket put in place after the raise survives drop and reconnect, and still answers', () async {
    final socket = '${where.path}/replaced.sock';
    final tunnel = Tunnel(machineAt(socket), start: bindsAndStays(socket));
    await tunnel.raise();
    expect(tunnel.state, TunnelState.up, reason: tunnel.problem ?? '');

    await anotherProgramAt(socket);
    await tunnel.raise();
    expect(tunnel.problem, contains('already serving'));
    await tunnel.drop();

    expect(await answersAt(socket), isTrue, reason: 'another program\'s socket was removed');
  });

  // Harm: a socket another program bound while this window's ssh was still logging in is taken for the forward, and
  // deleted with it.
  test('a socket somebody else bound after the launch is never taken for the forward', () async {
    final socket = '${where.path}/not-ours.sock';
    final tunnel = Tunnel(
      machineAt(socket),
      start: (_) async {
        final ssh = await Process.start('sh', const <String>['-c', 'exec sleep 30']);
        await anotherProgramAt(socket);
        return ssh;
      },
      appears: const Duration(milliseconds: 600),
    );

    await tunnel.raise();
    expect(tunnel.state, TunnelState.down);
    await tunnel.drop();

    expect(await answersAt(socket), isTrue, reason: 'another program\'s socket was removed');
  });

  // Harm: a socket bound and not listening yet refuses a connect as a dead one does, and is deleted under its program.
  test('a socket that is bound and does not listen yet is no leftover', () async {
    final socket = '${where.path}/not-yet.sock';
    await anotherProgramAt(socket, listens: false);
    var started = false;
    final tunnel = Tunnel(
      machineAt(socket),
      start: (command) {
        started = true;
        return bindsAndStays(socket)(command);
      },
    );

    await tunnel.raise();
    await tunnel.drop();

    expect(tunnel.problem, contains('no leftover'));
    expect(started, isFalse);
    expect(FileSystemEntity.typeSync(socket, followLinks: false), FileSystemEntityType.unixDomainSock);
  });

  // Harm: an endpoint made where others may put files, whose leftover can later never be told from theirs.
  test('a folder others may write is refused before anything is launched', () async {
    Process.runSync('chmod', <String>['770', where.path]);
    final socket = '${where.path}/shared.sock';
    var started = false;
    final tunnel = Tunnel(
      machineAt(socket),
      start: (command) {
        started = true;
        return bindsAndStays(socket)(command);
      },
    );

    await tunnel.raise();

    expect(tunnel.state, TunnelState.down);
    expect(tunnel.problem, contains('not yours alone'));
    expect(started, isFalse);
  });

  // Harm: a leftover replaced by a live socket between the probe and the removal, and the live one deleted.
  test('a socket swapped in between the probe and the removal survives', () async {
    final socket = '${where.path}/swapped.sock';
    final theirs = '${where.path}/theirs.sock';
    leftBehindAt(socket);
    await anotherProgramAt(theirs);

    final removed = await removeLeftover(socket, afterProbe: () => File(theirs).renameSync(socket));

    expect(removed, isFalse);
    expect(await answersAt(socket), isTrue, reason: 'another program\'s socket was removed');
  });

  // Harm: ssh told by the person's config to unlink before binding deletes whatever is at the socket path.
  test("ssh never unlinks what is at the socket path before binding, whatever the person's config says", () async {
    final config = File('${where.path}/config')..writeAsStringSync('Host *\n  StreamLocalBindUnlink yes\n');
    final command = Tunnel(machineAt('${where.path}/forward.sock')).command;

    final effective = await Process.run(command.first, <String>['-G', '-F', config.path, ...command.skip(1)]);

    expect(effective.exitCode, 0, reason: '${effective.stderr}');
    expect('${effective.stdout}'.split('\n'), contains('streamlocalbindunlink no'));
  });

  // Harm: a socket bound by the launched process and never listened on is taken for the forward, though a connect to
  // it is refused, and removed at drop as the forward's own.
  test('a socket the launched process only binds is not taken for the forward, and stays', () async {
    final socket = '${where.path}/only-bound.sock';
    final tunnel = Tunnel(
      machineAt(socket),
      start: (_) => Process.start('sh', <String>[
        '-c',
        'exec python3 -c "import socket,time; s=socket.socket(socket.AF_UNIX); s.bind(\'$socket\'); time.sleep(300)"',
      ]),
      appears: const Duration(milliseconds: 600),
    );

    await tunnel.raise();
    expect(tunnel.state, TunnelState.down);
    await tunnel.drop();

    expect(FileSystemEntity.typeSync(socket, followLinks: false), FileSystemEntityType.unixDomainSock);
  });

  // Harm: an endpoint made in another account's folder, whose leftover can never be told from what that account put.
  test('a folder of another account is refused before anything is launched', () async {
    final mine = Process.runSync('id', const <String>['-u']).stdout.toString().trim();
    final owner = Process.runSync('stat', const <String>['-c', '%u', '/usr']).stdout.toString().trim();
    if (mine == owner) {
      markTestSkipped("/usr is this account's own here, so it is no folder of another account");
      return;
    }
    var started = false;
    final tunnel = Tunnel(
      machineAt('/usr/porelo-not-here.sock'),
      start: (command) {
        started = true;
        return bindsAndStays('/usr/porelo-not-here.sock')(command);
      },
    );

    await tunnel.raise();

    expect(tunnel.problem, contains('not yours alone'));
    expect(started, isFalse);
  });

  // Harm: an endpoint in a folder reached through one this account may search and not read is refused, as if it were
  // another's, and the machine can never be raised.
  test("a folder reached through one that may be searched and not read is still this account's", () {
    final through = Directory('${where.path}/search-only')..createSync();
    final folder = Directory('${through.path}/sockets')..createSync();
    Process.runSync('chmod', <String>['700', folder.path]);
    Process.runSync('chmod', <String>['311', through.path]);
    addTearDown(() => Process.runSync('chmod', <String>['700', through.path]));

    expect(inOwnDirectory('${folder.path}/forward.sock'), isTrue);
  });

  // Harm: a held socket file never let go keeps a descriptor for good, and one let go is still removed through it.
  test('a held socket file is let go on release, and nothing is removed through it after', () {
    final socket = '${where.path}/held.sock';
    leftBehindAt(socket);
    int holding() => Directory('/proc/self/fd').listSync(followLinks: false).where((fd) {
      try {
        return Link(fd.path).targetSync() == socket;
      } on FileSystemException {
        return false;
      }
    }).length;

    final held = HeldSocket.at(socket)!;
    expect(holding(), 1);
    held.release();

    expect(holding(), 0);
    expect(removeSocketIfStill(socket, held), isFalse);
    expect(FileSystemEntity.typeSync(socket, followLinks: false), FileSystemEntityType.unixDomainSock);
  });

  // Harm: where the kernel cannot be asked which sockets are bound, a socket somebody still holds is taken for a
  // leftover, or one somebody else made for the launch's own.
  test("where the kernel cannot be asked, nothing is a leftover and nothing is the launch's own", () async {
    final leftover = '${where.path}/leftover.sock';
    leftBehindAt(leftover);
    final socket = '${where.path}/its.sock';
    final ssh = await listeningAt(socket);

    expect(await removeLeftover(leftover, diagnose: () => null), isFalse);
    expect(FileSystemEntity.typeSync(leftover, followLinks: false), FileSystemEntityType.unixDomainSock);
    expect(madeBy(ssh.pid, socket, diagnose: () => null), isNull);
  });

  group('a socket whose inode shares its low 32 bits with the one ssh listens on', () {
    late Process ssh;
    late String its;

    setUp(() async {
      its = '${where.path}/its.sock';
      ssh = await listeningAt(its);
    });

    // What the kernel answers where the two inodes collide: it names a bound file's inode in 32 bits only, so ssh's
    // listener reads as bound to the other file.
    List<BoundSocket> colliding(String other) {
      final mine = socketIdentityOf(its)!, theirs = socketIdentityOf(other)!;
      return [
        for (final each in boundSockets()!)
          if (boundTo(each, mine))
            (
              socket: each.socket,
              listening: each.listening,
              file: SocketIdentity(theirs.deviceMajor, theirs.deviceMinor, theirs.inode & 0xffffffff),
            )
          else
            each,
      ];
    }

    test("ssh's own socket is held as its own", () {
      final made = madeBy(ssh.pid, its);

      expect(made, isNotNull);
      made!.release();
    });

    // Harm: a socket file nobody binds, at the path where ssh's endpoint was, is removed as ssh's own.
    test("a socket file nobody binds is not taken for ssh's own", () {
      final other = '${where.path}/other.sock';
      leftBehindAt(other);

      expect(madeBy(ssh.pid, other, diagnose: () => colliding(other)), isNull);
    });

    // Harm: another program's live socket, at the path where ssh's endpoint was, is removed as ssh's own.
    test("another program's listening socket is not taken for ssh's own", () async {
      final other = '${where.path}/other.sock';
      await anotherProgramAt(other);

      expect(madeBy(ssh.pid, other, diagnose: () => colliding(other)), isNull);
      expect(await answersAt(other), isTrue);
    });
  });

  test('a socket that answers is left alone, and the forward is refused', () async {
    // The endpoint may belong to another program of this user that happens to sit at that path.
    // Deleting it to put ours there would break it with nothing said anywhere.
    final socket = '${where.path}/somebody-elses.sock';
    final theirs = await ServerSocket.bind(InternetAddress(socket, type: InternetAddressType.unix), 0);
    addTearDown(theirs.close);
    var started = false;
    final tunnel = Tunnel(
      machineAt(socket),
      start: (_) async {
        started = true;
        return Process.start('sh', const <String>['-c', 'sleep 30']);
      },
    );
    addTearDown(tunnel.drop);

    await tunnel.raise();

    expect(tunnel.state, TunnelState.down);
    expect(tunnel.problem, contains('already serving'));
    expect(started, isFalse, reason: 'ssh was run over a live endpoint');
    expect(
      FileSystemEntity.typeSync(socket),
      FileSystemEntityType.unixDomainSock,
      reason: 'somebody else\'s endpoint was deleted',
    );
  });

  test('an endpoint anybody can read is refused, not reported as working', () async {
    // What is checked is the socket, not the exit code of `chmod`: a command that succeeded on a
    // socket that is still group-readable would be a claim the thing itself contradicts.
    final socket = '${where.path}/loose.sock';
    final tunnel = Tunnel(
      machineAt(socket),
      // Binds with no umask at all, so the socket comes up readable by everybody.
      start: (_) => Process.start('sh', <String>[
        '-c',
        'exec python3 -c "'
            'import socket,os,time;'
            'os.umask(0);'
            's=socket.socket(socket.AF_UNIX);'
            's.bind(\'$socket\');'
            's.listen(1);'
            'time.sleep(30)"',
      ]),
      // A chmod that does nothing, which is how a machine that refuses to tighten it behaves.
      run: (_) async => ProcessResult(0, 0, '', ''),
    );
    addTearDown(tunnel.drop);

    await tunnel.raise();

    expect(tunnel.state, TunnelState.down);
    expect(tunnel.problem, contains('readable by nobody but you'));
    expect(File(socket).existsSync(), isFalse, reason: 'it was left behind');
  });

  test('raising twice over does not refuse the forward to itself', () async {
    // The re-raise path: the old process is still alive and its socket still answers, and that is
    // ours rather than somebody else's.
    final socket = '${where.path}/twice.sock';
    var starts = 0;
    final tunnel = Tunnel(
      machineAt(socket),
      start: (command) {
        starts++;
        return bindsAndStays(socket)(command);
      },
    );
    addTearDown(tunnel.drop);

    await tunnel.raise();
    expect(tunnel.state, TunnelState.up);
    await tunnel.raise();

    expect(tunnel.state, TunnelState.up, reason: tunnel.problem ?? '');
    expect(starts, 2);
  });

  test('dropping it takes the process down and leaves no socket behind', () async {
    final socket = '${where.path}/dropped.sock';
    final tunnel = Tunnel(machineAt(socket), start: bindsAndStays(socket));
    await tunnel.raise();
    expect(File(socket).existsSync(), isTrue);

    await tunnel.drop();

    expect(tunnel.state, TunnelState.idle);
    expect(File(socket).existsSync(), isFalse, reason: 'closing must leave no socket file behind');
  });

  test('the endpoint it creates is readable by nobody else', () async {
    final socket = '${where.path}/private.sock';
    final tunnel = Tunnel(machineAt(socket), start: bindsAndStays(socket));
    addTearDown(tunnel.drop);

    await tunnel.raise();

    final mode = FileStat.statSync(socket).mode;
    expect(mode & 0x3F, 0, reason: 'no group or other bits');
  });

  test('a forward that drops is raised again', () async {
    final socket = '${where.path}/again.sock';
    var attempt = 0;
    final tunnel = Tunnel(
      machineAt(socket),
      // The first one dies on its own, as a forward does when the network goes; the second holds.
      start: (_) async {
        attempt++;
        return attempt == 1
            ? Process.start('sh', <String>['-c', 'echo "Connection closed" >&2; exit 255'])
            : Process.start('sh', <String>[
                '-c',
                'exec python3 -c "'
                    'import socket,time;'
                    's=socket.socket(socket.AF_UNIX);'
                    's.bind(\'$socket\');'
                    's.listen(1);'
                    'time.sleep(300)"',
              ]);
      },
    );
    addTearDown(tunnel.drop);
    final tunnels = Tunnels();

    await tunnel.raise();
    expect(tunnel.state, TunnelState.down);

    await tunnel.raise();

    expect(tunnel.state, TunnelState.up);
    expect(tunnel.raised, 2);
    tunnels.dispose();
  });

  group('what the interface owns', () {
    /// A socket somebody else serves, at a path this test owns, so its surviving means something.
    Future<String> somebodyElsesSocket(String name) async {
      final path = '${where.path}/$name';
      final server = await ServerSocket.bind(InternetAddress(path, type: InternetAddressType.unix), 0);
      addTearDown(server.close);
      return path;
    }

    bool stillServed(String path) => FileSystemEntity.typeSync(path) == FileSystemEntityType.unixDomainSock;

    test('a machine somebody else forwarded is never raised or torn down', () async {
      // The path with no credential handling in it at all. It must keep working untouched, which
      // means nothing is started for it and nothing is stopped for it.
      final tunnels = Tunnels(start: (_) => throw StateError('nothing should be started'));
      addTearDown(tunnels.dispose);
      final theirs = Machine(name: 'theirs', socketPath: await somebodyElsesSocket('theirs.sock'));

      final ready = await tunnels.raiseFor(theirs);

      expect(ready, isTrue, reason: 'it is already reachable');
      expect(tunnels.manages(theirs), isFalse);
      await tunnels.dropEverything();
      expect(
        stillServed(theirs.socketPath),
        isTrue,
        reason: 'a socket somebody else forwarded must survive closing the window',
      );
    });

    test('dropping everything takes down only what was raised here', () async {
      final socket = '${where.path}/ours.sock';
      final tunnels = Tunnels(start: bindsAndStays(socket));
      addTearDown(tunnels.dispose);
      final ours = machineAt(socket);
      final theirs = Machine(name: 'theirs', socketPath: await somebodyElsesSocket('not-ours.sock'));

      await tunnels.raiseFor(ours);
      await tunnels.raiseFor(theirs);
      expect(tunnels.manages(ours), isTrue);
      expect(tunnels.manages(theirs), isFalse);

      await tunnels.dropEverything();

      expect(File(socket).existsSync(), isFalse);
      expect(tunnels.manages(ours), isFalse);
      expect(stillServed(theirs.socketPath), isTrue);
    });
  });

  /// Starting a daemon at the far end.
  ///
  /// **The script is run, not mocked.** What can go wrong here is the line itself — a missing
  /// binary, a unit that is not there, a start that blocks because its output was never
  /// redirected — and a stand-in for `ssh` that echoed a fixed answer would prove none of it. So
  /// the far end is this machine, with `PATH` deciding what it has.
  group('starting a daemon at the far end', () {
    /// The line runs through a login shell, which reads this machine's `/etc/profile` first. A
    /// `.profile` of the test's own puts [path] back last, so a profile that sets `PATH` outright
    /// cannot hand the line this machine's real `systemctl` and `porelod`, and start a daemon here.
    Tunnels runningTheScript(String path) {
      File('${where.path}/.profile').writeAsStringSync('PATH=\'$path\'\nexport PATH\n');
      return Tunnels(
        run: (command) => Process.run(
          '/bin/sh',
          <String>['-c', command.last],
          environment: <String, String>{'PATH': path, 'HOME': where.path},
          includeParentEnvironment: false,
        ),
      );
    }

    /// A far end whose `systemctl` reports [loadState] for the unit and does [start] when asked to
    /// start it. In the test's own directory, so it shadows this machine's real one.
    void systemdThatSays(String loadState, {String start = 'exit 0'}) {
      final fake = File('${where.path}/systemctl')
        ..writeAsStringSync('#!/bin/sh\ncase "\$*" in *show*) echo $loadState ;; *start*) $start ;; esac\n');
      Process.runSync('chmod', <String>['755', fake.path]);
    }

    /// A far end whose `porelod` runs [body].
    void porelodThat(String body) {
      File('${where.path}/porelod').writeAsStringSync('#!/bin/sh\n$body\n');
      Process.runSync('chmod', <String>['755', '${where.path}/porelod']);
    }

    test('the line names the host, asks for a unit first, and never prompts', () {
      final command = Tunnels.startCommandFor(machineAt('/tmp/unused.sock'));

      expect(command.first, 'ssh');
      expect(command, contains('user@build'));
      // Batch mode, for the same reason the forward uses it: there is no terminal to prompt at.
      expect(command, contains('BatchMode=yes'));
      expect(
        command.last.indexOf('systemctl'),
        lessThan(command.last.indexOf('setsid')),
        reason: 'a supervised unit is preferred to a loose process',
      );
    });

    // This computer's own daemon is started with the same lines, here, with no login to anywhere.
    test('this computer\'s own daemon is started here, in the login shell, with no ssh', () {
      final here = Machine.local(environment: const <String, String>{});
      expect(here.isThisComputer, isTrue);

      final command = Tunnels.startCommandFor(here);

      expect(command, <String>['sh', '-c', inTheLoginShell(Tunnels.startsIt)]);
    });

    test('nothing from a machine reaches the line that is run there', () {
      // The script runs through a login shell at the far end. It is a constant, and it has to
      // stay one: a field interpolated into it would be a command injection on somebody else's
      // machine, from a dialog anybody can type into.
      const sneaky = Machine(
        name: 'innocent',
        socketPath: '/tmp/unused.sock',
        host: r'user@build; rm -rf $HOME #',
        remoteSocket: r'/run/$(whoami)/porelo/porelod.sock',
      );

      final command = Tunnels.startCommandFor(sneaky);

      // The host travels as its own argument, never inside the script.
      expect(command.last, inTheLoginShell(Tunnels.startsIt));
      expect(
        command.last,
        Tunnels.startCommandFor(machineAt('/tmp/other.sock')).last,
        reason: 'the line differs between machines, so something of theirs is in it',
      );
      expect(command.where((each) => each.contains('rm -rf')), hasLength(1));
    });

    test('a machine with no porelod on it says so, and starts nothing', () async {
      // A path with nothing on it, and deliberately not this machine's own: a far end that has no
      // daemon is the case being tested, and running the real one here would be a side effect of
      // a test.
      final bare = Directory('${where.path}/bare')..createSync();

      final started = await runningTheScript(bare.path).startPoreloOn(machineAt('/tmp/unused.sock'));

      expect(started.went, isFalse);
      expect(started.words, contains('no porelod is installed there'));
    });

    test('a machine with no unit starts it detached, and does not wait for it', () async {
      final marker = '${where.path}/it-ran';
      porelodThat('echo ran > $marker\nsleep 5');
      systemdThatSays('not-found');

      final started = await runningTheScript('${where.path}:/usr/bin:/bin')
          .startPoreloOn(machineAt('/tmp/unused.sock'));

      expect(started.went, isTrue);
      expect(started.words, contains('started porelod itself: there is no systemd unit for it'));
      // It came back while the daemon is still running, which is the whole of "detached": a start
      // that waited for the daemon to finish would hold the window for as long as it serves.
      final by = DateTime.now().add(const Duration(seconds: 5));
      while (!File(marker).existsSync() && DateTime.now().isBefore(by)) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(File(marker).existsSync(), isTrue, reason: 'it was never run at the far end');
    });

    test('a machine with a unit has systemd start it, and never runs the binary itself', () async {
      final marker = '${where.path}/binary-ran';
      porelodThat('echo ran > $marker');
      systemdThatSays('loaded');

      final started = await runningTheScript('${where.path}:/usr/bin:/bin')
          .startPoreloOn(machineAt('/tmp/unused.sock'));

      expect(started.went, isTrue);
      expect(started.words, contains('started by systemd'));
      expect(File(marker).existsSync(), isFalse, reason: 'a supervised start ran the binary as well');
    });

    // Reported: a refused start said only that nothing answered.
    test('a unit that refuses says what systemd said, and the binary is not run instead', () async {
      final marker = '${where.path}/binary-ran';
      porelodThat('echo ran > $marker\nsleep 5');
      systemdThatSays(
        'loaded',
        start: 'echo "Job for porelod.service failed because the control process exited." >&2; exit 1',
      );

      final started = await runningTheScript('${where.path}:/usr/bin:/bin')
          .startPoreloOn(machineAt('/tmp/unused.sock'));

      expect(started.went, isFalse);
      expect(started.words, contains('Job for porelod.service failed because the control process exited.'));
      expect(started.words, contains('exit 1'));
      expect(
        File(marker).existsSync(),
        isFalse,
        reason: 'a unit that refused was worked around by starting the binary behind it',
      );
    });

    test('a daemon that ends as soon as it starts is a failure, with what it wrote', () async {
      porelodThat('echo "cannot read /etc/porelo/porelod.conf" >&2\nexit 3');
      systemdThatSays('not-found');

      final started = await runningTheScript('${where.path}:/usr/bin:/bin')
          .startPoreloOn(machineAt('/tmp/unused.sock'));

      expect(started.went, isFalse);
      expect(started.words, contains('cannot read /etc/porelo/porelod.conf'));
      expect(started.words, contains('exit 3'));
      expect(started.words, isNot(contains('started porelod itself')));
    });

    test('a far end with no lingering is told what that costs, and one with it is not', () async {
      porelodThat('sleep 5');
      systemdThatSays('not-found');

      Future<String> wordsWhenLingerIs(String answer) async {
        File('${where.path}/loginctl').writeAsStringSync('#!/bin/sh\necho $answer\n');
        Process.runSync('chmod', <String>['755', '${where.path}/loginctl']);
        final started = await runningTheScript('${where.path}:/usr/bin:/bin')
            .startPoreloOn(machineAt('/tmp/unused.sock'));
        return started.words;
      }

      // A user service dies with the last session on that machine, and the forward held here is
      // one of those sessions. Said rather than discovered when the window is closed.
      expect(await wordsWhenLingerIs('no'), contains('enable-linger'));
      expect(await wordsWhenLingerIs('yes'), isNot(contains('enable-linger')));
    });

    test('a machine somebody else forwards is refused before anything is run', () async {
      var asked = false;
      final tunnels = Tunnels(
        run: (_) async {
          asked = true;
          return ProcessResult(0, 0, '', '');
        },
      );
      addTearDown(tunnels.dispose);

      final started = await tunnels.startPoreloOn(const Machine(name: 'elsewhere', socketPath: '/tmp/elsewhere.sock'));

      expect(started.went, isFalse);
      expect(asked, isFalse, reason: 'there is no host to log into');
    });

    test('ssh that cannot be run at all is a refusal, not a crash', () async {
      final tunnels = Tunnels(
        run: (_) => Future<ProcessResult>.error(const ProcessException('ssh', <String>[], 'No such file or directory')),
      );
      addTearDown(tunnels.dispose);

      final started = await tunnels.startPoreloOn(machineAt('/tmp/unused.sock'));

      expect(started.went, isFalse);
      expect(started.words, contains('No such file or directory'));
    });
  });

  /// Asking a machine which uid the login account has.
  ///
  /// ssh reports a missing daemon and somebody else's socket in the same words, so this is how a
  /// trial tells them apart. Every way it can fail must be null, never a number: a guessed uid
  /// would send somebody to a path that is just as wrong.
  group('asking a machine which uid its login has', () {
    Tunnels answering(ProcessResult result) => Tunnels(run: (_) async => result);

    test('the line is a constant, and the host travels as its own argument', () {
      final command = Tunnels.loginUidCommandFor(machineAt('/tmp/unused.sock'));

      expect(command.first, 'ssh');
      expect(command, contains('BatchMode=yes'));
      expect(command, contains('user@build'));
      expect(command.last, 'id -u');
    });

    test('the uid it prints is the answer', () async {
      final uid = await answering(ProcessResult(0, 0, '1000\n', '')).loginUidOn(machineAt('/tmp/unused.sock'));

      expect(uid, 1000);
    });

    test('a command that failed says nothing, even if something printed a number', () async {
      // The exit code is the verdict: a login banner or a wrapper can print digits and still fail.
      final uid = await answering(ProcessResult(0, 255, '1000', 'Permission denied (publickey).'))
          .loginUidOn(machineAt('/tmp/unused.sock'));

      expect(uid, isNull);
    });

    test('output that is not a number says nothing', () async {
      final uid = await answering(ProcessResult(0, 0, 'Welcome to the build host\n1000', ''))
          .loginUidOn(machineAt('/tmp/unused.sock'));

      expect(uid, isNull);
    });

    test('ssh that cannot be run at all says nothing', () async {
      final tunnels = Tunnels(
        run: (_) => Future<ProcessResult>.error(const ProcessException('ssh', <String>[], 'No such file or directory')),
      );

      expect(await tunnels.loginUidOn(machineAt('/tmp/unused.sock')), isNull);
    });

    test('a machine somebody else forwards is not asked', () async {
      var asked = false;
      final tunnels = Tunnels(
        run: (_) async {
          asked = true;
          return ProcessResult(0, 0, '1000', '');
        },
      );

      final uid = await tunnels.loginUidOn(const Machine(name: 'elsewhere', socketPath: '/tmp/elsewhere.sock'));

      expect(uid, isNull);
      expect(asked, isFalse, reason: 'there is no host to log into');
    });

    test('a refused login when asking the uid joins the key ssh would use', () async {
      Tunnels withConfig(String config) => Tunnels(
        run: (command) async => command.contains('-G')
            ? ProcessResult(0, 0, config, '')
            : ProcessResult(0, 255, '', 'user@build: Permission denied (publickey).'),
      );

      final named = withConfig('identityfile /home/alice/.ssh/porelo-build-agent\n');
      expect(await named.loginUidAt('user@build'), isNull);
      expect(
        named.lastLoginRefusal,
        allOf(
          contains('user@build accepted none of the keys'),
          contains(
            "It would log in with ~/.ssh/porelo-build-agent; "
            "that key's public half must be in the account's authorized_keys.",
          ),
        ),
      );

      final defaultsOnly = withConfig('identityfile ~/.ssh/id_ed25519\n');
      expect(await defaultsOnly.loginUidAt('user@build'), isNull);
      expect(
        defaultsOnly.lastLoginRefusal,
        allOf(contains('user@build accepted none of the keys'), contains('No key is named for user@build')),
      );
    });
  });

  // Harm: a connection that started after its probe gave up was left pending, one more for every probe.
  test('a connection that starts after its probe gave up is cancelled once it does', () async {
    var cancelled = 0;
    final late = Completer<ConnectionTask<Socket>>();

    final found = await probeSocket(
      '${where.path}/late.sock',
      (_) => late.future,
      within: const Duration(milliseconds: 50),
    );
    late.complete(ConnectionTask.fromSocket(Completer<Socket>().future, () => cancelled++));
    await pumpEventQueue();

    expect(found, SocketProbe.unknown);
    expect(cancelled, 1);
  });

  // Harm: a socket removed as nobody's on an error that proves nothing, or kept for good on one that proves it.
  test('a bare OSError from a probe says nobody only where it proves nothing listens', () async {
    Future<SocketProbe> failing(int errno) =>
        probeSocket('${where.path}/bare.sock', (_) async => throw OSError('failed', errno));
    expect(await failing(111), SocketProbe.nobody, reason: 'ECONNREFUSED');
    expect(await failing(2), SocketProbe.nobody, reason: 'ENOENT');
    expect(await failing(24), SocketProbe.unknown, reason: 'EMFILE proves nothing about the endpoint');
    expect(await failing(13), SocketProbe.unknown, reason: 'EACCES proves nothing about the endpoint');
  });

  group('a forward a run that ended without asking left behind', _leftBehind);
}

/// The forwards a run that ended without asking left behind: found again by their record, and nothing else ended.
void _leftBehind() {
  late Directory where;
  late String records;
  late List<Process> started;
  late Set<Process> ended;

  setUp(() {
    ended = <Process>{};
    where = Directory.systemTemp.createTempSync('lb-');
    // As XDG_RUNTIME_DIR is: the records' parent is this account's alone.
    Process.runSync('chmod', <String>['700', where.path]);
    records = '${where.path}/records';
    started = <Process>[];
  });

  tearDown(() async {
    for (final process in started) {
      process.kill(ProcessSignal.sigkill);
      await process.exitCode;
    }
    where.deleteSync(recursive: true);
  });

  Machine machineAt(String socket) => Machine(
    name: 'the build machine',
    socketPath: socket,
    host: 'user@build',
    remoteSocket: '/run/user/1001/porelo/porelod.sock',
  );

  /// A process serving [socket] whose own command line forwards [forwarding] as ssh's would; it ignores SIGTERM where
  /// [stubborn].
  Future<({Process process, List<String> command})> serving(
    String socket, {
    String? forwarding,
    bool stubborn = false,
    bool slow = false,
    List<String> more = const <String>[],
  }) async {
    final command = <String>[
      'python3',
      '-c',
      'import socket,time,signal,sys;'
          '${stubborn ? 'signal.signal(signal.SIGTERM,signal.SIG_IGN);' : ''}'
          // Ends a second after it was asked to, still answering meanwhile.
          '${slow ? 'signal.signal(signal.SIGTERM,lambda *_:(time.sleep(1),sys.exit(0)));' : ''}'
          's=socket.socket(socket.AF_UNIX);s.bind("$socket");s.listen(8);time.sleep(300)',
      '-L',
      '${forwarding ?? socket}:/run/user/1001/porelo/porelod.sock',
      'user@build',
      ...more,
    ];
    final process = await Process.start(command.first, command.sublist(1));
    started.add(process);
    unawaited(process.exitCode.then((_) => ended.add(process)));
    for (var i = 0; i < 100 && FileSystemEntity.typeSync(socket) != FileSystemEntityType.unixDomainSock; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    return (process: process, command: command);
  }

  /// Whether [process] is still running after a moment.
  Future<bool> alive(Process process) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return !ended.contains(process);
  }

  /// A forward a run of this interface raised at [socket] and recorded, then ended without asking.
  Future<Process> leftBy(
    ForwardRecords earlier,
    String socket, {
    String? forwarding,
    bool stubborn = false,
    bool slow = false,
  }) async {
    final left = await serving(socket, forwarding: forwarding, stubborn: stubborn, slow: slow);
    earlier.record(left.process.pid, left.command);
    return left.process;
  }

  Future<Tunnel> raisedAgain(String socket, ForwardRecords now) async {
    final tunnel = Tunnel(machineAt(socket), records: now, start: (_) async => (await serving(socket)).process);
    addTearDown(tunnel.drop);
    await tunnel.raise();
    return tunnel;
  }

  // Harm: after a kill or `q`, a machine shown down at every later start while the forward it left still serves.
  test('a forward a killed run left at the socket is ended and the machine raised', () async {
    final socket = '${where.path}/left.sock';
    final left = await leftBy(ForwardRecords(records), socket);

    final tunnel = await raisedAgain(socket, ForwardRecords(records));

    expect(tunnel.problem, isNull);
    expect(tunnel.state, TunnelState.up);
    expect(await alive(left), isFalse, reason: 'the forward left behind was ended');
  });

  // Harm: another program of this person that sits at the socket path ended by the window.
  test('an answering socket with no record of ours is still left alone', () async {
    final socket = '${where.path}/theirs.sock';
    final theirs = (await serving(socket)).process;

    final tunnel = await raisedAgain(socket, ForwardRecords(records));

    expect(tunnel.state, TunnelState.down);
    expect(tunnel.problem, contains('already serving'));
    expect(await alive(theirs), isTrue);
  });

  /// Whether something accepts a connection at [socket] now.
  Future<bool> answersAt(String socket) async {
    try {
      (await Socket.connect(InternetAddress(socket, type: InternetAddressType.unix), 0)).destroy();
      return true;
    } on SocketException {
      return false;
    }
  }

  // Harm: another program's endpoint unlinked by the window, so nobody can connect to it any more.
  test('an endpoint refused as somebody else’s still answers after the tunnel is dropped', () async {
    final socket = '${where.path}/kept.sock';
    final theirs = (await serving(socket)).process;
    final tunnel = await raisedAgain(socket, ForwardRecords(records));
    expect(tunnel.problem, contains('already serving'));

    await tunnel.drop();

    expect(await answersAt(socket), isTrue, reason: 'their endpoint is still there to connect to');
    expect(await alive(theirs), isTrue);
  });

  // Harm: a live endpoint unlinked because a probe failed here, such as with too many open files.
  test('a probe that fails for a reason of its own never removes the endpoint', () async {
    final socket = '${where.path}/unprobed.sock';
    final theirs = (await serving(socket)).process;
    final tunnel = Tunnel(
      machineAt(socket),
      records: ForwardRecords(records),
      start: (_) async => (await serving(socket)).process,
      connect: (_) async => throw const SocketException('probe', osError: OSError('Too many open files', 24)),
    );
    addTearDown(tunnel.drop);

    await tunnel.raise();

    expect(tunnel.state, TunnelState.down);
    expect(tunnel.problem, contains('could not be told'));
    expect(await answersAt(socket), isTrue, reason: 'their endpoint is still there to connect to');
    expect(await alive(theirs), isTrue);
  });

  // Harm: a pending connection kept for every raise of a machine whose endpoint never answers.
  test('a probe that gets no answer in time is cancelled and the endpoint left alone', () async {
    final socket = '${where.path}/silent.sock';
    final theirs = (await serving(socket)).process;
    var cancelled = 0;
    final tunnel = Tunnel(
      machineAt(socket),
      records: ForwardRecords(records),
      start: (_) async => (await serving(socket)).process,
      connect: (_) async => ConnectionTask.fromSocket(Completer<Socket>().future, () => cancelled++),
    );
    addTearDown(tunnel.drop);

    await tunnel.raise();

    expect(cancelled, 1);
    expect(tunnel.state, TunnelState.down);
    expect(await answersAt(socket), isTrue);
    expect(await alive(theirs), isTrue);
  });

  /// [tunnel] refused the endpoint as served by somebody else, and [left] still runs.
  Future<void> leftAlone(Tunnel tunnel, Process left) async {
    expect(tunnel.state, TunnelState.down);
    expect(tunnel.problem, contains('already serving'));
    expect(await alive(left), isTrue, reason: 'nothing provably ours was there to end');
  }

  // Harm, for each guard below: a process that is not the forward this interface left, ended by its pid.
  test('a recorded pid that now runs another command line is not ended', () async {
    final socket = '${where.path}/other-line.sock';
    final left = await serving(socket);
    ForwardRecords(records).record(left.process.pid, <String>[...left.command, 'more']);

    await leftAlone(await raisedAgain(socket, ForwardRecords(records)), left.process);
  });

  test('a recorded pid with another start time is not ended', () async {
    final socket = '${where.path}/other-start.sock';
    final left = await leftBy(ForwardRecords(records, table: _Told(startTime: '1')), socket);

    await leftAlone(await raisedAgain(socket, ForwardRecords(records)), left);
  });

  test('a recorded pid of another boot is not ended', () async {
    final socket = '${where.path}/other-boot.sock';
    final left = await leftBy(ForwardRecords(records, table: _Told(bootId: 'another boot')), socket);

    await leftAlone(await raisedAgain(socket, ForwardRecords(records)), left);
  });

  test('a recorded forward of another socket is not ended for this one', () async {
    final socket = '${where.path}/this.sock';
    final left = await leftBy(ForwardRecords(records), socket, forwarding: '${where.path}/that.sock');

    await leftAlone(await raisedAgain(socket, ForwardRecords(records)), left);
  });

  test('a recorded pid that runs as another account is not ended', () async {
    final socket = '${where.path}/other-account.sock';
    final left = await leftBy(ForwardRecords(records), socket);
    final me = const LinuxProcessTable().myUid!;

    await leftAlone(await raisedAgain(socket, ForwardRecords(records, table: _Told(owner: me + 1))), left);
  });

  test('without a pidfd nothing is ended, never by a bare pid', () async {
    final socket = '${where.path}/no-pidfd.sock';
    final left = await leftBy(ForwardRecords(records), socket);

    await leftAlone(await raisedAgain(socket, ForwardRecords(records, table: _Told(pins: false))), left);
  });

  test('a record owned by another uid is ignored', () async {
    final socket = '${where.path}/foreign.sock';
    final left = await leftBy(ForwardRecords(records), socket);
    PathFacts? foreign(String path, int? descriptor) => switch (pathFactsOf(path, descriptor)) {
      final facts? when path.endsWith('.forward') => PathFacts(
        owner: facts.owner + 1,
        permissions: facts.permissions,
        type: facts.type,
      ),
      final facts => facts,
    };

    await leftAlone(await raisedAgain(socket, ForwardRecords(records, facts: foreign)), left);
  });

  test('a record wider than 0600 is ignored', () async {
    final socket = '${where.path}/wide.sock';
    final left = await leftBy(ForwardRecords(records), socket);
    Process.runSync('chmod', <String>['640', '$records/${left.pid}.forward']);

    await leftAlone(await raisedAgain(socket, ForwardRecords(records)), left);
  });

  test('a record that is a link is ignored', () async {
    final socket = '${where.path}/linked.sock';
    final left = await leftBy(ForwardRecords(records), socket);
    final record = '$records/${left.pid}.forward';
    File(record).renameSync('${where.path}/elsewhere');
    Link(record).createSync('${where.path}/elsewhere');

    await leftAlone(await raisedAgain(socket, ForwardRecords(records)), left);
  });

  test('records in a directory others may write are ignored', () async {
    final socket = '${where.path}/shared.sock';
    final left = await leftBy(ForwardRecords(records), socket);
    Process.runSync('chmod', <String>['770', records]);

    await leftAlone(await raisedAgain(socket, ForwardRecords(records)), left);
  });

  test('records in a directory others may read are ignored', () async {
    final socket = '${where.path}/readable.sock';
    final left = await leftBy(ForwardRecords(records), socket);
    Process.runSync('chmod', <String>['750', records]);

    await leftAlone(await raisedAgain(socket, ForwardRecords(records)), left);
  });

  test('records under a runtime directory that is not 0700 are ignored', () async {
    final socket = '${where.path}/open-runtime.sock';
    final left = await leftBy(ForwardRecords(records), socket);
    Process.runSync('chmod', <String>['750', where.path]);

    await leftAlone(await raisedAgain(socket, ForwardRecords(records)), left);
  });

  test('a pid this run holds is not ended', () async {
    final socket = '${where.path}/held.sock';
    final now = ForwardRecords(records);
    final left = await leftBy(now, socket);

    await leftAlone(await raisedAgain(socket, now), left);
  });

  // Harm: a start that waits without end, or a SIGKILL sent where SIGTERM was not heeded.
  test('an endpoint still answered after the end is refused after a bounded wait, and nothing is killed', () async {
    final socket = '${where.path}/stubborn.sock';
    final left = await leftBy(ForwardRecords(records), socket, stubborn: true);
    final began = DateTime.now();

    final tunnel = await raisedAgain(socket, ForwardRecords(records));

    expect(DateTime.now().difference(began), lessThan(const Duration(seconds: 5)));
    await leftAlone(tunnel, left);
    // Harm: an ssh that ignored the end forgotten, and never found again.
    expect(File('$records/${left.pid}.forward').existsSync(), isTrue, reason: 'it is still running, so still recorded');
  });

  // Harm: an endpoint that answered all along called one nobody could tell, because the wait's last probe had only the
  // few milliseconds left of the deadline and a loaded machine answered it late.
  test(
    'an endpoint that answered during the wait is said to be served though the last probe ran out of time',
    () async {
      final socket = '${where.path}/answered.sock';
      final left = await leftBy(ForwardRecords(records), socket, stubborn: true);
      var probes = 0;
      final tunnel = Tunnel(
        machineAt(socket),
        records: ForwardRecords(records),
        start: (_) async => (await serving(socket)).process,
        connect: (path) async =>
            ++probes == 1 ? connectToSocket(path) : ConnectionTask.fromSocket(Completer<Socket>().future, () {}),
      );
      addTearDown(tunnel.drop);

      await tunnel.raise();

      expect(probes, greaterThan(1), reason: 'the leftover was waited for');
      await leftAlone(tunnel, left);
    },
  );

  // Harm: a machine refused because the start did not wait for a leftover that takes a moment to end.
  test('a leftover that takes a moment to end is waited for, and the machine raised', () async {
    final socket = '${where.path}/slow.sock';
    final left = await leftBy(ForwardRecords(records), socket, slow: true);

    final tunnel = await raisedAgain(socket, ForwardRecords(records));

    expect(tunnel.problem, isNull);
    expect(tunnel.state, TunnelState.up);
    expect(await alive(left), isFalse);
  });

  test('a recorded pid whose program differs only in argv[0] is not ended', () async {
    final socket = '${where.path}/argv0.sock';
    final left = await serving(socket);
    ForwardRecords(records).record(left.process.pid, <String>['python', ...left.command.skip(1)]);

    await leftAlone(await raisedAgain(socket, ForwardRecords(records)), left.process);
  });

  for (final (joint, name) in [('\u0000', 'a NUL'), (' ', 'a space')]) {
    test('a recorded argument that joins two running ones with $name is not ended', () async {
      final socket = '${where.path}/joined-${name.length}.sock';
      final left = await serving(socket, more: <String>['x', 'y']);
      final recorded = <String>[...left.command.take(left.command.length - 2), 'x${joint}y'];
      ForwardRecords(records).record(left.process.pid, recorded);

      await leftAlone(await raisedAgain(socket, ForwardRecords(records)), left.process);
    });
  }

  // The pid ended and was taken by another process between the check and the pidfd: what the pidfd holds is checked.
  test('a pid taken by another process before it is pinned is not ended', () async {
    final socket = '${where.path}/reused.sock';
    final left = await leftBy(ForwardRecords(records), socket);

    await leftAlone(await raisedAgain(socket, ForwardRecords(records, table: _Told(reusedOnPin: true))), left);
  });

  // Harm: a live forward forgotten because it could not be read once, and never found again.
  test('a record whose process cannot be read, or of a boot that cannot be told, stays', () async {
    final left = await leftBy(ForwardRecords(records), '${where.path}/unread.sock');

    ForwardRecords(records, table: _Told(unreadable: true)).removeStale();
    ForwardRecords(records, table: _Told(noBoot: true)).removeStale();

    expect(File('$records/${left.pid}.forward').existsSync(), isTrue);
  });

  // Harm: records read from, or written to, wherever a link above the runtime directory points.
  test('records under a runtime directory reached through a link are ignored', () async {
    Directory('${where.path}/real/run').createSync(recursive: true);
    Process.runSync('chmod', <String>['700', '${where.path}/real/run']);
    Link('${where.path}/link').createSync('${where.path}/real');
    final socket = '${where.path}/linked-runtime.sock';
    final left = await leftBy(ForwardRecords('${where.path}/real/run/records'), socket);

    await leftAlone(await raisedAgain(socket, ForwardRecords('${where.path}/link/run/records')), left);
  });

  // Harm: a pidfd kept open for every leftover that was looked at and not ended.
  test('a pidfd is let go also where the pid is not ended', () async {
    final me = const LinuxProcessTable().myUid!;
    for (final table in [_Told(owner: me + 1), _Told(reusedOnPin: true)]) {
      final socket = '${where.path}/rejected-${table.reusedOnPin}.sock';
      await leftBy(ForwardRecords(records), socket);

      await raisedAgain(socket, ForwardRecords(records, table: table));

      expect(table.pinned, 1);
      expect(table.released, 1);
    }
  });

  // Harm: a pidfd per leftover kept open for the window's whole life.
  test('every pidfd taken is let go', () async {
    final socket = '${where.path}/released.sock';
    await leftBy(ForwardRecords(records), socket);
    final table = _Told();

    await raisedAgain(socket, ForwardRecords(records, table: table));

    expect(table.pinned, 1);
    expect(table.released, table.pinned);
  });

  test('a record replaced after it was checked is not what is read', () async {
    final socket = '${where.path}/replaced.sock';
    final left = await serving(socket);
    // The record as listed and checked names other arguments; what replaces it would name this very forward.
    ForwardRecords(records).record(left.process.pid, <String>[...left.command, 'other']);
    final record = '$records/${left.process.pid}.forward';
    final forged = '${where.path}/forged';
    ForwardRecords('${where.path}/forging').record(left.process.pid, left.command);
    File('${where.path}/forging/${left.process.pid}.forward').copySync(forged);
    final now = ForwardRecords(records)
      ..afterChecking = (name) {
        File(record).deleteSync();
        Link(record).createSync(forged);
      };

    await leftAlone(await raisedAgain(socket, now), left.process);
  });

  // Harm: a record left for a forward that ended normally, to be matched against whatever later takes its pid.
  test('a record is gone after a normal close', () async {
    final socket = '${where.path}/closed.sock';
    final tunnel = await raisedAgain(socket, ForwardRecords(records));
    expect(tunnel.state, TunnelState.up);
    expect(Directory(records).listSync().where((each) => each.path.endsWith('.forward')), hasLength(1));

    await tunnel.drop();

    expect(Directory(records).listSync().where((each) => each.path.endsWith('.forward')), isEmpty);
  });

  // Harm: records read from, or written to, a directory another account owns, though its mode is 0700.
  test('records in a directory another account owns are ignored', () async {
    final socket = '${where.path}/owned.sock';
    final left = await leftBy(ForwardRecords(records), socket);
    PathFacts? foreign(String path, int? descriptor) => switch (pathFactsOf(path, descriptor)) {
      final facts? when path == records => PathFacts(
        owner: facts.owner + 1,
        permissions: facts.permissions,
        type: facts.type,
      ),
      final facts => facts,
    };

    await leftAlone(await raisedAgain(socket, ForwardRecords(records, facts: foreign)), left);
  });

  // Harm: a process whose arguments cannot be read taken for the recorded forward and ended, or its record dropped.
  test('a recorded pid whose arguments cannot be read is not ended, and its record stays', () async {
    final socket = '${where.path}/no-arguments.sock';
    final left = await leftBy(ForwardRecords(records), socket);

    await leftAlone(await raisedAgain(socket, ForwardRecords(records, table: _Told(noArguments: true))), left);
    ForwardRecords(records, table: _Told(noArguments: true)).removeStale();
    expect(File('$records/${left.pid}.forward').existsSync(), isTrue);
  });

  // Harm: a live forward's record dropped because a lookup of its process failed, and the forward never found again.
  test('a record stays where the lookup of its process fails, and goes once its process is gone', () async {
    final ended = await Process.start('true', const <String>[]);
    await ended.exitCode;
    // The process is gone, so its record is written as a run that recorded it while it ran would have left it.
    final record = File('$records/${ended.pid}.forward');
    Directory(records).createSync();
    Process.runSync('chmod', <String>['700', records]);
    record.writeAsStringSync(
      jsonEncode(<String, Object>{
        'pid': ended.pid,
        'boot': const LinuxProcessTable().bootId!,
        'start': '1',
        'command': <String>['true'],
      }),
    );
    Process.runSync('chmod', <String>['600', record.path]);
    int denied(String path) => path == '/proc/self' ? 0 : 13;

    ForwardRecords(records, table: LinuxProcessTable(statOf: denied)).removeStale();
    expect(record.existsSync(), isTrue, reason: 'EACCES proves nothing about the process');

    ForwardRecords(records).removeStale();
    expect(record.existsSync(), isFalse, reason: 'the process is gone');
  });

  // Harm: a failed lookup, or a computer with no process table to read, taken as a process that ended.
  test('only ENOENT or ESRCH says a process is gone, and only where the table can be read', () {
    LinuxProcessTable answering(int self, int other) =>
        LinuxProcessTable(statOf: (path) => path == '/proc/self' ? self : other);
    expect(answering(0, 2).isGone(1), isTrue);
    expect(answering(0, 3).isGone(1), isTrue);
    expect(answering(0, 13).isGone(1), isFalse);
    expect(answering(0, 12).isGone(1), isFalse);
    expect(answering(2, 2).isGone(1), isFalse, reason: 'no /proc to read');
    expect(const LinuxProcessTable().isGone(pid), isFalse, reason: 'this very process');
  });

  /// The descriptors this process holds now on the test's directories; others come and go with the test's own I/O.
  List<String> descriptors() => <String>[
    for (final each in Directory('/proc/self/fd').listSync(followLinks: false))
      if (each is Link)
        if (_targetOf(each) case final target? when target.startsWith(where.path)) target,
  ];

  // Harm: a directory descriptor, or a temporary record, left behind by every record written while memory ran out.
  test('no descriptor and no temporary record is kept when an allocation fails', () {
    final deep = '${where.path}/a/b/records';
    Directory('${where.path}/a/b').createSync(recursive: true);
    Process.runSync('chmod', <String>['700', '${where.path}/a/b']);
    final writing = ForwardRecords(deep);
    var failed = 0;
    for (var failing = 1; failing < 60; failing++) {
      var count = 0;
      final before = descriptors();
      allocationFails = () => ++count == failing;
      try {
        writing.record(pid, <String>['ssh', '-N', '$failing']);
      } on FileSystemException {
        failed++;
      } finally {
        allocationFails = null;
      }
      expect(descriptors(), unorderedEquals(before), reason: 'allocation $failing failed and a descriptor was kept');
      final dir = Directory(deep);
      if (dir.existsSync()) {
        expect(
          dir.listSync().map((each) => each.path.split('/').last).where((name) => name.startsWith('.')),
          isEmpty,
          reason: 'allocation $failing failed and a temporary record was kept',
        );
      }
      writing.forget(pid);
    }
    expect(failed, greaterThan(5), reason: 'the allocations of the chain and the write were each made to fail');
  });

  // Harm: tunnels whose ssh ignores the end stopped one after another, so the last of three still ran past the
  // window's five seconds and was never killed.
  test('every tunnel is killed within the bound however many ignore the end', () async {
    final tunnels = Tunnels(
      start: (command) async {
        final socket = command[command.indexOf('-L') + 1].split(':').first;
        return (await serving(socket, stubborn: true)).process;
      },
    );
    addTearDown(tunnels.dispose);
    final mine = <Process>[];
    for (final name in ['one', 'two', 'three']) {
      final machine = Machine(
        name: name,
        socketPath: '${where.path}/$name.sock',
        host: 'user@build',
        remoteSocket: '/run/user/1001/porelo/porelod.sock',
      );
      expect(await tunnels.raiseFor(machine), isTrue);
      mine.add(started.last);
    }

    await letGoTogether(<Future<void> Function()>[tunnels.dropEverything]);

    for (final process in mine) {
      expect(ended.contains(process), isTrue, reason: 'each was killed within the five seconds');
    }
  });
}

/// Where [link] points, or null where it went meanwhile, as a descriptor of the test's own I/O may.
String? _targetOf(Link link) {
  try {
    return link.targetSync();
  } on FileSystemException {
    return null;
  }
}

/// The real process table, except for what a test tells it to say instead.
class _Told implements ProcessTable {
  _Told({
    this.startTime,
    String? bootId,
    this.owner,
    this.pins = true,
    this.reusedOnPin = false,
    this.unreadable = false,
    this.noBoot = false,
    this.noArguments = false,
  }) : _boot = bootId;

  /// Its arguments cannot be read, though it runs and its start time can be.
  final bool noArguments;

  /// Its start time and arguments cannot be read, though it runs.
  final bool unreadable;

  /// This boot cannot be told.
  final bool noBoot;

  static const _real = LinuxProcessTable();
  final String? startTime;
  final String? _boot;
  final int? owner;
  final bool pins;

  /// Once pinned, the pid is another process: one started later.
  final bool reusedOnPin;
  int pinned = 0;
  int released = 0;

  @override
  int? get myUid => _real.myUid;

  @override
  String? get bootId => noBoot ? null : _boot ?? _real.bootId;

  @override
  bool isGone(int pid) => _real.isGone(pid);

  @override
  int? ownerOf(int pid) => owner ?? _real.ownerOf(pid);

  @override
  String? startTimeOf(int pid) =>
      unreadable ? null : startTime ?? (reusedOnPin && pinned > 0 ? '1' : _real.startTimeOf(pid));

  @override
  List<String>? argumentsOf(int pid) => unreadable || noArguments ? null : _real.argumentsOf(pid);

  @override
  PinnedProcess? pin(int pid) {
    final real = pins ? _real.pin(pid) : null;
    if (real == null) return null;
    pinned++;
    return _Counted(real, () => released++);
  }
}

class _Counted implements PinnedProcess {
  _Counted(this._real, this._released);

  final PinnedProcess _real;
  final void Function() _released;

  @override
  bool terminate() => _real.terminate();

  @override
  void release() {
    _released();
    _real.release();
  }
}

class _ControlledProcess extends Fake implements Process {
  final _errors = StreamController<List<int>>();
  final _exit = Completer<int>();

  void end(String words) {
    _errors.add(utf8.encode(words));
    unawaited(_errors.close());
    _exit.complete(255);
  }

  @override
  Stream<List<int>> get stderr => _errors.stream;

  @override
  Stream<List<int>> get stdout => const Stream.empty();

  @override
  Future<int> get exitCode => _exit.future;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    if (!_exit.isCompleted) end('');
    return true;
  }
}
