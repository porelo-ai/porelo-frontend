import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/desk.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';
import 'package:porelo_frontend/src/app/loopback_carrier.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/tunnel.dart';
import 'package:porelo_host/porelo_host.dart';

const publicKey = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

/// What the daemon's relay stand-in does when it is asked.
enum _Says { answer, foreign, bannerOnly, malformed, denied, forged, going, bare, later }

/// A host's card connected from a Windows desktop, with the ssh stand-in: Windows' OpenSSH holds no master and its
/// `-L` port can never be proven its own, so the window holds each card port itself and carries every connection over
/// an ssh of its own; the daemon goes through the relay, and its answer alone makes the card up.
void main() {
  final families = [InternetAddress.loopbackIPv4, InternetAddress.loopbackIPv6];
  late Desk before;
  late Directory folder;
  late Map<String, String> environment;
  late Machine host;
  late List<int> ports;
  late List<List<String>> launches;
  late List<String> carried;
  late List<_Relay> carryingChildren;
  int? carryExit;
  late List<_Relay> relays;
  late _Unlock unlock;
  late _Files files;
  late _Says says;

  Future<int> freePort() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    return port;
  }

  Future<bool> bindable(InternetAddress address, int port) async {
    try {
      final socket = await ServerSocket.bind(address, port, v6Only: address.type == InternetAddressType.IPv6);
      await socket.close();
      return true;
    } on SocketException {
      return false;
    }
  }

  Future<void> until(bool Function() condition) async {
    for (var turn = 0; turn < 200 && !condition(); turn++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  /// Whether a connection to [port] on [address] is closed by the window within a moment.
  Future<bool> closedAtOnce(InternetAddress address, int port) async {
    final Socket client;
    try {
      client = await Socket.connect(address, port);
    } on SocketException {
      return false;
    }
    try {
      await client.drain<void>().timeout(const Duration(seconds: 2));
      return true;
    } on TimeoutException {
      return false;
    } on SocketException {
      return true;
    } finally {
      client.destroy();
    }
  }

  Tunnels tunnelsWith({Duration appears = const Duration(seconds: 5), CarrierBudget? budget, BindLoopback? bind}) {
    final tunnels = Tunnels(
      carrierBudget: budget,
      carrierBind: bind,
      configEnvironment: environment,
      appears: appears,
      start: (command) async {
        launches.add(command);
        final line = command.last;
        if (line.contains('porelo daemon connect')) {
          final relay = _Relay(says);
          relays.add(relay);
          return relay;
        }
        carried.add(line);
        final child = _Relay(_Says.later);
        carryingChildren.add(child);
        if (carryExit case final code?) Timer.run(() => child._finish(code));
        return child;
      },
      run: (command) async => ProcessResult(0, 0, '', ''),
      keyAvailable: (_) async => true,
      portsAvailable: (_) async {},
      unlocker: unlock,
      writer: files,
    );
    addTearDown(() async {
      await tunnels.dropEverything();
      tunnels.dispose();
    });
    return tunnels;
  }

  setUp(() async {
    before = desk;
    folder = Directory.systemTemp.createTempSync('w-');
    // An APPDATA Windows' path rules and this test's file system both take: the stand-in writer keeps the files.
    environment = {'SystemRoot': r'C:\Windows', 'APPDATA': folder.path};
    desk = Desk.of('windows', environment);
    ports = [await freePort(), await freePort(), await freePort()];
    final card = HostCardSsh(
      name: 'alpha',
      address: 'alpha.example.org',
      sshPort: 2222,
      hostKey: publicKey,
      login: 'alice',
      publicKey: publicKey,
      webPort: ports[0],
      gitPort: ports[1],
      matrixPort: ports[2],
    );
    host = Machine.fromHostCard(card, socketPath: '');
    launches = [];
    carried = [];
    carryingChildren = [];
    carryExit = null;
    relays = [];
    unlock = _Unlock();
    files = _Files();
    says = _Says.answer;
    addTearDown(() {
      desk = before;
      folder.deleteSync(recursive: true);
    });
  });

  // Harm: an ssh -L port on Windows is bound with SO_REUSEADDR after ssh says it listens, so another program takes or
  // shares it and receives the person's sign-ins; or the card asks Windows' OpenSSH for a master it cannot hold.
  test('no ssh is started with -L, -R or a master, and the window holds both families of each port', () async {
    final tunnels = tunnelsWith();

    expect(await tunnels.raiseFor(host), isTrue, reason: '${tunnels.of(host)?.problem}');

    final config = '${folder.path}\\porelo\\ssh\\alpha.conf';
    expect(host.sshConfig, config);
    for (final command in launches) {
      expect(command, isNot(anyOf(contains('-L'), contains('-R'), contains('-M'), contains('-N'))));
    }
    expect(launches.single, containsAllInOrder(['-F', config, '-T', 'alpha']), reason: 'only the relay ran');
    for (final port in ports) {
      for (final family in families) {
        expect(await bindable(family, port), isFalse, reason: '${family.address}:$port is held');
      }
    }
    expect(unlock.calls, [('alpha', config)], reason: "Core's unlock goes as a process of its own");
    expect(files.written[config], isNot(contains('Control')));
  });

  // Harm: a connection meant for one service reaches another's socket, or a path a caller chose.
  test('a connection to each port is carried over its own ssh to its own role', () async {
    final tunnels = tunnelsWith();
    expect(await tunnels.raiseFor(host), isTrue, reason: '${tunnels.of(host)?.problem}');

    for (final (index, family) in [
      (0, InternetAddress.loopbackIPv4),
      (1, InternetAddress.loopbackIPv6),
      (2, InternetAddress.loopbackIPv4),
    ]) {
      final client = await Socket.connect(family, ports[index]);
      addTearDown(client.destroy);
      await until(() => carried.length == index + 1);
    }

    expect(carried, [
      for (final role in ['forge-web', 'forge-git', 'homeserver']) inTheLoginShell('porelo service connect $role'),
    ]);
    final carrying = launches.where((command) => carried.contains(command.last)).toList();
    expect(carrying.first.take(6), [
      r'C:\Windows\System32\OpenSSH\ssh.exe',
      '-F',
      '${folder.path}\\porelo\\ssh\\alpha.conf',
      '-T',
      '--',
      'alpha',
    ]);
  });

  // Harm: the card is shown reached, its vault unlocked and its ports carried on the word of ssh or of whatever
  // answers, not on the daemon's own answer through the relay.
  for (final (name, saying) in [
    ('a banner on stderr alone', _Says.bannerOnly),
    ('malformed output', _Says.malformed),
    ('failed authentication', _Says.denied),
    ('an answer of no Porelo daemon', _Says.foreign),
    ('a frame that only names the interface and goes on', _Says.forged),
    ('a complete answer that goes on', _Says.going),
    ('a final frame that only names the interface', _Says.bare),
  ]) {
    test('$name leaves the card down, its ports held and carrying nothing', () async {
      says = saying;
      final tunnels = tunnelsWith(appears: const Duration(milliseconds: 300));

      expect(await tunnels.raiseFor(host), isFalse);

      expect(tunnels.of(host)?.state, TunnelState.down);
      expect(unlock.calls, isEmpty);
      expect(await closedAtOnce(InternetAddress.loopbackIPv4, ports[0]), isTrue);
      expect(carried, isEmpty);
      expect(await bindable(InternetAddress.loopbackIPv6, ports[2]), isFalse, reason: 'the ports stay held');
    });
  }

  // Harm: an answer to a card the person already let go makes it up again, with its vault unlocked.
  test('an answer that arrives after the card was released sets nothing', () async {
    says = _Says.later;
    final tunnels = tunnelsWith();
    final raising = tunnels.raiseFor(host);
    await until(() => relays.isNotEmpty);

    // The window ends: what is raising is interrupted, and the daemon's answer comes only then.
    final dropping = tunnels.dropEverything();
    relays.single.answer();
    await dropping;

    expect(await raising, isFalse);
    expect(tunnels.of(host)?.state, isNot(TunnelState.up));
    expect(unlock.calls, isEmpty);
    for (final family in families) {
      expect(await bindable(family, ports[0]), isTrue, reason: 'a released card holds nothing');
    }
  });

  // Harm: while a card reconnects, its ports are free a moment and another program takes them.
  test('the ports stay held on both families through a reconnect, closing what comes meanwhile', () async {
    final tunnels = tunnelsWith(appears: const Duration(milliseconds: 300));
    expect(await tunnels.raiseFor(host), isTrue, reason: '${tunnels.of(host)?.problem}');

    says = _Says.bannerOnly;
    await tunnels.raiseAgainIfItDropped(host);
    expect(tunnels.of(host)?.state, TunnelState.down, reason: 'the reconnect asked the daemon again');
    for (final family in families) {
      expect(await bindable(family, ports[1]), isFalse);
    }
    expect(await closedAtOnce(InternetAddress.loopbackIPv6, ports[1]), isTrue);
    expect(carried, isEmpty);

    says = _Says.answer;
    await tunnels.raiseAgainIfItDropped(host);
    expect(tunnels.of(host)?.state, TunnelState.up);
    final client = await Socket.connect(InternetAddress.loopbackIPv6, ports[1]);
    addTearDown(client.destroy);
    await until(() => carried.isNotEmpty);
    expect(carried, [inTheLoginShell('porelo service connect forge-git')]);
  });

  // Harm: a connection carried before a reconnect keeps reaching the host while the card is not up, or one accepted
  // while it raises again is carried before the daemon answered.
  test('a reconnect closes what it carried and carries nothing until the daemon answers again', () async {
    final tunnels = tunnelsWith(appears: const Duration(milliseconds: 500));
    expect(await tunnels.raiseFor(host), isTrue, reason: '${tunnels.of(host)?.problem}');
    final before = await Socket.connect(InternetAddress.loopbackIPv4, ports[0]);
    addTearDown(before.destroy);
    await until(() => carried.isNotEmpty);
    final closing = before.drain<void>().then((_) => true, onError: (Object _) => true);

    says = _Says.later;
    final again = tunnels.raiseAgainIfItDropped(host);
    await until(() => relays.length == 2);
    final closedWhileRaising = await closing.timeout(const Duration(seconds: 2), onTimeout: () => false);
    final newcomerClosed = await closedAtOnce(InternetAddress.loopbackIPv4, ports[0]);
    await again;

    expect(closedWhileRaising, isTrue, reason: 'the connection carried before is closed');
    expect(newcomerClosed, isTrue, reason: 'nothing is carried while it raises');
    expect(carried, hasLength(1));
    expect(carryingChildren.single.killed, isTrue, reason: 'its ssh is ended');
  });

  // Harm: a listener the system closed leaves its port to whatever program binds it next, while the card stays up and
  // its forge's address goes to that program.
  test('a port the system let go takes the card down, naming it, and Connect holds every port anew', () async {
    final listeners = <_Failing>[];
    final tunnels = tunnelsWith(
      bind: (address, port) async {
        final listener = _Failing(await LoopbackCarrier.bindExclusive(address, port));
        listeners.add(listener);
        return listener;
      },
    );
    expect(await tunnels.raiseFor(host), isTrue, reason: '${tunnels.of(host)?.problem}');
    final held = listeners.length;

    listeners.first.events.addError(const SocketException('accept failed'));
    await until(() => tunnels.of(host)?.state == TunnelState.down);

    expect(tunnels.of(host)?.state, TunnelState.down);
    expect(tunnels.of(host)?.problem, contains('${ports[0]}'));
    expect(await tunnels.raiseFor(host), isTrue, reason: '${tunnels.of(host)?.problem}');
    expect(listeners, hasLength(held * 2), reason: 'every port is bound again');
  });

  // Harm: connecting many cards at once starts an ssh for each, with the person's key, beyond the window's cap.
  test("the daemon's probes of many cards stay within the cap of all", () async {
    final cards = [
      for (final name in ['alpha', 'beta', 'gamma'])
        Machine.fromHostCard(
          HostCardSsh.fromStored({
            ...host.hostCard!.stored,
            'name': name,
            'services': {'forge': null, 'matrix': null},
          }),
          socketPath: '',
        ),
    ];
    says = _Says.later;
    final tunnels = tunnelsWith(appears: const Duration(milliseconds: 500), budget: CarrierBudget(inAll: 2));

    final raising = [for (final card in cards) tunnels.raiseFor(card)];
    await until(() => relays.length >= 2);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final probing = relays.length;
    await Future.wait(raising);

    expect(probing, 2);
    expect(cards.where((card) => tunnels.of(card)?.problem?.contains('connections') ?? false), hasLength(1));
  });

  // Harm: a forge or homeserver page that never loads or stops halfway is not explained, so the person cannot tell a
  // host whose porelo does not know the service from one that serves none or is down, or from one that broke off.
  for (final (code, said) in [(64, 'older than'), (69, 'serves no '), (70, 'broke off')]) {
    test('a carried connection whose host relay exits $code says what it means: $said', () async {
      final tunnels = tunnelsWith();
      expect(await tunnels.raiseFor(host), isTrue, reason: '${tunnels.of(host)?.problem}');
      carryExit = code;

      final client = await Socket.connect(InternetAddress.loopbackIPv4, ports[1]);
      addTearDown(client.destroy);
      await until(() => tunnels.of(host)?.words != null);

      expect(tunnels.of(host)?.words, allOf(contains(said), contains('Git')));
      expect(tunnels.of(host)?.state, TunnelState.up, reason: 'the daemon still answers');
    });
  }

  // Harm: every page closed by the browser itself is said on the card as a fault of the host.
  test('a carried connection whose relay ends well says nothing', () async {
    final tunnels = tunnelsWith();
    expect(await tunnels.raiseFor(host), isTrue, reason: '${tunnels.of(host)?.problem}');
    carryExit = 0;

    final client = await Socket.connect(InternetAddress.loopbackIPv4, ports[1]);
    addTearDown(client.destroy);
    await until(() => carried.isNotEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(tunnels.of(host)?.words, isNull);
  });

  // Harm: Connect goes on beside another program holding one of the card's ports, which then receives what is meant for
  // the card.
  test('a port another program holds refuses Connect, naming it, and holds no other', () async {
    final squatter = await ServerSocket.bind(InternetAddress.loopbackIPv6, ports[1], v6Only: true);
    addTearDown(squatter.close);
    final tunnels = tunnelsWith();

    expect(await tunnels.raiseFor(host), isFalse);

    expect(tunnels.of(host)?.problem, contains('${ports[1]}'));
    expect(relays, isEmpty, reason: 'nothing is asked of the host');
    for (final family in families) {
      expect(await bindable(family, ports[0]), isTrue);
    }
  });

  // Harm: a card with no forge and no homeserver is counted up without anything having answered.
  test("a host forwarding no port is up only on its daemon's answer", () async {
    host = Machine.fromHostCard(
      HostCardSsh.fromStored({
        ...host.hostCard!.stored,
        'services': {'forge': null, 'matrix': null},
      }),
      socketPath: '',
    );
    says = _Says.bannerOnly;
    final silent = tunnelsWith(appears: const Duration(milliseconds: 300));
    expect(await silent.raiseFor(host), isFalse);
    expect(unlock.calls, isEmpty);

    says = _Says.answer;
    final answering = tunnelsWith();
    expect(await answering.raiseFor(host), isTrue, reason: '${answering.of(host)?.problem}');
    expect(unlock.calls, hasLength(1));
  });
}

class _Unlock implements HostUnlocker {
  final calls = <(String, String)>[];
  @override
  Future<HostUnlockResult> unlock(HostCardSsh card, String config) async {
    calls.add((card.name, config));
    return const HostUnlockResult(HostUnlockState.unlocked);
  }

  @override
  Future<void> cancel(String host) async {}
}

/// Keeps what would be published, by path, and protects nothing: Windows' ACLs are not this test's.
class _Files extends HostFileWriter {
  final written = <String, String>{};

  @override
  Future<void> protectDirectory(Directory directory) async {}

  @override
  Future<bool> check(File file, List<int> bytes) async => false;

  @override
  Future<void> write(File file, List<int> bytes) async => written[file.path] = utf8.decode(bytes);
}

/// The ssh stand-in: as the daemon's relay it answers GetInfo as it is told; as a carried connection's ssh, or told
/// to wait, it says nothing until it is killed.
class _Relay extends Fake implements Process {
  _Relay(this.says) {
    if (says == _Says.bannerOnly) _errors.add(utf8.encode('Welcome to alpha. Authorized use only.\n'));
    if (says == _Says.denied) {
      _errors.add(utf8.encode('alice@alpha.example.org: Permission denied (publickey).\n'));
      _finish(255);
    }
  }

  final _Says says;
  final _out = StreamController<List<int>>();
  final _errors = StreamController<List<int>>();
  final _exit = Completer<int>();
  late final _In _in = _In(this);
  bool killed = false;

  void _asked() {
    switch (says) {
      case _Says.answer:
        answer();
      case _Says.foreign:
        _reply(['org.varlink.service', 'org.example.Other1']);
      case _Says.malformed:
        _out.add(utf8.encode('Last login: yesterday\x00'));
      case _Says.forged:
        _out.add(utf8.encode('{"parameters":{"interfaces":["org.fuin.porelo.Tasks1"]},"continues":true}\x00'));
      case _Says.going:
        _reply(['org.fuin.porelo.Tasks1'], continues: true);
      case _Says.bare:
        _out.add(utf8.encode('{"parameters":{"interfaces":["org.fuin.porelo.Tasks1"]}}\x00'));
      case _Says.bannerOnly || _Says.denied || _Says.later:
        break;
    }
  }

  void answer() => _reply(['org.varlink.service', 'org.fuin.porelo.Tasks1']);

  void _reply(List<String> interfaces, {bool continues = false}) {
    if (_out.isClosed) return;
    final reply = {
      'parameters': {'product': 'porelo', 'version': '1', 'vendor': 'fuin', 'interfaces': interfaces},
      if (continues) 'continues': true,
    };
    _out.add(utf8.encode('${jsonEncode(reply)}\x00'));
  }

  void _finish(int code) {
    unawaited(_out.close());
    unawaited(_errors.close());
    if (!_exit.isCompleted) _exit.complete(code);
  }

  @override
  IOSink get stdin => _in;
  @override
  Stream<List<int>> get stdout => _out.stream;
  @override
  Stream<List<int>> get stderr => _errors.stream;
  @override
  Future<int> get exitCode => _exit.future;
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    _finish(-1);
    return true;
  }
}

/// The relay's standard input: a call ends at its NUL.
class _In extends Fake implements IOSink {
  _In(this.relay);
  final _Relay relay;
  final _done = Completer<void>();

  @override
  void add(List<int> data) {
    if (data.contains(0)) relay._asked();
  }

  @override
  Future<void> flush() async {}
  @override
  Future<void> close() async {
    if (!_done.isCompleted) _done.complete();
  }

  @override
  Future<void> get done => _done.future;
}

/// A real listener whose errors the test gives instead of the system.
class _Failing extends Stream<RawSocket> implements RawServerSocket {
  _Failing(this._real) {
    _accepting = _real.listen(events.add, onError: events.addError, onDone: events.close);
  }

  final RawServerSocket _real;
  final events = StreamController<RawSocket>();
  late final StreamSubscription<RawSocket> _accepting;

  @override
  InternetAddress get address => _real.address;

  @override
  int get port => _real.port;

  @override
  Future<RawServerSocket> close() async {
    await _accepting.cancel();
    await _real.close();
    if (!events.isClosed) unawaited(events.close());
    return this;
  }

  @override
  StreamSubscription<RawSocket> listen(
    void Function(RawSocket event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => events.stream.listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
}
