import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/loopback_carrier.dart';

/// The loopback ports of a host's card, held by the window itself on both families, each connection carried over a
/// process of its own. Run on Linux and in the Windows build; the native contender runs on Windows alone.
void main() {
  final families = [InternetAddress.loopbackIPv4, InternetAddress.loopbackIPv6];
  late List<CarriedRole> roles;
  late List<_Child> children;
  late List<LoopbackCarrier> carriers;

  Future<int> freePort() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    return port;
  }

  Future<Process> carry(CarriedRole role) async {
    roles.add(role);
    final child = _Child();
    children.add(child);
    return child;
  }

  LoopbackCarrier carrier(
    Map<int, CarriedRole> ports, {
    CarrierBudget? budget,
    BindLoopback? bind,
    Future<Process> Function(CarriedRole)? through,
  }) {
    final made = LoopbackCarrier(ports, carry: through ?? carry, budget: budget, bind: bind);
    carriers.add(made);
    return made;
  }

  /// Whether another socket can bind [port] on [address] now.
  Future<bool> bindable(InternetAddress address, int port) async {
    try {
      final socket = await ServerSocket.bind(address, port, v6Only: address.type == InternetAddressType.IPv6);
      await socket.close();
      return true;
    } on SocketException {
      return false;
    }
  }

  /// Waits until [condition] holds, a bounded number of turns.
  Future<void> until(bool Function() condition) async {
    for (var turn = 0; turn < 200 && !condition(); turn++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  /// Whether [client] is closed by the far end within a moment.
  Future<bool> closedByTheCarrier(Socket client) async {
    try {
      await client.drain<void>().timeout(const Duration(seconds: 2));
      return true;
    } on TimeoutException {
      return false;
    } on SocketException {
      return true;
    }
  }

  setUp(() {
    roles = [];
    children = [];
    carriers = [];
    addTearDown(() async {
      for (final each in carriers) {
        await each.release();
      }
    });
  });

  // Harm: another program that took a card's port first is left on it, and the person's sign-ins sent there go to it.
  for (final family in families) {
    test('a port another socket holds on ${family.address} refuses the hold, naming it, and binds nothing', () async {
      final port = await freePort();
      final other = await freePort();
      final squatter = await ServerSocket.bind(family, port, v6Only: family.type == InternetAddressType.IPv6);
      addTearDown(squatter.close);
      final held = carrier({other: CarriedRole.forgeWeb, port: CarriedRole.forgeGit});

      await expectLater(
        held.hold(),
        throwsA(isA<CarrierRefused>().having((refused) => refused.message, 'message', contains('$port'))),
      );

      for (final each in families) {
        expect(await bindable(each, other), isTrue, reason: 'what was bound before the refusal is released');
      }
    });
  }

  // Harm: another program binds or shares a held port and receives connections meant for the card.
  test('while held, no other socket binds its port on either family', () async {
    final port = await freePort();
    final held = carrier({port: CarriedRole.forgeWeb});

    await held.hold();

    for (final family in families) {
      expect(await bindable(family, port), isFalse, reason: '${family.address} is held');
    }
  });

  // Harm: a port's connection reaches another service's socket, or its bytes are lost on the way.
  test('each port reaches its own role, and the bytes arrive both ways', () async {
    final web = await freePort();
    final matrix = await freePort();
    final held = carrier({web: CarriedRole.forgeWeb, matrix: CarriedRole.homeserver})..carrying = true;
    await held.hold();

    final toWeb = await Socket.connect(InternetAddress.loopbackIPv4, web);
    addTearDown(toWeb.destroy);
    final fromWeb = <int>[];
    toWeb.listen(fromWeb.addAll);
    await until(() => children.isNotEmpty);
    toWeb.add(utf8.encode('GET /'));
    await until(() => children.single.received.isNotEmpty);
    children.single.say('200 OK');
    await until(() => fromWeb.isNotEmpty);

    final toMatrix = await Socket.connect(InternetAddress.loopbackIPv6, matrix);
    addTearDown(toMatrix.destroy);
    await until(() => children.length == 2);

    expect(roles, [CarriedRole.forgeWeb, CarriedRole.homeserver]);
    expect(utf8.decode(children.first.received), 'GET /');
    expect(utf8.decode(fromWeb), '200 OK');
  });

  // Harm: a connection's ssh is left running with the person's key after either side let go.
  test('the client closing ends its process, and the process ending closes the client', () async {
    final port = await freePort();
    final held = carrier({port: CarriedRole.forgeWeb})..carrying = true;
    await held.hold();

    final leaving = await Socket.connect(InternetAddress.loopbackIPv4, port);
    await until(() => children.isNotEmpty);
    leaving.destroy();
    await until(() => children.first.killed);
    final staying = await Socket.connect(InternetAddress.loopbackIPv4, port);
    addTearDown(staying.destroy);
    await until(() => children.length == 2);
    children.last.say('bye');
    children.last.end();

    expect(children.first.killed, isTrue);
    expect(await closedByTheCarrier(staying), isTrue);
    expect(held.connections, 0);
  });

  // Harm: a disconnected card keeps its ports, or a connection's ssh, after the person let it go.
  test('release closes the listeners and every connection', () async {
    final port = await freePort();
    final held = carrier({port: CarriedRole.forgeGit})..carrying = true;
    await held.hold();
    final client = await Socket.connect(InternetAddress.loopbackIPv4, port);
    addTearDown(client.destroy);
    await until(() => children.isNotEmpty);

    await held.release();

    expect(children.single.killed, isTrue);
    expect(await closedByTheCarrier(client), isTrue);
    for (final family in families) {
      expect(await bindable(family, port), isTrue);
    }
  });

  // Harm: while the card is not up, a connection meant for it waits on a port the window holds or reaches a host not
  // yet proven.
  test('while not carrying, a connection is closed at once and nothing is started', () async {
    final port = await freePort();
    final held = carrier({port: CarriedRole.forgeWeb});
    await held.hold();

    final client = await Socket.connect(InternetAddress.loopbackIPv4, port);
    addTearDown(client.destroy);

    expect(await closedByTheCarrier(client), isTrue);
    expect(roles, isEmpty);
  });

  // Harm: a flood of local connections uses the person's key without bound, or takes the card's ports down.
  test('a flood against stalled children stays within the caps of each card and of all, and keeps the ports', () async {
    final budget = CarrierBudget(perCard: 3, inAll: 4, startsPerSecond: 1000, now: () => DateTime.utc(2026));
    final one = await freePort();
    final two = await freePort();
    final first = carrier({one: CarriedRole.forgeWeb}, budget: budget)..carrying = true;
    final second = carrier({two: CarriedRole.forgeWeb}, budget: budget)..carrying = true;
    await first.hold();
    await second.hold();

    final clients = [
      for (var each = 0; each < 10; each++) await Socket.connect(InternetAddress.loopbackIPv4, one),
      for (var each = 0; each < 10; each++) await Socket.connect(InternetAddress.loopbackIPv4, two),
    ];
    addTearDown(() {
      for (final client in clients) {
        client.destroy();
      }
    });
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(first.connections, 3, reason: 'one card stops at its own cap');
    expect(second.connections, 1, reason: 'every card together stops at the cap of all');
    expect(children, hasLength(4));
    for (final family in families) {
      expect(await bindable(family, one), isFalse, reason: 'the ports stay held');
    }
  });

  // Harm: a burst of connections starts the person's key faster than the budget allows.
  test('a burst within one second starts no more children than the rate', () async {
    final budget = CarrierBudget(startsPerSecond: 2, now: () => DateTime.utc(2026));
    final port = await freePort();
    final held = carrier({port: CarriedRole.forgeWeb}, budget: budget)..carrying = true;
    await held.hold();

    final clients = [for (var each = 0; each < 6; each++) await Socket.connect(InternetAddress.loopbackIPv4, port)];
    addTearDown(() {
      for (final client in clients) {
        client.destroy();
      }
    });
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(children, hasLength(2));
  });

  // Harm: an ssh that never answers holds a connection, the person's key and a place under the caps for ever.
  test('a child silent past the handshake deadline is ended with its connection', () async {
    final budget = CarrierBudget(handshake: const Duration(milliseconds: 100));
    final port = await freePort();
    final held = carrier({port: CarriedRole.forgeWeb}, budget: budget)..carrying = true;
    await held.hold();

    final client = await Socket.connect(InternetAddress.loopbackIPv4, port);
    addTearDown(client.destroy);

    expect(await closedByTheCarrier(client), isTrue);
    expect(children.single.killed, isTrue);
    expect(held.connections, 0);
  });

  // Harm: a child that stops reading makes the window hold everything the client sends, without bound.
  test('a child that stops reading holds no more than the buffer bound', () async {
    final budget = CarrierBudget(bufferedBytes: 4096);
    final port = await freePort();
    final held = carrier({port: CarriedRole.forgeGit}, budget: budget)..carrying = true;
    await held.hold();
    final client = await Socket.connect(InternetAddress.loopbackIPv4, port);
    addTearDown(client.destroy);
    await until(() => children.isNotEmpty);
    children.single.stall();

    client.add(Uint8List(4 * 1024 * 1024));
    unawaited(client.flush().then<void>((_) {}, onError: (Object _) {}));
    await Future<void>.delayed(const Duration(milliseconds: 500));

    expect(children.single.received, isNotEmpty);
    expect(children.single.received.length, lessThanOrEqualTo(4096 + 16 * 1024));
  });

  // Harm: an ssh started for a connection already gone runs on with the person's key.
  test('a child that starts after its connection was cancelled is ended', () async {
    final port = await freePort();
    final starting = Completer<Process>();
    final held = carrier({port: CarriedRole.forgeWeb}, through: (_) => starting.future)..carrying = true;
    await held.hold();
    final client = await Socket.connect(InternetAddress.loopbackIPv4, port);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    client.destroy();
    await held.release();
    final late = _Child();
    starting.complete(late);
    await until(() => late.killed);

    expect(late.killed, isTrue);
  });

  // Harm: a release while the ports are being bound leaves one held that nobody will let go.
  test('a release during the hold leaves nothing bound', () async {
    final port = await freePort();
    final binding = Completer<void>();
    final held = carrier(
      {port: CarriedRole.forgeWeb},
      bind: (address, port) async {
        await binding.future;
        return LoopbackCarrier.bindExclusive(address, port);
      },
    );

    final holding = held.hold().then<void>((_) {}, onError: (Object _) {});
    await held.release();
    binding.complete();
    await holding;

    for (final family in families) {
      expect(await bindable(family, port), isTrue);
    }
  });

  // Harm: a released card's ssh children still run with the person's key after release answered, and their places
  // under the caps go to new children meanwhile.
  test('release waits for its children to exit, and a place is free only once its child exited', () async {
    final budget = CarrierBudget(inAll: 1);
    final one = await freePort();
    final two = await freePort();
    final first = carrier({one: CarriedRole.forgeWeb}, budget: budget)..carrying = true;
    final second = carrier({two: CarriedRole.forgeWeb}, budget: budget)..carrying = true;
    await first.hold();
    await second.hold();
    final client = await Socket.connect(InternetAddress.loopbackIPv4, one);
    addTearDown(client.destroy);
    await until(() => children.isNotEmpty);
    children.single.lingers = true;

    var released = false;
    final releasing = first.release().then((_) => released = true);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final releasedBeforeExit = released;
    final meanwhile = await Socket.connect(InternetAddress.loopbackIPv4, two);
    addTearDown(meanwhile.destroy);
    final refusedMeanwhile = await closedByTheCarrier(meanwhile);
    children.first.exit();
    await releasing;
    final after = await Socket.connect(InternetAddress.loopbackIPv4, two);
    addTearDown(after.destroy);
    await until(() => children.length == 2);

    expect(children.first.killed, isTrue);
    expect(releasedBeforeExit, isFalse, reason: 'release waits for the exit');
    expect(refusedMeanwhile, isTrue, reason: 'the place stays taken until the child exited');
    expect(children, hasLength(2), reason: 'the place is free once it exited');
  });

  // Harm: a child that says faster than the client reads makes the window hold its output without bound.
  test('a fast child and a client that does not read hold the child back', () async {
    final budget = CarrierBudget(bufferedBytes: 64 * 1024);
    final port = await freePort();
    final held = carrier({port: CarriedRole.forgeWeb}, budget: budget)..carrying = true;
    await held.hold();
    final client = await Socket.connect(InternetAddress.loopbackIPv4, port);
    addTearDown(client.destroy);
    // Never read: the client's subscription stays paused.
    client.listen((_) {}).pause();
    await until(() => children.isNotEmpty);

    unawaited(children.single.flood(64 * 1024 * 1024));
    await Future<void>.delayed(const Duration(seconds: 2));

    expect(children.single.produced, lessThan(24 * 1024 * 1024), reason: 'beyond what the system buffers, it waits');
  });

  group('against a native contender that sets SO_REUSEADDR', () {
    final skip = Platform.isWindows ? false : 'Windows sockets only: the contender is Winsock';

    // Harm: on Windows, a program that sets SO_REUSEADDR binds a held port beside the window and takes the person's
    // connections.
    for (final family in families) {
      test('it cannot bind a held port on ${family.address}, and a connection reaches the window', () async {
        final port = await freePort();
        final held = carrier({port: CarriedRole.forgeWeb})..carrying = true;
        await held.hold();

        final contender = _Winsock.listenReusing(family, port);
        addTearDown(() => _Winsock.close(contender));
        final client = await Socket.connect(family, port);
        addTearDown(client.destroy);
        await until(() => roles.isNotEmpty);

        expect(contender.bound, isFalse, reason: 'Winsock said ${contender.error}');
        expect(roles, [CarriedRole.forgeWeb], reason: 'the connection was delivered to the window');
      }, skip: skip);

      test('a port it holds on ${family.address} refuses the hold', () async {
        final port = await freePort();
        final contender = _Winsock.listenReusing(family, port);
        addTearDown(() => _Winsock.close(contender));
        expect(contender.bound, isTrue, reason: 'Winsock said ${contender.error}');

        await expectLater(carrier({port: CarriedRole.forgeWeb}).hold(), throwsA(isA<CarrierRefused>()));
      }, skip: skip);
    }
  });
}

/// The process stand-in: records what it is given, says what the test tells it, and can stop reading.
class _Child extends Fake implements Process {
  final received = <int>[];
  final _out = StreamController<List<int>>();
  final _exit = Completer<int>();
  late final _Stdin _stdin = _Stdin(this);
  bool killed = false;
  Completer<void>? _stalled;

  void say(String words) => _out.add(utf8.encode(words));

  void end() {
    unawaited(_out.close());
    if (!_exit.isCompleted) _exit.complete(0);
  }

  void stall() => _stalled = Completer<void>();

  /// Whether a kill leaves it running until [exit], as a child Windows terminates late does.
  bool lingers = false;

  /// Exits now, whatever it was told before.
  void exit() => end();

  /// How many bytes it produced while flooding.
  int produced = 0;

  /// Says [total] bytes as fast as its output is read, never faster: it waits while its reader is paused.
  Future<void> flood(int total) async {
    final chunk = Uint8List(64 * 1024);
    while (produced < total && !_out.isClosed) {
      if (!_out.isPaused) {
        _out.add(chunk);
        produced += chunk.length;
      }
      await Future<void>.delayed(Duration.zero);
    }
  }

  @override
  IOSink get stdin => _stdin;
  @override
  Stream<List<int>> get stdout => _out.stream;
  @override
  Stream<List<int>> get stderr => const Stream.empty();
  @override
  Future<int> get exitCode => _exit.future;
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    if (!lingers) end();
    return true;
  }
}

