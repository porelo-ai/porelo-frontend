import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'varlink_exception.dart';

/// One connection to a varlink service: over a unix socket, or over any byte stream, such as a
/// relay's standard input and output.
///
/// The whole protocol is here, and it is small: a JSON object per message, a NUL byte between
/// them, no length prefix and no request ids. Because there are no ids, **a connection carries one
/// call at a time** - so a stream gets its own connection, which costs nothing.
class VarlinkConnection {
  final StreamSink<List<int>> _out;
  final void Function() _end;

  /// Supplies transport diagnostics when a failed write would hide the reason it ended.
  final Future<VarlinkDisconnected> Function()? writeFailure;
  final StreamController<Map<String, dynamic>> _replies = StreamController<Map<String, dynamic>>();

  /// The most one reply may weigh before the connection is called broken.
  ///
  /// Generous: a log chunk or a long task list is a legitimate reply and there is no length prefix
  /// to size the buffer from, so the only way to know a reply has ended is the NUL. Finite,
  /// because a peer that never sends one would otherwise be answered with all the memory there is
  /// — and an interface killed by the daemon it watches has nothing left to report it with.
  static const int mostBytesPerReply = 8 * 1024 * 1024;

  bool _broken = false;

  /// Speaks over [incoming] and [outgoing], ending both with [destroy].
  ///
  /// **The bytes are the protocol, whatever carries them.** A relay's standard input and output
  /// (`wsl.exe -d <distro> -- porelo daemon connect`) are as good a way to a daemon as its socket,
  /// and a socket is only one way to get such a pair.
  VarlinkConnection.over({
    required Stream<List<int>> incoming,
    required StreamSink<List<int>> outgoing,
    required void Function() destroy,
    this.writeFailure,
  }) : _out = outgoing,
       _end = destroy {
    final buffer = BytesBuilder();
    // A write to a peer that has gone fails here, not where it was written, and a failure nobody
    // waits for escapes unhandled. It is the same lost connection as a read error.
    unawaited(outgoing.done.catchError((Object error) async => _lost(await writeFailure?.call() ?? error)));
    incoming.listen(
      (chunk) {
        // **Every failure in here is the connection, not an exception.** A throw inside this
        // callback does not reach `onError`: it escapes the zone, and the call waiting on the
        // reply hangs until its timeout with nothing said. So what a peer can produce — bytes
        // that are not UTF-8, text that is not JSON, JSON that is not an object, a reply with no
        // end — is caught here and reported as a lost connection.
        if (_broken) return;
        for (final byte in chunk) {
          if (byte != 0) {
            if (buffer.length >= mostBytesPerReply) {
              _breakOff('a reply passed $mostBytesPerReply bytes without ending');
              return;
            }
            buffer.addByte(byte);
            continue;
          }
          final bytes = buffer.takeBytes();
          final Object? decoded;
          try {
            decoded = jsonDecode(utf8.decode(bytes));
          } on FormatException catch (ex) {
            _breakOff('a reply was not readable: ${ex.message}');
            return;
          }
          if (decoded is! Map<String, dynamic>) {
            _breakOff('a reply was ${decoded.runtimeType}, not an object');
            return;
          }
          _replies.add(decoded);
        }
      },
      onError: _lost,
      onDone: _replies.close,
      cancelOnError: true,
    );
  }

  /// Reports the connection broken and stops reading it.
  ///
  /// The way in is destroyed rather than left open: a peer talking nonsense will go on talking,
  /// and there is nothing left here that could act on it.
  void _breakOff(String why) {
    _broken = true;
    _end();
    _lost(why);
  }

  void _lost(Object error) {
    if (!_replies.isClosed) _replies.addError(error is VarlinkDisconnected ? error : VarlinkDisconnected('$error'));
  }

  /// Opens a connection to the service listening on [socketPath].
  ///
  /// Throws [VarlinkDisconnected] rather than a platform error, because "there is no daemon
  /// there" and "the tunnel dropped" are the same thing to whatever has to render it.
  static Future<VarlinkConnection> open(String socketPath) async {
    try {
      final socket = await Socket.connect(InternetAddress(socketPath, type: InternetAddressType.unix), 0);
      return VarlinkConnection.over(incoming: socket, outgoing: socket, destroy: socket.destroy);
    } on SocketException catch (ex) {
      throw VarlinkDisconnected('cannot reach $socketPath: ${ex.message}');
    }
  }

