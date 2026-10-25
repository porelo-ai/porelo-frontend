import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Thrown from a handler to refuse the call, the way the daemon refuses one.
///
/// A method that refuses depending on *what it was asked* is a real thing — `NoSuchLog` is
/// exactly that — and a stand-in that could only refuse a whole method could not produce it.
class MockRefusal implements Exception {
  /// Constructor taking the fully-qualified error name and whatever goes with it.
  const MockRefusal(this.error, [this.parameters = const <String, dynamic>{}]);

  /// Fully-qualified error name.
  final String error;

  /// Whatever the error carries.
  final Map<String, dynamic> parameters;
}

/// A stand-in for `porelod`, speaking real varlink over a real unix socket.
///
/// **Not scaffolding until the backend is ready.** It is permanent, because it produces states a
/// real daemon cannot be made to produce on demand, and those are the hard ones: a method missing
/// because the backend is older, an outcome this build has never heard of, a stream cut
/// mid-flight, a task refusing to be removed because it holds work. A real daemon always has all
/// its methods and only ever sends values it knows, so those rules are otherwise unenforceable.
///
/// It also means the suite needs no podman, no containers and no runtime - so it runs anywhere.
class MockDaemon {
  /// Registers stateful room membership methods; tests may replace or remove them.
  MockDaemon() {
    method(
      'MessageMembers',
      (parameters) => <String, dynamic>{
        'members': <Map<String, dynamic>>[
          for (final member in membersOf[parameters['project']] ?? const <Map<String, dynamic>>[])
            Map<String, dynamic>.of(member),
        ],
      },
    );
    method('RemoveMessageMember', (parameters) {
      final members = membersOf[parameters['project']];
      final person = parameters['person'];
      final index = members?.indexWhere((member) => member['person'] == person) ?? -1;
      if (index < 0) {
        throw MockRefusal('$interfaceName.NoSuchMember', <String, dynamic>{'person': person});
      }
      members!.removeAt(index);
      return <String, dynamic>{'user': '', 'kept': false, 'why': ''};
    });
  }

  /// The room members returned by project, changed only by confirmed mock calls.
  final Map<String, List<Map<String, dynamic>>> membersOf = <String, List<Map<String, dynamic>>>{};

  /// Interfaces this pretends to serve, in the order `GetInfo` reports them.
  ///
  /// Set it to something newer to check that a client picks the highest name it understands, or
  /// to something older to check it refuses politely.
  List<String> interfaces = const ['org.varlink.service', 'org.fuin.porelo.Tasks1'];

  /// Interface the methods below are registered under.
  String interfaceName = 'org.fuin.porelo.Tasks1';

  /// Version reported by `GetInfo`.
  String version = '0.1.0-mock';

  /// What this returns from `GetInterfaceDescription`, when anything.
  String? description;

  /// Cuts every open connection the moment the next reply would be sent.
  ///
  /// For the requirement that a lost tunnel reads as a disconnection and never as a machine with
  /// nothing running on it.
  bool severed = false;

  final Map<String, _Handler> _methods = {};
  final List<Socket> _clients = [];
  ServerSocket? _server;
  Directory? _directory;

  /// Where this is listening. Valid once [start] has completed.
  String get socketPath => _path;
  late String _path;

  /// Registers a method that answers once.
  ///
  /// The name is bare - `List`, not the full interface - and is qualified with [interfaceName],
  /// so pointing the mock at a different interface moves every method with it.
  void method(String name, FutureOr<Map<String, dynamic>> Function(Map<String, dynamic>) answer) {
    _methods['$interfaceName.$name'] = _Handler.single(answer);
  }

  /// Registers a method that streams.
  ///
  /// The test drives the events; nothing here is on a timer. A mock that emitted on wall clock
  /// makes stream tests flaky, and flaky tests get deleted rather than fixed.
  ///
  /// [isFinal] lets a controlled finite stream send progress without holding one reply back.
  void stream(
    String name,
    Stream<Map<String, dynamic>> Function(Map<String, dynamic>) events, {
    bool Function(Map<String, dynamic>)? isFinal,
  }) {
    _methods['$interfaceName.$name'] = _Handler.streaming(events, isFinal);
  }