/// A child's standard input: takes bytes until it is stalled, then never finishes a flush.
class _Stdin extends Fake implements IOSink {
  _Stdin(this.child);
  final _Child child;
  final _done = Completer<void>();

  @override
  void add(List<int> data) => child.received.addAll(data);

  @override
  Future<void> flush() => child._stalled?.future ?? Future<void>.value();
  @override
  Future<void> close() async {
    if (!_done.isCompleted) _done.complete();
  }

  @override
  Future<void> get done => _done.future;
}

/// A listener made through Winsock itself, with SO_REUSEADDR set before its bind, as another program would.
class _Contender {
  _Contender(this.socket, this.bound, this.error);
  final int socket;
  final bool bound;
  final int error;
}

abstract final class _Winsock {
  static final _ws2 = DynamicLibrary.open('ws2_32.dll');
  static final _kernel = DynamicLibrary.open('kernel32.dll');
  static final _socket = _ws2.lookupFunction<IntPtr Function(Int32, Int32, Int32), int Function(int, int, int)>(
    'socket',
  );
  static final _setsockopt = _ws2
      .lookupFunction<
        Int32 Function(IntPtr, Int32, Int32, Pointer<Uint8>, Int32),
        int Function(int, int, int, Pointer<Uint8>, int)
      >('setsockopt');
  static final _bind = _ws2
      .lookupFunction<Int32 Function(IntPtr, Pointer<Uint8>, Int32), int Function(int, Pointer<Uint8>, int)>('bind');
  static final _listen = _ws2.lookupFunction<Int32 Function(IntPtr, Int32), int Function(int, int)>('listen');
  static final _closesocket = _ws2.lookupFunction<Int32 Function(IntPtr), int Function(int)>('closesocket');
  static final _lastError = _ws2.lookupFunction<Int32 Function(), int Function()>('WSAGetLastError');
  static final _alloc = _kernel
      .lookupFunction<Pointer<Uint8> Function(Uint32, IntPtr), Pointer<Uint8> Function(int, int)>('LocalAlloc');
  static final _free = _kernel
      .lookupFunction<Pointer<Uint8> Function(Pointer<Uint8>), Pointer<Uint8> Function(Pointer<Uint8>)>('LocalFree');

