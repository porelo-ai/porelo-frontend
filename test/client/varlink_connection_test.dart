// Linux only: it speaks over unix sockets, which dart:io cannot open on Windows.
@Tags(<String>['linux'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/wire/varlink_connection.dart';
import 'package:porelo_frontend/src/wire/varlink_exception.dart';

/// The transport against a peer that goes away, which a forward does when its far end has no
/// socket: ssh accepts the connection here, then hangs up.
void main() {
  late Directory scratch;
  late ServerSocket server;
  late String socketPath;

  setUp(() async {
    scratch = Directory.systemTemp.createTempSync('varlink');
    socketPath = '${scratch.path}/porelod.sock';
    server = await ServerSocket.bind(InternetAddress(socketPath, type: InternetAddressType.unix), 0);
    server.listen((client) => client.destroy());
  });

  tearDown(() async {
    await server.close();
    scratch.deleteSync(recursive: true);
  });

  /// A peer that answers with something no reader can use.
  ///
  /// Every one of these used to throw inside the socket callback, where a throw does not reach
  /// `onError`: it escaped the zone and the waiting call hung for its full timeout with nothing
  /// said. The point of each test is not the message but that the *call* ends, and ends as a lost
  /// connection.
  Future<void> answering(List<int> bytes) async {
    await server.close();
    server = await ServerSocket.bind(InternetAddress(socketPath, type: InternetAddressType.unix), 0);
    server.listen((client) {
      client.add(bytes);
      // Left open deliberately: a closing peer would end the call by itself and prove nothing.
    });
  }

  test('a reply that is not UTF-8 ends the call, rather than escaping', () async {
    await answering(<int>[0xC3, 0x28, 0]);
    final connection = await VarlinkConnection.open(socketPath);

    await expectLater(
      connection.call('org.fuin.porelo.Tasks1.List', const {}, const Duration(seconds: 2)),
      throwsA(isA<VarlinkDisconnected>().having((ex) => ex.message, 'message', contains('not readable'))),
    );
  });

  test('a reply that is not JSON ends the call', () async {
    await answering(<int>[...utf8.encode('{"parameters": '), 0]);
    final connection = await VarlinkConnection.open(socketPath);

    await expectLater(
      connection.call('org.fuin.porelo.Tasks1.List', const {}, const Duration(seconds: 2)),
      throwsA(isA<VarlinkDisconnected>().having((ex) => ex.message, 'message', contains('not readable'))),
    );
  });

  test('a reply that is JSON but not an object ends the call', () async {
    await answering(<int>[...utf8.encode('[1, 2, 3]'), 0]);
    final connection = await VarlinkConnection.open(socketPath);

    await expectLater(
      connection.call('org.fuin.porelo.Tasks1.List', const {}, const Duration(seconds: 2)),
      throwsA(isA<VarlinkDisconnected>().having((ex) => ex.message, 'message', contains('not an object'))),
    );
  });

  test('a reply that never ends is cut off rather than buffered without limit', () async {
    // More than the limit, in chunks, with no NUL anywhere: what a peer that has lost its framing
    // looks like. Without the bound this grows until the process dies.
    await server.close();
    server = await ServerSocket.bind(InternetAddress(socketPath, type: InternetAddressType.unix), 0);
    final megabyte = Uint8List(1024 * 1024)..fillRange(0, 1024 * 1024, 0x61);
    server.listen((client) async {
      try {
        for (var sent = 0; sent < VarlinkConnection.mostBytesPerReply + megabyte.length; sent += megabyte.length) {
          client.add(megabyte);
          await client.flush();
        }
      } on SocketException {
        // Cut off, which is the point of the test.
      }
    });
    final connection = await VarlinkConnection.open(socketPath);

    await expectLater(
      connection.call('org.fuin.porelo.Tasks1.List', const {}, const Duration(seconds: 10)),
      throwsA(isA<VarlinkDisconnected>().having((ex) => ex.message, 'message', contains('without ending'))),
    );
  });

  test('a reply split across chunks is read as one, and two in one chunk as two', () async {
    // There is no length prefix: the NUL is the only end there is, and a socket delivers bytes
    // when it feels like it. Both halves of that matter — a reply arriving in pieces must not be
    // read as several, and several arriving together must not be read as one.
    await server.close();
    server = await ServerSocket.bind(InternetAddress(socketPath, type: InternetAddressType.unix), 0);
    server.listen((client) async {
      client.add(utf8.encode('{"parameters": {"one'));
      await client.flush();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      client.add(<int>[...utf8.encode('": true}, "continues": true}'), 0]);
      await client.flush();
      // The second and third replies in a single chunk, for the same call's stream.
      client.add(<int>[
        ...utf8.encode('{"parameters": {"two": true}, "continues": true}'),
        0,
        ...utf8.encode('{"parameters": {"three": true}}'),
        0,
      ]);
      await client.flush();
    });
    final connection = await VarlinkConnection.open(socketPath);

    final replies = await connection
        .callMore('org.fuin.porelo.Tasks1.Watch')
        .toList()
        .timeout(const Duration(seconds: 10));

    expect(replies, [
      {'one': true},
      {'two': true},
      {'three': true},
    ]);
  });

  /// A frame that stops halfway, in the two ways a peer can stop it.
  ///
  /// Named by the round-2 review: the synthetic failures above prove the parser, and this proves
  /// the end of a frame that never comes. **The two ways are different and both had to be
  /// checked** — a clean close arrives as the stream ending, a reset arrives as a socket error,
  /// and only one of those paths was exercised before. Neither may wait for the timeout: that is
  /// what the 20-second deadline in each is for, since a test with a short one would pass on the
  /// timeout and prove nothing.
  Future<void> halfAFrameThen(void Function(Socket) stop) async {
    await server.close();
    server = await ServerSocket.bind(InternetAddress(socketPath, type: InternetAddressType.unix), 0);
    server.listen((client) async {
      client.add(utf8.encode('{"parameters": {"half": tr'));
      await client.flush();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      stop(client);
    });
  }

  test('a peer that closes cleanly mid-frame ends the call, not the clock', () async {
    await halfAFrameThen((client) => client.close());
    final connection = await VarlinkConnection.open(socketPath);

    await expectLater(
      connection.call('org.fuin.porelo.Tasks1.List', const {}, const Duration(seconds: 20)),
      throwsA(
        isA<VarlinkDisconnected>().having(
          (ex) => ex.message,
          'message',
          contains('closed before the call was answered'),
        ),
      ),
    );
  });

  test('a peer that resets mid-frame reports the transport, not a timeout', () async {
    await halfAFrameThen((client) => client.destroy());
    final connection = await VarlinkConnection.open(socketPath);

    await expectLater(
      connection.call('org.fuin.porelo.Tasks1.List', const {}, const Duration(seconds: 20)),
      // The transport's own sentence — "Connection reset by peer" — rather than ours. What must
      // never appear is the deadline: that would mean nothing noticed the socket had gone.
      throwsA(isA<VarlinkDisconnected>().having((ex) => ex.message, 'message', isNot(contains('not answered within')))),
    );
  });

  test('a peer that hangs up is a lost connection, never an error that escapes', () async {
    final connection = await VarlinkConnection.open(socketPath);
    // Written after the peer has gone, so the write itself fails.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await expectLater(connection.call('org.fuin.porelo.Tasks1.List'), throwsA(isA<VarlinkDisconnected>()));
    // Long enough for a failed write to surface where nobody is waiting for it.
    await Future<void>.delayed(const Duration(milliseconds: 200));
  });
}
