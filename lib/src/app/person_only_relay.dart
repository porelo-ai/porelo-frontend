import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'forward_records.dart' show accountUid;

/// Binds one loopback port of the window's own, for a test to stand in.
typedef BindRelayPort = Future<ServerSocket> Function(InternetAddress address, int port);

/// Who opened [accepted], a connection to one of the window's loopback ports: the uid owning its other end, or null
/// where that cannot be told.
typedef ConnectionOwner = int? Function(Socket accepted);

/// A port the window could not hold for a forward, named with its family.
class RelayRefused implements Exception {
  /// Constructor taking the port, its address and what the system said.
  const RelayRefused(this.port, this.address, this.said);

  /// The port that could not be held.
  final int port;

  /// The loopback address it could not be held on.
  final InternetAddress address;

  /// What the system said.
  final String said;

  @override
  String toString() => 'port $port is busy on ${address.address}: $said';
}

/// The loopback ports of a forward, held by the window itself, each relayed to a unix socket of this account's own
/// that the forward's ssh listens on; **only the person's own connections are relayed**. A port of the loopback
/// address is reached by every local account of this computer, a socket in a folder of the person's alone by nobody
/// else: the relay asks the kernel who opened each connection, and closes any other at once, before anything is read
/// from it.
class PersonOnlyRelay {
  /// Constructor taking each port with the socket it is relayed to, the loopback addresses it is held on, and,
  /// injectable, how a port is bound, who opened a connection and whose connections are let through.
  PersonOnlyRelay(
    Map<int, String> targets, {
    required List<InternetAddress> loopbacks,
    BindRelayPort? bind,
    ConnectionOwner? owner,
    int? person,
  }) : targets = Map.unmodifiable(targets),
       loopbacks = List.unmodifiable(loopbacks),
       _bind = bind ?? bindPort,
       _owner = owner ?? ownerOnLinux,
       _person = person ?? accountUid();

  /// Each port held, with the socket it is relayed to.
  final Map<int, String> targets;

  /// The loopback addresses each port is held on.
  final List<InternetAddress> loopbacks;

  final BindRelayPort _bind;
  final ConnectionOwner _owner;
  final int _person;

  /// Whether forwards go through a relay here: where the kernel names who opened a connection, Linux. Elsewhere ssh
  /// binds the loopback port as before, and Windows' cards have a carrier of their own.
  static bool here = Platform.isLinux;

  /// How a port is bound where none is given: so that no other socket may bind or share it. A test suite sets one that
  /// binds a port of the system's choosing, so fixed ports of tests running side by side never meet.
  static BindRelayPort bindPort = bindExclusive;

  /// Binds [address]:[port] so that no other socket may bind or share it.
  static Future<ServerSocket> bindExclusive(InternetAddress address, int port) =>
      ServerSocket.bind(address, port, v6Only: address.type == InternetAddressType.IPv6, shared: false);

  /// Where a connection for a socket is relayed to now: the path to connect to, naming the very socket the forward was
  /// proven to make; null where nothing may be, and the connection is closed at once.
  String? Function(String socket) routeTo = _nowhere;

  static String? _nowhere(String _) => null;

  final List<ServerSocket> _listeners = [];
  final Set<Socket> _open = {};
  bool _closed = false;

  /// The ports as bound, by the port asked for: the same, except where a test's binding chose another.
  final Map<int, List<int>> bound = {};

  /// Binds every port on each loopback, or none: a port that cannot be held refuses with [RelayRefused]. Nothing is
  /// accepted before every port is bound; a [close] meanwhile leaves nothing bound.
  Future<void> hold() async {
    final held = <(ServerSocket, String)>[];
    Future<void> letGo() async {
      for (final (listener, _) in held) {
        await listener.close();
      }
      bound.clear();
    }

    for (final MapEntry(key: port, value: socket) in targets.entries) {
      for (final address in loopbacks) {
        final ServerSocket listener;
        try {
          listener = await _bind(address, port);
        } on SocketException catch (refused) {
          await letGo();
          throw RelayRefused(port, address, refused.osError?.message ?? refused.message);
        }
        held.add((listener, socket));
        (bound[port] ??= []).add(listener.port);
        if (_closed) {
          await letGo();
          return;
        }
      }
    }
    for (final (listener, socket) in held) {
      _listeners.add(listener);
      listener.listen((client) => unawaited(_accepted(client, socket)), onError: (Object _) {});
    }
  }