  /// Registers a method that refuses.
  void fails(String name, String error, [Map<String, dynamic> parameters = const {}]) {
    _methods['$interfaceName.$name'] = _Handler.failing(error, parameters);
  }

  /// Registers a method that streams endlessly, sending each event as it happens.
  ///
  /// Different from [stream] and the difference matters. [stream] holds each event back until the
  /// next one arrives, because a *finite* stream has to know which reply is its last. `Watch` and
  /// `Prompts` are not finite - a real daemon keeps them open for as long as the connection lives
  /// - and against a held-back stream every change reaches the interface one change late, which
  /// looks exactly like an interface that ignores its own events.
  void pushes(String name, Stream<Map<String, dynamic>> Function(Map<String, dynamic>) events) {
    _methods['$interfaceName.$name'] = _Handler.pushing(events);
  }

  /// Registers a method that accepts the call and never answers it.
  ///
  /// A wedged backend, which is a real state rather than a contrived one: a daemon whose event
  /// loop is blocked accepts connections and then says nothing, so the socket looks healthy and
  /// every call hangs. Met for real while building the frame.
  void neverAnswers(String name) {
    _methods['$interfaceName.$name'] = _Handler.streaming((_) => StreamController<Map<String, dynamic>>().stream, null);
  }

  /// Removes a method, so calling it answers `MethodNotFound`.
  ///
  /// This is how a backend older than the interface is simulated, and it is the only way to prove
  /// that a feature degrades instead of the whole client failing.
  void remove(String name) => _methods.remove('$interfaceName.$name');

  /// Binds the socket and starts answering.
  ///
  /// The directory is short on purpose: a unix socket path is limited to about 108 bytes on
  /// Linux, and a test harness's temporary directory can reach that on its own.
  Future<void> start() async {
    _directory = await Directory.systemTemp.createTemp('skm');
    _path = '${_directory!.path}/d.sock';
    _server = await ServerSocket.bind(InternetAddress(_path, type: InternetAddressType.unix), 0);
    _server!.listen(_serve);
  }

  /// Stops answering and removes the socket.
  Future<void> stop() async {
    for (final client in List<Socket>.from(_clients)) {
      client.destroy();
    }
    _clients.clear();
    await _server?.close();
    await _directory?.delete(recursive: true);
  }

  /// Methods that close the connection politely instead of answering.
  ///
  /// Different from [severConnections] and the difference matters: a destroyed socket surfaces as
  /// a socket error, while a *graceful* close mid-call surfaces as a stream simply ending. The
  /// second is the dangerous one - it looks like "nothing more to say" and would render as a
  /// machine with no tasks on it.
  final Set<String> hangUpOn = <String>{};

  /// Drops every open connection now, as a tunnel does.
  void severConnections() {
    severed = true;
    for (final client in List<Socket>.from(_clients)) {
      client.destroy();
    }
    _clients.clear();
  }

  void _serve(Socket client) {
    _clients.add(client);
    // A client that goes away mid-write reports it here rather than from add(), and an
    // unhandled asynchronous error fails whatever test is running. Leaving is normal: it is
    // what canceling a stream looks like from this end.
    unawaited(client.done.catchError((Object _) => client));
    final buffer = BytesBuilder();
    client.listen(
      (chunk) {
        for (final byte in chunk) {
          if (byte != 0) {
            buffer.addByte(byte);
            continue;
          }
          final call = jsonDecode(utf8.decode(buffer.takeBytes())) as Map<String, dynamic>;
          unawaited(_handle(client, call));
        }
      },
      onError: (Object _) {},
      onDone: () => _clients.remove(client),
      cancelOnError: true,
    );
  }

