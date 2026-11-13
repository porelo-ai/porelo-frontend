// Linux only: who opened a connection is read from Linux's own tables.
@Tags(['linux'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/forward_records.dart' show accountUid;
import 'package:porelo_frontend/src/app/person_only_relay.dart';
import 'package:porelo_host/porelo_host.dart';

/// A forward's port is held by the window, and only the person's own connections reach the socket behind it.
void main() {
  late Directory folder;
  late String socket;
  late ServerSocket service;
  late List<String> heard;
  late int reached;

  setUp(() async {
    folder = Directory.systemTemp.createTempSync('r-');
    Process.runSync('chmod', <String>['700', folder.path]);
    socket = '${folder.path}/s';
    heard = [];
    reached = 0;
    service = await ServerSocket.bind(InternetAddress(socket, type: InternetAddressType.unix), 0);
    service.listen((connection) {
      reached++;
      connection.listen((bytes) {
        heard.add(utf8.decode(bytes));
        connection.add(bytes);
      }, onDone: connection.destroy);
    });
    addTearDown(() async {
      await service.close();
      folder.deleteSync(recursive: true);
    });
  });

  Future<PersonOnlyRelay> held({ConnectionOwner? owner, bool relays = true}) async {
    final relay = PersonOnlyRelay(
      {0: socket},
      loopbacks: [InternetAddress.loopbackIPv4, if (HostCardSsh.ipv6Loopback) InternetAddress.loopbackIPv6],
      bind: PersonOnlyRelay.bindExclusive,
      owner: owner,
    )..relaysTo = (to) => relays && to == socket;
    await relay.hold();
    addTearDown(relay.close);
    return relay;
  }

  /// What comes back for [said] through [port], or null where the connection was closed without an answer.
  Future<String?> through(int port, String said, {InternetAddress? at}) async {
    final connection = await Socket.connect(at ?? InternetAddress.loopbackIPv4, port);
    connection.write(said);
    try {
      await connection.flush();
      final back = await connection.timeout(const Duration(seconds: 2)).toList();
      return back.isEmpty ? null : utf8.decode(back.expand((each) => each).toList());
    } on SocketException {
      return null;
    } on TimeoutException {
      return 'kept open';
    } finally {
      connection.destroy();
    }
  }

  Future<String?> echoed(int port, String said, {InternetAddress? at}) async {
    final connection = await Socket.connect(at ?? InternetAddress.loopbackIPv4, port);
    connection.write(said);
    await connection.flush();
    final back = await connection.timeout(const Duration(seconds: 2)).first;
    connection.destroy();
    return utf8.decode(back);
  }

  // Harm: the forward's service unreachable for the person the window runs for.
  test("the person's own connection is relayed byte for byte, on each loopback", () async {
    final relay = await held();
    final port = relay.bound[0]!.first;

    expect(await echoed(port, 'GET / HTTP/1.1\r\n\r\n'), 'GET / HTTP/1.1\r\n\r\n');
    if (HostCardSsh.ipv6Loopback) {
      expect(await echoed(relay.bound[0]!.last, 'six', at: InternetAddress.loopbackIPv6), 'six');
    }
  });

  // Harm: another local account reaches the host's forge as the person, or sends a sign-in its redirect.
  test("another account's connection is closed, with nothing read from it or sent on", () async {
    final relay = await held(owner: (_) => accountUid() + 1);

    expect(await through(relay.bound[0]!.first, 'GET / HTTP/1.1\r\n\r\n'), isNull);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(reached, 0);
    expect(heard, isEmpty);
  });

  // Harm: a connection whose owner could not be told taken for the person's.
  test('a connection whose owner cannot be told is closed', () async {
    final relay = await held(owner: (_) => null);

    expect(await through(relay.bound[0]!.first, 'hello'), isNull);
    expect(reached, 0);
  });

  // Harm: a connection relayed to a socket the forward's ssh was not seen to make, or while the forward is down.
  test('nothing is relayed while the forward does not say so', () async {
    final relay = await held(relays: false);

    expect(await through(relay.bound[0]!.first, 'hello'), isNull);
    expect(reached, 0);
  });

  // Harm: the owner looked up wrongly lets another account in, or keeps the person out.
  test("the kernel's table names this account as the owner of a connection it opened", () async {
    for (final loopback in [InternetAddress.loopbackIPv4, if (HostCardSsh.ipv6Loopback) InternetAddress.loopbackIPv6]) {
      final listener = await ServerSocket.bind(loopback, 0);
      addTearDown(listener.close);
      final accepted = listener.first;
      final client = await Socket.connect(loopback, listener.port);
      addTearDown(client.destroy);
      final server = await accepted;
      addTearDown(server.destroy);

      expect(PersonOnlyRelay.ownerOnLinux(server), accountUid(), reason: loopback.address);
    }
  });

  // Harm: the server's own end of the connection, always the window's, taken for who opened it.
  test("only the row of the connection's other end is read, never the window's own end", () {
    const rows =
        '  sl  local_address rem_address   st tx_queue rx_queue tr tm->when retrnsmt   uid  timeout inode\n'
        '   0: 0100007F:1F90 0100007F:9876 01 00000000:00000000 00:00000000 00000000  1000        0 1 1\n'
        '   1: 0100007F:9876 0100007F:1F90 01 00000000:00000000 00:00000000 00000000  1001        0 2 1\n';

    expect(
      PersonOnlyRelay.ownerIn(
        rows,
        local: PersonOnlyRelay.kernelAddress(InternetAddress.loopbackIPv4, 0x9876),
        remote: PersonOnlyRelay.kernelAddress(InternetAddress.loopbackIPv4, 0x1F90),
      ),
      1001,
    );
    expect(PersonOnlyRelay.kernelAddress(InternetAddress.loopbackIPv6, 8080), '00000000000000000000000001000000:1F90');
    expect(PersonOnlyRelay.ownerIn(rows, local: '0100007F:0001', remote: '0100007F:1F90'), isNull);
  });

  // Harm: a port another program holds on either loopback left to it beside the window's own.
  test('a port held by another program on either loopback refuses, holding none', () async {
    for (final loopback in [InternetAddress.loopbackIPv4, if (HostCardSsh.ipv6Loopback) InternetAddress.loopbackIPv6]) {
      final other = await ServerSocket.bind(loopback, 0, v6Only: true);
      final relay = PersonOnlyRelay(
        {other.port: socket},
        loopbacks: [InternetAddress.loopbackIPv4, if (HostCardSsh.ipv6Loopback) InternetAddress.loopbackIPv6],
        bind: PersonOnlyRelay.bindExclusive,
      );
      await expectLater(relay.hold(), throwsA(isA<RelayRefused>()));
      await other.close();
      // Nothing of it is held: the port binds again on both.
      final again = await ServerSocket.bind(InternetAddress.loopbackIPv4, other.port);
      await again.close();
    }
  });
}