  Future<void> _accepted(Socket client, String socket) async {
    // Asked before anything is read: a connection of another account, or one whose owner cannot be told, gets nothing.
    final to = _closed ? null : routeTo(socket);
    if (to == null || _owner(client) != _person) {
      client.destroy();
      return;
    }
    _open.add(client);
    final Socket upstream;
    try {
      upstream = await Socket.connect(
        InternetAddress(to, type: InternetAddressType.unix),
        0,
        timeout: const Duration(seconds: 5),
      );
    } on SocketException {
      _open.remove(client);
      client.destroy();
      return;
    }
    if (_closed) {
      upstream.destroy();
      _open.remove(client);
      client.destroy();
      return;
    }
    _open.add(upstream);
    void end() {
      client.destroy();
      upstream.destroy();
      _open
        ..remove(client)
        ..remove(upstream);
    }

    // Byte for byte, each way; each side's end is passed on as an end of writing, and an error ends both.
    var halves = 2;
    Future<void> carry(Socket from, Socket to) async {
      try {
        await to.addStream(from);
        await to.close();
      } on Object {
        end();
        return;
      }
      if (--halves == 0) end();
    }

    unawaited(carry(client, upstream));
    unawaited(carry(upstream, client));
  }

  /// Lets go of every port and closes every connection relayed.
  Future<void> close() async {
    _closed = true;
    for (final each in _open.toList()) {
      each.destroy();
    }
    _open.clear();
    for (final listener in _listeners) {
      await listener.close();
    }
    _listeners.clear();
  }

  /// The uid owning the other end of [accepted] on Linux, read from the kernel's tables of TCP sockets: the row whose
  /// own address is the connection's remote one and whose remote address is its local one. A client reaching an IPv4
  /// port through an IPv6 socket has its row in the IPv6 table, its addresses mapped: both tables are read for those.
  /// Null where no such row is found, or not on Linux.
  static int? ownerOnLinux(Socket accepted, {@visibleForTesting String? Function(String path)? read}) {
    if (!Platform.isLinux && read == null) return null;
    final List<(String, String, String)> asked;
    try {
      final six = accepted.address.type == InternetAddressType.IPv6;
      asked = [
        (
          six ? '/proc/net/tcp6' : '/proc/net/tcp',
          kernelAddress(accepted.remoteAddress, accepted.remotePort),
          kernelAddress(accepted.address, accepted.port),
        ),
        if (!six)
          (
            '/proc/net/tcp6',
            kernelAddress(_mapped(accepted.remoteAddress), accepted.remotePort),
            kernelAddress(_mapped(accepted.address), accepted.port),
          ),
      ];
    } on Object {
      return null;
    }
    final found = <List<String>>[];
    for (final (table, local, remote) in asked) {
      final String? rows;
      try {
        rows = (read ?? _readFile)(table);
      } on FileSystemException {
        continue; // a table not there holds no row: IPv6 may be off
      }
      found.addAll(_rowsOf(rows ?? '', local, remote));
    }
    return _ownerOf(found);
  }

  static String? _readFile(String path) => File(path).readAsStringSync();

  /// [address], an IPv4 one, as an IPv6 socket names it: `::ffff:a.b.c.d`.
  static InternetAddress _mapped(InternetAddress address) =>
      InternetAddress.fromRawAddress(Uint8List.fromList([...List.filled(10, 0), 0xff, 0xff, ...address.rawAddress]));

  /// The states of a client's end that is still its own: connected (`01`), or done writing and still held (`04`,
  /// `05`). Others, and any end no process holds any more (inode 0, whose uid the kernel gives as 0), name nobody.
  static const _live = {'01', '04', '05'};

  /// The uid of the one row of [rows], a `/proc/net/tcp` table, whose own address is [local] and whose remote one is
  /// [remote], both as [kernelAddress] writes them, held by a process and still connected; null where there is none,
  /// or more than one owner. A row of an end no process holds is never read for its owner, as its uid reads 0, root's.
  @visibleForTesting
  static int? ownerIn(String rows, {required String local, required String remote}) =>
      _ownerOf(_rowsOf(rows, local, remote));

  static List<List<String>> _rowsOf(String rows, String local, String remote) => [
    for (final line in rows.split('\n').skip(1))
      if (line.trim().split(RegExp(r'\s+')) case final fields
          when fields.length >= 10 && fields[1].toUpperCase() == local && fields[2].toUpperCase() == remote)
        fields,
  ];

  static int? _ownerOf(List<List<String>> rows) {
    int? owner;
    for (final fields in rows) {
      final uid = int.tryParse(fields[7]);
      final inode = int.tryParse(fields[9]);
      if (uid == null || inode == null || inode == 0 || !_live.contains(fields[3].toUpperCase())) return null;
      if (owner != null && owner != uid) return null;
      owner = uid;
    }
    return owner;
  }

  /// [address]:[port] as the kernel's TCP tables write them: each four bytes of the address in the machine's order, as
  /// hex, and the port as four hex digits. Little-endian, as every Linux this window runs on.
  @visibleForTesting
  static String kernelAddress(InternetAddress address, int port) {
    final bytes = address.rawAddress;
    final hex = StringBuffer();
    for (var at = 0; at < bytes.length; at += 4) {
      for (var i = 3; i >= 0; i--) {
        hex.write(bytes[at + i].toRadixString(16).padLeft(2, '0'));
      }
    }
    return '${hex.toString().toUpperCase()}:${port.toRadixString(16).padLeft(4, '0').toUpperCase()}';
  }
}