  Future<void> _handle(Socket client, Map<String, dynamic> call) async {
    final method = call['method'];
    final raw = call['parameters'];
    final parameters = raw is Map<String, dynamic> ? raw : <String, dynamic>{};

    if (method == 'org.varlink.service.GetInfo') {
      return _send(client, {
        'parameters': {'vendor': 'fuin.org', 'product': 'Porelo', 'version': version, 'interfaces': interfaces},
      });
    }
    if (method == 'org.varlink.service.GetInterfaceDescription') {
      if (description == null) {
        return _send(client, {
          'error': 'org.varlink.service.InterfaceNotFound',
          'parameters': {'interface': '${parameters['interface']}'},
        });
      }
      return _send(client, {
        'parameters': {'description': description},
      });
    }

    if (hangUpOn.contains('$method'.split('.').last)) {
      _clients.remove(client);
      await client.close();
      return;
    }

    final handler = _methods[method];
    if (handler == null) {
      return _send(client, {
        'error': 'org.varlink.service.MethodNotFound',
        'parameters': {'method': '$method'},
      });
    }
    await handler.run(parameters, call['more'] == true, (reply) => _send(client, reply));
  }

  void _send(Socket client, Map<String, dynamic> message) {
    if (severed) return;
    try {
      client.add(utf8.encode(jsonEncode(message)));
      client.add(const [0]);
    } on StateError {
      // The client left. That is how a canceled stream looks from here, and it is normal.
    } on SocketException {
      // The same thing, seen a moment later: the socket is already gone rather than merely
      // closed. Canceling a stream is an ordinary act and must not fail the daemon.
    }
  }
}

class _Handler {
  final FutureOr<Map<String, dynamic>> Function(Map<String, dynamic>)? _single;
  final Stream<Map<String, dynamic>> Function(Map<String, dynamic>)? _events;
  final String? _error;
  final Map<String, dynamic> _errorParameters;
  final bool _immediate;
  final bool Function(Map<String, dynamic>)? _isFinal;

  _Handler.single(this._single)
    : _events = null,
      _error = null,
      _errorParameters = const {},
      _immediate = false,
      _isFinal = null;

  _Handler.streaming(this._events, this._isFinal)
    : _single = null,
      _error = null,
      _errorParameters = const {},
      _immediate = false;

  _Handler.pushing(this._events)
    : _single = null,
      _error = null,
      _errorParameters = const {},
      _immediate = true,
      _isFinal = null;

  _Handler.failing(this._error, this._errorParameters)
    : _single = null,
      _events = null,
      _immediate = false,
      _isFinal = null;

  Future<void> run(Map<String, dynamic> parameters, bool more, void Function(Map<String, dynamic>) send) async {
    try {
      await _answer(parameters, more, send);
    } on MockRefusal catch (refusal) {
      send({'error': refusal.error, 'parameters': refusal.parameters});
    } on TypeError {
      // A parameter of the wrong type, as varlink refuses it: unanswered, it read as a wedged daemon.
      send({'error': 'org.varlink.service.InvalidParameter', 'parameters': const <String, dynamic>{}});
    }
  }

  Future<void> _answer(Map<String, dynamic> parameters, bool more, void Function(Map<String, dynamic>) send) async {
    if (_error != null) {
      return send({'error': _error, 'parameters': _errorParameters});
    }
    if (_single != null) {
      return send({'parameters': await _single(parameters)});
    }
    final isFinal = _isFinal;
    if (isFinal != null) {
      await for (final event in _events!(parameters)) {
        final finished = isFinal(event);
        send({'parameters': event, if (!finished) 'continues': true});
        if (finished) return;
      }
      throw StateError('The mock stream ended without its final reply');
    }
    Map<String, dynamic>? previous;
    if (_immediate) {
      await for (final event in _events!(parameters)) {
        previous = event;
        send({'parameters': event, 'continues': true});
      }
      // Repeating the last state rather than sending an empty reply: an empty one would reach a
      // client as a machine with nothing on it, which is the reading a stream must never produce.
      if (previous != null) send({'parameters': previous});
      return;
    }
    await for (final event in _events!(parameters)) {
      if (previous != null) {
        send({'parameters': previous, 'continues': true});
      }
      previous = event;
    }
    // The last event carries no 'continues', which is what ends the stream. Holding one back is
    // the only way to know which one that is.
    send({'parameters': previous ?? const <String, dynamic>{}});
  }
}