  /// How long a single call may go unanswered before it is treated as a lost backend.
  ///
  /// A backend that accepts a connection and then says nothing is indistinguishable from one
  /// answering slowly, and an interface that waited on it forever would sit saying it was
  /// connecting with no way out. Generous, because stopping a task can genuinely take a while;
  /// finite, because "no answer" has to become an answer eventually.
  static const answerWithin = Duration(seconds: 30);

  /// Sends one call and returns its single reply.
  ///
  /// Only for calls that answer once. A stream deliberately has no deadline here: `Prompts` may
  /// legitimately have nothing to say for hours, and a timeout on it would report a working
  /// backend as a broken one.
  Future<Map<String, dynamic>> call(
    String method, [
    Map<String, dynamic> parameters = const {},
    Duration timeout = answerWithin,
  ]) async {
    _send(method, parameters, more: false);
    try {
      await for (final reply in _replies.stream.timeout(timeout)) {
        return _parameters(reply);
      }
    } on TimeoutException {
      throw VarlinkDisconnected('$method was not answered within ${timeout.inSeconds} seconds');
    }
    throw const VarlinkDisconnected('the connection closed before the call was answered');
  }

  /// Sends one call and returns every reply it produces.
  ///
  /// The stream ends when the service sends a reply without `continues`, or when the connection
  /// goes away - the latter as an error, never as a quiet completion. A stream that ends silently
  /// is indistinguishable from one with nothing to say, and that is how a truncated answer gets
  /// read as an empty machine.
  ///
  /// Built on an explicit subscription rather than `await for`, because **`await for` cannot be
  /// interrupted while it waits**. A generator paused on one only notices it has been canceled
  /// when the next event arrives - so leaving a `Watch` or a `Tail` hung until the daemon
  /// happened to say something, which on a quiet machine is for ever.
  Stream<Map<String, dynamic>> callMore(String method, [Map<String, dynamic> parameters = const {}]) {
    final replies = StreamController<Map<String, dynamic>>();
    StreamSubscription<Map<String, dynamic>>? reading;

    replies.onListen = () {
      _send(method, parameters, more: true);
      reading = _replies.stream.listen(
        (reply) {
          final Map<String, dynamic> answer;
          try {
            answer = _parameters(reply);
          } on VarlinkException catch (refusal) {
            replies.addError(refusal);
            unawaited(replies.close());
            return;
          }
          replies.add(answer);
          if (reply['continues'] != true) unawaited(replies.close());
        },
        onError: replies.addError,
        onDone: () {
          replies.addError(const VarlinkDisconnected('the stream ended without a final reply'));
          unawaited(replies.close());
        },
      );
    };
    replies.onCancel = () async => reading?.cancel();

    return replies.stream;
  }

  void _send(String method, Map<String, dynamic> parameters, {required bool more}) {
    final call = <String, dynamic>{'method': method, 'parameters': parameters};
    if (more) call['more'] = true;
    try {
      _out.add(utf8.encode(jsonEncode(call)));
      _out.add(const [0]);
    } catch (error) {
      unawaited(_lostWrite(error));
    }
  }

  Future<void> _lostWrite(Object error) async => _lost(await writeFailure?.call() ?? error);

  static Map<String, dynamic> _parameters(Map<String, dynamic> reply) {
    final error = reply['error'];
    if (error is String) {
      final parameters = reply['parameters'];
      throw VarlinkException(error, parameters is Map<String, dynamic> ? parameters : const {});
    }
    final parameters = reply['parameters'];
    return parameters is Map<String, dynamic> ? parameters : const {};
  }

  /// Closes the connection.
  ///
  /// Destroys it rather than waiting for the far end. `Socket.close()` completes only once the
  /// peer has closed too, and a daemon holding a stream open has no reason to — so awaiting it
  /// hangs for ever. Canceling a stream is an ordinary act, not an error: leaving a log view or
  /// closing a window does it, and neither may block.
  Future<void> close() async => _end();
}