  /// A socket of [family] with SO_REUSEADDR, bound to [port] and listening if Winsock let it.
  static _Contender listenReusing(InternetAddress family, int port) {
    final v6 = family.type == InternetAddressType.IPv6;
    final socket = _socket(v6 ? 23 : 2, 1, 6);
    // LPTR: zeroed memory.
    final memory = _alloc(0x40, 32);
    try {
      memory.asTypedList(4).setAll(0, [1, 0, 0, 0]);
      // SOL_SOCKET, SO_REUSEADDR.
      if (_setsockopt(socket, 0xffff, 4, memory, 4) != 0) return _Contender(socket, false, _lastError());
      final address = memory.asTypedList(28)..fillRange(0, 28, 0);
      address.buffer.asByteData(address.offsetInBytes).setUint16(0, v6 ? 23 : 2, Endian.little);
      address.buffer.asByteData(address.offsetInBytes).setUint16(2, port, Endian.big);
      if (v6) {
        address[23] = 1;
      } else {
        address.setAll(4, [127, 0, 0, 1]);
      }
      if (_bind(socket, memory, v6 ? 28 : 16) != 0) return _Contender(socket, false, _lastError());
      if (_listen(socket, 8) != 0) return _Contender(socket, false, _lastError());
      return _Contender(socket, true, 0);
    } finally {
      _free(memory);
    }
  }

  static void close(_Contender contender) => _closesocket(contender.socket);
}
