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
    )..routeTo = (to) => relays && to == socket ? socket : null;
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

  // Harm: a socket put at the forward's path after its ssh was proven to make it reached in its place.
  test('a connection goes to the socket the forward names for it, never to whatever is at the path now', () async {
    final proven = '${folder.path}/proven';
    final other = await ServerSocket.bind(InternetAddress(proven, type: InternetAddressType.unix), 0);
    addTearDown(other.close);
    other.listen((connection) {
      connection.write('proven');
      unawaited(connection.flush().then((_) => connection.destroy()));
    });
    final relay = await held();
    relay.routeTo = (to) => to == socket ? proven : null;

    expect(await through(relay.bound[0]!.first, 'hello'), 'proven');
    expect(reached, 0);
  });

  /// One TCP table row, as the kernel writes it: [local] and [remote] in its form, its state, owner and inode.
  String row(String local, String remote, {String state = '01', int uid = 1000, int inode = 7}) =>
      '   0: $local $remote $state 00000000:00000000 00:00000000 00000000 $uid        0 $inode 1\n';
  const head = '  sl  local_address rem_address   st tx_queue rx_queue tr tm->when retrnsmt   uid  timeout inode\n';
  final client = PersonOnlyRelay.kernelAddress(InternetAddress.loopbackIPv4, 0x9876);
  final server = PersonOnlyRelay.kernelAddress(InternetAddress.loopbackIPv4, 0x1F90);

  // Harm: a connection whose client closed before it was looked up, its socket orphaned and owned by root in the
  // kernel's table, let in as root's when the window runs as root.
  test("a client end no process holds any more names no owner, whatever uid the table gives it", () {
    for (final orphan in [
      row(client, server, state: '04', uid: 0, inode: 0),
      row(client, server, state: '01', uid: 0, inode: 0),
      row(client, server, state: '06', uid: 0, inode: 9),
      row(client, server, state: '07', uid: 0, inode: 9),
    ]) {
      final rows = '$head${row(server, client, uid: 0)}$orphan';

      expect(
        PersonOnlyRelay.ownerIn(rows, local: client, remote: server),
        isNull,
        reason: orphan,
      );
    }
    // A client still holding its end, done writing, is still the person's.
    expect(
      PersonOnlyRelay.ownerIn(
        '$head${row(client, server, state: '05', uid: 1000)}',
        local: client,
        remote: server,
      ),
      1000,
    );
  });

  // Harm: the row of a connection from the same port to another place taken for this one's, letting its owner in.
  test("only the row whose remote address is the connection's own end is read", () {
    final elsewhere = PersonOnlyRelay.kernelAddress(InternetAddress.loopbackIPv4, 80);
    final rows = '$head${row(client, elsewhere, uid: 1002)}${row(client, server, uid: 1001)}';

    expect(PersonOnlyRelay.ownerIn(rows, local: client, remote: server), 1001);
  });

  // Harm: of two rows naming the same connection, the last one's owner believed.
  test('two rows naming the connection with different owners name no owner', () {
    final rows = '$head${row(client, server, uid: 1001)}${row(client, server, uid: 1002, inode: 8)}';

    expect(PersonOnlyRelay.ownerIn(rows, local: client, remote: server), isNull);
  });

  // Harm: the window's own end read for who opened the connection, which is always the person, letting anybody in.
  test("the owner of an accepted connection is its client's, read from the kernel's table as it stands", () async {
    final listener = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(listener.close);
    final accepted = listener.first;
    final opened = await Socket.connect(InternetAddress.loopbackIPv4, listener.port);
    addTearDown(opened.destroy);
    final served = await accepted;
    addTearDown(served.destroy);
    final mine = PersonOnlyRelay.kernelAddress(opened.address, opened.port);
    // The kernel's own table, with the client's end given to another account.
    String? another(String path) => [
      for (final line in File(path).readAsLinesSync())
        if (line.trim().split(RegExp(r'\s+')) case final fields when fields.length > 9 && fields[1] == mine)
          ([...fields]..[7] = '4242').join(' ')
        else
          line,
    ].join('\n');

    expect(PersonOnlyRelay.ownerOnLinux(served, read: another), 4242);
  });

  // Harm: the person's own client, connecting to the IPv4 port through an IPv6 socket, turned away.
  test("a client reaching the IPv4 port through an IPv6 socket is the person's own", () async {
    final listener = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(listener.close);
    final accepted = listener.first;
    final opened = await Socket.connect(InternetAddress('::ffff:127.0.0.1'), listener.port);
    addTearDown(opened.destroy);
    final served = await accepted;
    addTearDown(served.destroy);

    expect(PersonOnlyRelay.ownerOnLinux(served), accountUid());
  }, skip: HostCardSsh.ipv6Loopback ? null : 'no IPv6 here');

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
