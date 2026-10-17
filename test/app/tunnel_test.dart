// Linux only: it forwards unix sockets with ssh and sh, which dart:io cannot open on Windows.
@Tags(<String>['linux'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/connections.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/tunnel.dart';

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
    where = Directory.systemTemp.createTempSync('porelo-tunnel-test');
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
    final tunnel = Tunnel(machineAt('${where.path}/refused.sock'), start: failsSaying('Host key verification failed.'));

    await tunnel.raise();

    // ssh's own words. "Host key verification failed" is a different problem from a machine that
    // is not there, and reporting the second sends somebody looking in the wrong place.
    expect(tunnel.state, TunnelState.down);
    expect(tunnel.problem, contains('Host key verification failed'));
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
    expect(tunnel.problem, contains('did not appear'));
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
    expect(tunnel.problem, contains('did not appear'));
  });

  test('a socket left by a run that died is taken over, not surrendered to', () async {
    // Otherwise one crash means the machine can never be opened again without somebody knowing to
    // delete a file they have never heard of. ssh refuses to bind a path that exists.
    final socket = '${where.path}/leftover.sock';
    File(socket).writeAsStringSync('');
    final tunnel = Tunnel(machineAt(socket), start: bindsAndStays(socket));
    addTearDown(tunnel.drop);

    await tunnel.raise();

    expect(tunnel.state, TunnelState.up);
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
      expect(started.words, contains('forwarded by somebody else'));
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
  });
}
