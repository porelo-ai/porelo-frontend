import 'dart:async';
import 'dart:io';

/// A service of a host's card that the window carries a loopback port to, named by the role the host maps to its one
/// fixed socket: the host's relay command takes the role alone, never a path.
enum CarriedRole {
  /// The forge's web interface.
  forgeWeb('forge-web'),

  /// The forge's Git transport.
  forgeGit('forge-git'),

  /// The homeserver's client interface.
  homeserver('homeserver');

  const CarriedRole(this.word);

  /// The word the host's relay command takes.
  final String word;
}

/// Binds one listener of the window's own, for a test to stand in.
typedef BindLoopback = Future<RawServerSocket> Function(InternetAddress address, int port);

/// A port the window could not hold for a card, named with its family.
class CarrierRefused implements Exception {
  /// Constructor taking the port, its address and what the system said.
  const CarrierRefused(this.port, this.address, this.said);

  /// The port that could not be held.
  final int port;

  /// The loopback address it was bound on.
  final InternetAddress address;

  /// What the system said.
  final String said;

  /// The sentence for the person.
  String get message =>
      'Local port $port on ${address.address} is held by another program, so this computer cannot carry the '
      "host's connection on it: $said";

  @override
  String toString() => message;
}

/// What every carrier of the window may spend together, and each alone: the person's key is used once for each
/// connection carried, so they are bounded.
class CarrierBudget {
  /// Constructor taking the bounds, and the clock a test stands in for.
  CarrierBudget({
    this.perCard = 16,
    this.inAll = 48,
    this.startsPerSecond = 8,
    this.bufferedBytes = 256 * 1024,
    this.handshake = const Duration(seconds: 30),
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  /// The most connections, pending and carried, of one card.
  final int perCard;

  /// The most connections, pending and carried, of every card together.
  final int inAll;

  /// The most connections one card starts in any second.
  final int startsPerSecond;

  /// The most bytes one direction of a connection holds before it stops reading.
  final int bufferedBytes;

  /// How long a connection's ssh is given to say its first byte.
  final Duration handshake;

  /// The clock the rate is read on.
  final DateTime Function() now;

  int _held = 0;

  /// Takes a place under [inAll] for one more ssh child of the window, or answers false when every place is taken.
  bool take() {
    if (_held >= inAll) return false;
    _held++;
    return true;
  }

  /// Gives back a place [take] took, once its child has exited.
  void giveBack() => _held--;
}

/// The loopback ports of one host's card, held by the window itself on both families, exclusively, with each
/// accepted connection carried to the host over a process of its own.
///
/// No other program can bind or share a held port, so none receives a connection meant for the card. While
/// [carrying] is false a connection is accepted and closed at once, never left to another program.
class LoopbackCarrier {
  /// Constructor taking each port with its role, how a connection's process is started, how a listener is bound and
  /// the budget it shares.
  LoopbackCarrier(
    Map<int, CarriedRole> ports, {
    required this._carry,
    BindLoopback? bind,
    CarrierBudget? budget,
    this.onExit,
    this.onLost,
  }) : ports = Map.unmodifiable(ports),
       _bind = bind ?? bindExclusive,
       budget = budget ?? CarrierBudget();

  /// Each port held, with the role it carries to.
  final Map<int, CarriedRole> ports;

  /// What this carrier may spend.
  final CarrierBudget budget;

  final Future<Process> Function(CarriedRole role) _carry;
  final BindLoopback _bind;

  /// Told how each connection's process exited, with the role it carried.
  final void Function(CarriedRole role, int code)? onExit;

  /// Told once, with its port and address, when the system closed a listener: every port is let go then, and nothing is
  /// carried any more; a new carrier has to hold them again.
  final void Function(int port, InternetAddress address)? onLost;

  /// Whether an accepted connection is carried; while false it is closed at once.
  bool carrying = false;

  /// Binds [address]:[port] so that no other socket may bind or share it.
  static Future<RawServerSocket> bindExclusive(InternetAddress address, int port) =>
      RawServerSocket.bind(address, port, v6Only: address.type == InternetAddressType.IPv6, shared: false);

  final List<RawServerSocket> _listeners = [];
  final Set<_Carried> _carried = {};
  final List<DateTime> _starts = [];
  bool _released = false;

  /// Binds every port on both loopback families, or none: a port that cannot be held refuses with [CarrierRefused].
  ///
  /// Nothing is accepted before every port is bound; a [release] meanwhile leaves nothing bound.
  Future<void> hold() async {
    final bound = <(RawServerSocket, CarriedRole, int, InternetAddress)>[];
    Future<void> letGo() async {
      for (final (listener, _, _, _) in bound) {
        await listener.close();
      }
    }

    for (final MapEntry(key: port, value: role) in ports.entries) {
      for (final address in [InternetAddress.loopbackIPv4, InternetAddress.loopbackIPv6]) {
        final RawServerSocket listener;
        try {
          listener = await _bind(address, port);
        } on SocketException catch (refused) {
          await letGo();
          throw CarrierRefused(port, address, refused.osError?.message ?? refused.message);
        }
        bound.add((listener, role, port, address));
        if (_released) {
          await letGo();
          return;
        }
      }
    }
    for (final (listener, role, port, address) in bound) {
      _listeners.add(listener);
      // The system closes a listener on an error, and the port is then free for anyone: the card no longer holds it.
      listener.listen(
        (client) => _accepted(client, role),
        onError: (Object _) => _lose(port, address),
        onDone: () => _lose(port, address),
        cancelOnError: true,
      );
    }
  }

  bool _lost = false;

  /// Whether the system closed one of its listeners: it carries nothing any more and holds no port.
  bool get lost => _lost;

  /// A listener closed that [release] did not close: nothing is carried, every port is let go, and [onLost] is told.
  void _lose(int port, InternetAddress address) {
    if (_released || _lost) return;
    _lost = true;
    unawaited(release());
    onLost?.call(port, address);
  }

  void _accepted(RawSocket client, CarriedRole role) {
    if (_released ||
        _lost ||
        !carrying ||
        _carried.length >= budget.perCard ||
        budget._held >= budget.inAll ||
        !_mayStart()) {
      client.close();
      return;
    }
    if (!budget.take()) {
      client.close();
      return;
    }
    final carried = _Carried(this, client, role);
    _carried.add(carried);
    unawaited(carried.start());
  }

  /// Whether one more child may start in the last second, counting it if so.
  bool _mayStart() {
    final now = budget.now();
    _starts.removeWhere((start) => now.difference(start) >= const Duration(seconds: 1));
    if (_starts.length >= budget.startsPerSecond) return false;
    _starts.add(now);
    return true;
  }

  void _exited(_Carried carried) {
    if (_carried.remove(carried)) budget.giveBack();
  }

  /// Stops carrying: each connection carried so far is closed and its process ended, and what comes next is closed at
  /// once until [carrying] is set again.
  void stopCarrying() {
    carrying = false;
    for (final carried in [..._carried]) {
      carried.end();
    }
  }

  /// How long [release] waits for the connections' processes to exit.
  static const exitWithin = Duration(seconds: 5);

  /// Closes every listener and every connection, and ends each connection's process, waiting up to [exitWithin] for
  /// them to exit.
  Future<void> release() async {
    _released = true;
    final listeners = [..._listeners];
    _listeners.clear();
    final exiting = [for (final carried in _carried) carried.exited];
    stopCarrying();
    for (final listener in listeners) {
      await listener.close();
    }
    await Future.wait(exiting).timeout(exitWithin, onTimeout: () => const []);
  }

  /// How many connections are pending or carried.
  int get connections => _carried.length;
}

/// One accepted connection and the process that carries it.
///
/// The client's side is a raw socket, so that each read takes no more than is asked: a buffered socket reads whatever
/// the system holds, megabytes at once.
class _Carried {
  _Carried(this.carrier, this.client, this.role);

  final LoopbackCarrier carrier;
  final RawSocket client;
  final CarriedRole role;
  Process? _process;
  Timer? _handshake;
  StreamSubscription<RawSocketEvent>? _events;
  StreamSubscription<List<int>>? _output;
  bool _over = false;
  bool _starting = true;
  final _exited = Completer<void>();

  /// Completes once its process exited, or none was started: only then is its place under the caps free.
  Future<void> get exited => _exited.future;

  /// Bytes read from the client and not yet flushed into the process.
  int _toProcess = 0;

  /// Bytes of the process for the client, not yet written.
  final _toClient = <List<int>>[];
  int _toClientBytes = 0;
  bool _outputDone = false;

  static const _mostPerRead = 16 * 1024;

  Future<void> start() async {
    _handshake = Timer(carrier.budget.handshake, end);
    client.readEventsEnabled = false;
    _events = client.listen(_event, onError: (Object _) => end(), onDone: end);
    final Process process;
    try {
      process = await carrier._carry(role);
    } on Object {
      _starting = false;
      end();
      _done();
      return;
    }
    _starting = false;
    if (_over) {
      // It started after its connection was let go: nothing may keep it running.
      _stop(process);
      return;
    }
    _process = process;
    // A child gone mid-write fails here, unawaited otherwise.
    unawaited(process.stdin.done.then<void>((_) {}, onError: (Object _) => end()));
    unawaited(process.stderr.drain<void>().then<void>((_) {}, onError: (Object _) {}));
    // What it said last reaches the client through its output's end; one that ended and keeps its output open does not
    // hold the connection.
    unawaited(
      process.exitCode.then<void>((code) {
        carrier.onExit?.call(role, code);
        Timer(const Duration(seconds: 2), end);
      }, onError: (Object _) => end()),
    );
    _output = process.stdout.listen(
      _fromProcess,
      onError: (Object _) => end(),
      onDone: () {
        _outputDone = true;
        _endOnceWritten();
      },
      cancelOnError: true,
    );
    client.readEventsEnabled = true;
  }

  void _event(RawSocketEvent event) {
    if (_over) return;
    if (event == RawSocketEvent.read) {
      _fromClient();
    } else if (event == RawSocketEvent.write) {
      _write();
    } else if (event == RawSocketEvent.readClosed || event == RawSocketEvent.closed) {
      end();
    }
  }

  void _fromClient() {
    final process = _process;
    if (process == null || _toProcess >= carrier.budget.bufferedBytes) {
      client.readEventsEnabled = false;
      return;
    }
    final bytes = client.read(_mostPerRead);
    if (bytes == null || bytes.isEmpty) return;
    try {
      process.stdin.add(bytes);
    } on Object {
      end();
      return;
    }
    _toProcess += bytes.length;
    if (_toProcess < carrier.budget.bufferedBytes) return;
    client.readEventsEnabled = false;
    process.stdin.flush().then<void>((_) {
      _toProcess = 0;
      if (!_over) client.readEventsEnabled = true;
    }, onError: (Object _) => end());
  }

  void _fromProcess(List<int> bytes) {
    if (_over) return;
    _handshake?.cancel();
    _handshake = null;
    _toClient.add(bytes);
    _toClientBytes += bytes.length;
    _write();
    if (_toClientBytes >= carrier.budget.bufferedBytes) _output?.pause();
  }

  void _write() {
    while (_toClient.isNotEmpty && !_over) {
      final head = _toClient.first;
      final int written;
      try {
        written = client.write(head);
      } on SocketException {
        end();
        return;
      }
      _toClientBytes -= written;
      if (written < head.length) {
        _toClient[0] = head.sublist(written);
        client.writeEventsEnabled = true;
        return;
      }
      _toClient.removeAt(0);
    }
    if (_over) return;
    if (_toClientBytes < carrier.budget.bufferedBytes && (_output?.isPaused ?? false)) _output?.resume();
    _endOnceWritten();
  }

  void _endOnceWritten() {
    if (_outputDone && _toClient.isEmpty) end();
  }

  void end() {
    if (_over) return;
    _over = true;
    _handshake?.cancel();
    unawaited(_output?.cancel());
    unawaited(_events?.cancel());
    client.close();
    if (_process case final process?) {
      _stop(process);
    } else if (!_starting) {
      _done();
    }
  }

  /// Ends [process], forcing it when it does not stop, and frees the place once it exited.
  void _stop(Process process) {
    process.kill();
    process.exitCode
        .timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            process.kill(ProcessSignal.sigkill);
            return process.exitCode;
          },
        )
        .then<void>((_) => _done(), onError: (Object _) => _done());
  }

  void _done() {
    if (_exited.isCompleted) return;
    _exited.complete();
    carrier._exited(this);
  }
}
