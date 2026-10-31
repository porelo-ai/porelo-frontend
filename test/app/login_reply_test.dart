import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/login_forward.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/pty.dart';
import 'package:porelo_frontend/src/app/session.dart';

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

    await expectLater(
      withSsh(vm, taken.port),
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
