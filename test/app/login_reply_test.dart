import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/forward_records.dart';
import 'package:porelo_frontend/src/app/login_forward.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/person_only_relay.dart';
import 'package:porelo_frontend/src/app/pty.dart';
import 'package:porelo_frontend/src/app/session.dart';
import 'package:porelo_host/porelo_host.dart' show HostCardSsh;

import '../features/support/world.dart';

/// A login's reply reaches the machine through a forward the login terminal asks for — and only a
/// login terminal, for one port, while it is open.
void main() {
  final withSsh = raiseLoginForward;
  const vm = Machine(name: 'vm', socketPath: '/tmp/vm.sock', host: 'alice@vm', remoteSocket: '/run/s.sock');
  late List<({Machine machine, int port})> raised;
  late List<int> closed;
  late FakeTerminal far;

  Session login({bool forwards = true}) => Session(
    task: 'login',
    machine: vm,
    run: const <String>['ssh', '-t', 'alice@vm', 'porelo', 'vault', 'login', 'claude'],
    forwardsALoginReply: forwards,
    open: (executable, arguments, {columns = 80, rows = 24}) => far = FakeTerminal(<String>[executable, ...arguments]),
  );

  // What one test raised and kept is not the next one's to find.
  tearDown(letGoOfTheForwards);

  setUp(() {
    raised = <({Machine machine, int port})>[];
    closed = <int>[];
    raiseLoginForward = (machine, port) async {
      raised.add((machine: machine, port: port));
      return _Recorded(() => closed.add(port));
    };
  });

  Future<void> said(String words) async {
    far.prints(words);
    await pumpEventQueue();
  }

  test('the port a login names is forwarded to the same port on its machine, and taken down after', () async {
    final session = login();
    await said('\x1b]5379;forward;42017\x1b\\');

    expect(raised, <({Machine machine, int port})>[(machine: vm, port: 42017)]);
    expect(session.forwarded, 42017);
    await session.leave();
    expect(closed, <int>[42017]);
  });

  // Harm: a terminal left open, its program and handles with it, because its login's forward would not close, and an
  // error nobody handles.
  test('a forward that will not close leaves the terminal closed all the same', () async {
    raiseLoginForward = (machine, port) async => _Recorded(() => throw StateError('the forward would not close'));
    final session = login();
    await said('\x1b]5379;forward;42017\x1b\\');

    await session.leave();
    expect(far.closed, isTrue);

    final disposed = login();
    await said('\x1b]5379;forward;42018\x1b\\');
    disposed.dispose();
    await pumpEventQueue();
    expect(far.closed, isTrue);
  });

  // Harm: a terminal that was left still taken for one that can be typed into.
  test('a session left or put away is no longer live', () async {
    final left = login();
    expect(left.live, isTrue);
    await left.leave();
    expect(left.live, isFalse);

    final disposed = login();
    disposed.dispose();
    expect(disposed.live, isFalse);
  });

  test('a login that ends takes its forward down with it', () async {
    final session = login();
    await said('\x1b]5379;forward;42017\x1b\\');
    far.endsWith(0);
    await pumpEventQueue();

    expect(closed, <int>[42017]);
    expect(session.state, SessionState.over);
  });

  test('a terminal that is no login never opens a way from here into the machine', () async {
    login(forwards: false);
    await said('\x1b]5379;forward;42017\x1b\\');

    expect(raised, isEmpty);
  });

  test('one port, once, and never a privileged one', () async {
    final session = login();
    await said('\x1b]5379;forward;22\x1b\\');
    expect(raised, isEmpty, reason: 'a privileged port is not a login reply');
    await said('\x1b]5379;forward;42017\x1b\\\x1b]5379;forward;42018\x1b\\');

    expect(raised.map((each) => each.port), <int>[42017]);
    expect(session.forwarded, 42017);
  });

  test('a port already in use here is said before anything is started', () async {
    final taken = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(taken.close);
    final private = Directory.systemTemp.createTempSync('lp-');
    addTearDown(() => private.deleteSync(recursive: true));
    Process.runSync('chmod', <String>['700', private.path]);
    final bindBefore = PersonOnlyRelay.bindPort;
    addTearDown(() => PersonOnlyRelay.bindPort = bindBefore);
    PersonOnlyRelay.bindPort = PersonOnlyRelay.bindExclusive;

    await expectLater(
      withSsh(
        Machine(name: 'vm', socketPath: '${private.path}/vm.sock', host: 'alice@vm', remoteSocket: '/run/s.sock'),
        taken.port,
      ),
      throwsA(
        isA<ForwardRefused>().having((refused) => refused.words, 'words', contains('already in use on this computer')),
      ),
    );
  });

  test("this computer's own daemon needs nothing forwarded: the reply lands on its listener", () async {
    final here = Machine.local();
    final held = await withSsh(here, 42017);
    await held.close();
  });

  test('a port that cannot be forwarded is said, and nothing is claimed to be forwarded', () async {
    raiseLoginForward = (machine, port) async =>
        throw const ForwardRefused('Port 42017 is already in use on this computer.');
    final session = login();
    await said('\x1b]5379;forward;42017\x1b\\');

    expect(session.forwarded, isNull);
    expect(session.forwardProblem, contains('already in use'));
  });

  // Harm: a terminal whose window went away still acting on what its closing program prints: a use of the disposed
  // session thrown into its output, the desktop's clipboard overwritten, or a forward raised for nobody.
  test(
    'a session that was disposed takes no link, copy or forward from what its program prints while it closes',
    () async {
      final before = copyToClipboard;
      final copied = <String>[];
      copyToClipboard = (text) async => copied.add(text);
      addTearDown(() => copyToClipboard = before);
      final closing = _SlowToClose();
      final session = Session(
        task: 'login',
        machine: vm,
        run: const <String>['porelo', 'vault', 'login', 'claude'],
        forwardsALoginReply: true,
        open: (executable, arguments, {columns = 80, rows = 24}) => closing,
      );
      var told = 0;
      session.addListener(() => told++);

      session.dispose();
      closing.prints(
        '\x1b]8;;https://example.org/login\x1b\\here\x1b]8;;\x1b\\'
        '\x1b]52;c;${base64.encode(utf8.encode('secret'))}\x1b\\'
        '\x1b]5379;forward;42017\x1b\\',
      );
      await pumpEventQueue();
      closing.closed.complete();
      await pumpEventQueue();

      expect([told, copied, raised, session.links], [0, isEmpty, isEmpty, isEmpty]);
    },
  );

  // Measured: a forward still held when the run ended kept its ssh, and its port,
  // after the interface was gone.
  test('the window closing takes down every forward still held, and one taken down already only once', () async {
    final homeserver = await raiseForward(vm, 8009);
    final grant = await raiseForward(vm, 9420);
    await grant.close();

    await letGoOfTheForwards();

    expect(closed, <int>[9420, 8009]);
    await homeserver.close();
    expect(closed, <int>[9420, 8009], reason: 'taken down twice');
  });

  // Harm: the forwards after one that is slow to end left running when the window's time to close is up.
  test('the window closing takes every forward down at once, one that hangs holding none up', () async {
    final hanging = Completer<void>();
    raiseLoginForward = (machine, port) async =>
        port == 8009 ? _Hanging(hanging.future) : _Recorded(() => closed.add(port));
    await raiseForward(vm, 8009);
    await raiseForward(vm, 9420);

    unawaited(letGoOfTheForwards());
    await pumpEventQueue();

    expect(closed, <int>[9420]);
    hanging.complete();
  });

  group(
    'a login forward a run that ended without asking left behind',
    () {
      late Directory where;
      late String records;
      late List<Process> started;
      late Set<Process> ended;
      late Machine here;
      final startedBefore = startLoginForward;
      final masterBefore = cardMaster;
      final bindBefore = PersonOnlyRelay.bindPort;

      setUp(() async {
        where = Directory.systemTemp.createTempSync('lf-');
        // As XDG_RUNTIME_DIR is: the records' parent is this account's alone.
        Process.runSync('chmod', <String>['700', where.path]);
        records = '${where.path}/records';
        started = <Process>[];
        ended = <Process>{};
        // Its socket beside the machine's, in a folder of this account's alone, as the runtime directory is.
        here = Machine(name: 'vm', socketPath: '${where.path}/vm.sock', host: 'alice@vm', remoteSocket: '/run/s.sock');
        // The port asked for, held by the window as it is outside a test.
        PersonOnlyRelay.bindPort = PersonOnlyRelay.bindExclusive;
      });

      tearDown(() async {
        forwardRecords = null;
        startLoginForward = startedBefore;
        cardMaster = masterBefore;
        PersonOnlyRelay.bindPort = bindBefore;
        for (final process in started) {
          process.kill(ProcessSignal.sigkill);
          await process.exitCode;
        }
        where.deleteSync(recursive: true);
      });

      Future<int> freePort() async {
        final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        final port = probe.port;
        await probe.close();
        return port;
      }

      /// A process listening on [port] whose own command line forwards it as a login forward's ssh does.
      Future<({Process process, List<String> command})> listening(int port, {bool stubborn = false}) async {
        final command = <String>[
          'python3',
          '-c',
          'import socket,time,signal;${stubborn ? 'signal.signal(signal.SIGTERM,signal.SIG_IGN);' : ''}'
              's=socket.socket();s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1);'
              's.bind(("127.0.0.1",$port));s.listen(8);time.sleep(300)',
          '-L',
          '$port:localhost:$port',
          'alice@vm',
        ];
        final process = await Process.start(command.first, command.sublist(1));
        started.add(process);
        unawaited(process.exitCode.then((_) => ended.add(process)));
        for (var i = 0; i < 100; i++) {
          try {
            (await Socket.connect(InternetAddress.loopbackIPv4, port)).destroy();
            break;
          } on SocketException {
            await Future<void>.delayed(const Duration(milliseconds: 20));
          }
        }
        return (process: process, command: command);
      }

      /// The stand-in of a login forward's ssh, started from its [command]: it listens where the `-L` says, on a
      /// socket where that is a path, else on the port, and echoes what it hears.
      Future<Process> forwarding(List<String> command, {bool stubborn = false}) async {
        final local = command[command.indexOf('-L') + 1].split(':').first;
        final process = await Process.start('python3', [
          '-c',
          'import socket,sys,threading,time,os,signal\n'
              '${stubborn ? 'signal.signal(signal.SIGTERM,signal.SIG_IGN)\n' : ''}'
              'os.umask(0o177)\n'
              'p=sys.argv[1]\n'
              'if p.startswith("/"):\n'
              '  s=socket.socket(socket.AF_UNIX); s.bind(p)\n'
              'else:\n'
              '  s=socket.socket(); s.bind(("127.0.0.1",int(p)))\n'
              's.listen(8)\n'
              'def echo(c):\n'
              '  while True:\n'
              '    d=c.recv(4096)\n'
              '    if not d: break\n'
              '    c.sendall(d)\n'
              '  c.close()\n'
              'while True:\n'
              '  c,_=s.accept(); threading.Thread(target=echo,args=(c,),daemon=True).start()\n',
          local,
        ]);
        started.add(process);
        unawaited(process.exitCode.then((_) => ended.add(process)));
        return process;
      }

      Future<bool> alive(Process process) async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return !ended.contains(process);
      }

      // Harm: after a kill or `q`, every homeserver or login forward refused at the next start as a port in use.
      test('one a killed run left on the port is ended and raised again', () async {
        final port = await freePort();
        final left = await listening(port);
        ForwardRecords(records).record(left.process.pid, left.command);
        forwardRecords = ForwardRecords(records);
        startLoginForward = forwarding;

        final held = await withSsh(here, port);
        addTearDown(held.close);

        expect(await alive(left.process), isFalse, reason: 'the forward left behind was ended');
      });

      // Harm: an ssh that ignored being taken down forgotten, and never found again at the next start.
      test('a forward taken down stays recorded while its process still runs', () async {
        final port = await freePort();
        forwardRecords = ForwardRecords(records);
        startLoginForward = (command) => forwarding(command, stubborn: true);

        final held = await withSsh(here, port);
        await held.close();

        expect(File('$records/${started.last.pid}.forward').existsSync(), isTrue);
      });

      // Harm: a reply's port ssh binds on the loopback lets any local account send the sign-in its redirect first.
      test("a reply's port is held by the window, its ssh forwarding a socket of the person's own", () async {
        final port = await freePort();
        final commands = <List<String>>[];
        startLoginForward = (command) {
          commands.add(command);
          return forwarding(command);
        };
        final held = await withSsh(here, port);
        addTearDown(held.close);

        expect(commands.single[commands.single.indexOf('-L') + 1], '${where.path}/l-$port:localhost:$port');
        final connection = await Socket.connect(InternetAddress.loopbackIPv4, port);
        connection.write('/callback?code=1');
        await connection.flush();
        expect(utf8.decode(await connection.timeout(const Duration(seconds: 2)).first), '/callback?code=1');
        connection.destroy();
        await held.close();
        expect(FileSystemEntity.typeSync('${where.path}/l-$port'), FileSystemEntityType.notFound);
        await expectLater(Socket.connect(InternetAddress.loopbackIPv4, port), throwsA(isA<SocketException>()));
      });

      // Harm: a socket another program of the person's puts at the forward's path, after its ssh was proven to make it,
      // handed the sign-in's redirect.
      test("a reply goes to the socket its ssh was seen to make, not to one put at its path later", () async {
        final port = await freePort();
        startLoginForward = forwarding;
        final held = await withSsh(here, port);
        addTearDown(held.close);
        final path = '${where.path}/l-$port';
        File(path).deleteSync();
        final impostor = await ServerSocket.bind(InternetAddress(path, type: InternetAddressType.unix), 0);
        addTearDown(impostor.close);
        impostor.listen((connection) {
          connection.write('impostor');
          unawaited(connection.flush().then((_) => connection.destroy()));
        });

        final connection = await Socket.connect(InternetAddress.loopbackIPv4, port);
        connection.write('/callback?code=1');
        await connection.flush();
        expect(utf8.decode(await connection.timeout(const Duration(seconds: 2)).first), '/callback?code=1');
        connection.destroy();
      });

      group('through a card', () {
        late Machine card;
        late Process master;
        late List<List<String>> commands;

        setUp(() async {
          card = Machine.fromHostCard(
            HostCardSsh(
              name: 'alpha',
              address: 'alpha.example.org',
              sshPort: 22,
              hostKey: _cardKey,
              login: 'alice',
              publicKey: _cardKey,
            ),
            socketPath: '${where.path}/d',
            sshConfig: '${where.path}/ssh/alpha.conf',
          );
          commands = [];
          // The card's master as this window started it: it binds the socket a forward asked of it names, and lets go
          // of it when the forward is canceled; a client of it ends at once.
          master = await Process.start('python3', [
            '-c',
            'import socket,sys,threading,time,os,signal\n'
                'os.umask(0o177)\n'
                'held=[]\n'
                'def echo(c):\n'
                '  while True:\n'
                '    d=c.recv(4096)\n'
                '    if not d: break\n'
                '    c.sendall(d)\n'
                '  c.close()\n'
                'def serve(s):\n'
                '  try:\n'
                '    while True:\n'
                '      c,_=s.accept(); threading.Thread(target=echo,args=(c,),daemon=True).start()\n'
                '  except OSError: pass\n'
                'def forward(*_):\n'
                '  s=socket.socket(socket.AF_UNIX); s.bind(open(sys.argv[1]).read()); s.listen(8); held.append(s)\n'
                '  threading.Thread(target=serve,args=(s,),daemon=True).start()\n'
                'def cancel(*_):\n'
                '  for s in held:\n'
                '    try: s.shutdown(socket.SHUT_RDWR)\n'
                '    except OSError: pass\n'
                '    s.close()\n'
                '  held.clear()\n'
                'signal.signal(signal.SIGUSR1,forward)\n'
                'signal.signal(signal.SIGUSR2,cancel)\n'
                'print("ready",flush=True)\n'
                'while True: time.sleep(1)\n',
            '${where.path}/asked',
          ]);
          started.add(master);
          await master.stdout.transform(utf8.decoder).firstWhere((line) => line.contains('ready'));
          cardMaster = (control) => control == card.hostCard!.controlSocket(card.sshConfig) ? master.pid : null;
          startLoginForward = (command) {
            commands.add(command);
            final asked = command.contains('-O') ? command[command.indexOf('-O') + 1] : null;
            if (asked == 'forward') {
              File('${where.path}/asked').writeAsStringSync(command[command.indexOf('-L') + 1].split(':').first);
              master.kill(ProcessSignal.sigusr1);
            } else if (asked == 'cancel') {
              master.kill(ProcessSignal.sigusr2);
            }
            return Process.start('true', const []);
          };
        });

        // Harm: a sign-in through a card's machine refused, its forward added to the master and never taken down.
        test("a reply's socket is asked of the card's master, proven its, and canceled with the forward", () async {
          final port = await freePort();
          final held = await withSsh(card, port);

          final forward = commands.single;
          expect(forward.sublist(forward.indexOf('-O'), forward.indexOf('-O') + 2), ['-O', 'forward']);
          expect(forward[forward.indexOf('-L') + 1], '${where.path}/l-$port:localhost:$port');
          final connection = await Socket.connect(InternetAddress.loopbackIPv4, port);
          connection.write('/callback?code=2');
          await connection.flush();
          expect(utf8.decode(await connection.timeout(const Duration(seconds: 2)).first), '/callback?code=2');
          connection.destroy();

          await held.close();
          final cancel = commands.last;
          expect(cancel.sublist(cancel.indexOf('-O'), cancel.indexOf('-O') + 2), ['-O', 'cancel']);
          expect(cancel[cancel.indexOf('-L') + 1], '${where.path}/l-$port:localhost:$port');
          expect(FileSystemEntity.typeSync('${where.path}/l-$port'), FileSystemEntityType.notFound);
          await expectLater(Socket.connect(InternetAddress.loopbackIPv4, port), throwsA(isA<SocketException>()));
        });

        // Harm: a socket at the forward's path taken for the master's when this window raised no master to make it.
        test("a card whose master this window does not hold forwards nothing, and says so", () async {
          cardMaster = (_) => null;

          await expectLater(
            withSsh(card, await freePort()),
            throwsA(isA<ForwardRefused>().having((refused) => refused.words, 'words', contains('not connected'))),
          );
          expect(commands, isEmpty);
        });
      });

      // Harm: a forward this run holds for one login ended by another login asking for the same port.
      test('a second forward for a port this run holds ends nothing', () async {
        final port = await freePort();
        final held = await listening(port);
        forwardRecords = ForwardRecords(records)..record(held.process.pid, held.command);

        await expectLater(
          withSsh(here, port),
          throwsA(isA<ForwardRefused>().having((refused) => refused.words, 'words', contains('already in use'))),
        );
        expect(await alive(held.process), isTrue);
      });
    },
    // The records are read from Linux's /proc and held by a pidfd; elsewhere a forward left behind is not found again.
    skip: Platform.isLinux ? null : 'records of forwards left behind are kept on Linux alone',
  );
}

class _Hanging implements HeldForward {
  _Hanging(this._until);

  final Future<void> _until;

  @override
  Future<void> close() => _until;
}

class _Recorded implements HeldForward {
  _Recorded(this._onClose);

  final void Function() _onClose;

  @override
  Future<void> close() async => _onClose();
}

/// A terminal whose close takes until the test lets it end, as a program printing its last answer does.
class _SlowToClose implements SessionChannel {
  final _output = StreamController<List<int>>.broadcast();
  final _ended = Completer<int>();

  /// Completed by the test: the close has ended.
  final closed = Completer<void>();

  void prints(String words) => _output.add(utf8.encode(words));

  @override
  Stream<List<int>> get output => _output.stream;

  @override
  Future<int> get ended => _ended.future;

  @override
  void send(String input) {}

  @override
  void resize({required int columns, required int rows}) {}

  @override
  Future<void> close() async {
    await closed.future;
    if (!_ended.isCompleted) _ended.complete(129);
  }
}

const _cardKey = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
