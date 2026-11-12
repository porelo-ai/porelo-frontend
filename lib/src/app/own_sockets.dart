import 'dart:io';

import 'package:flutter/foundation.dart';

import 'forward_records.dart';
import 'tunnel.dart' show ConnectToSocket, SocketProbe, connectToSocket, probeSocket;

/// The socket file at [path], held, when [pid] holds a listening socket bound to that very file: the proof that the
/// process made the socket now there, rather than only that it was started or that something is at the path. The
/// kernel names the file each socket is bound to by device and inode (`sock_diag`), and `/proc/<pid>/fd` names the
/// sockets the process holds; a socket somebody else bound at the path is not among them. That answer names the inode
/// in 32 bits only, so another file whose inode shares them reads alike: the file is therefore also connected to
/// through its held descriptor, and the socket the kernel reaches there must have been put to listen by [pid]. Null
/// where any of that is not seen.
HeldSocket? madeBy(int pid, String path, {@visibleForTesting List<BoundSocket>? Function() diagnose = boundSockets}) {
  final held = HeldSocket.at(path);
  if (held == null) return null;
  var made = false;
  try {
    final listening = {
      for (final bound in diagnose() ?? const <BoundSocket>[])
        if (bound.listening && boundTo(bound, held.identity)) 'socket:[${bound.socket}]',
    };
    made = listening.isNotEmpty && _holdsAny(pid, listening) && held.listenerPid() == pid;
    return made ? held : null;
  } finally {
    if (!made) held.release();
  }
}

bool _holdsAny(int pid, Set<String> sockets) {
  try {
    return Directory('/proc/$pid/fd').listSync(followLinks: false).any((fd) {
      try {
        return sockets.contains(Link(fd.path).targetSync());
      } on FileSystemException {
        return false; // closed meanwhile
      }
    });
  } on FileSystemException {
    return false;
  }
}

/// Removes the socket at [path] when it is a leftover nobody holds, and answers whether it did. It must be a socket
/// that no socket of this network namespace is bound to, a connect to it must be refused, and its name must still
/// name that same file when it is removed, in a directory this account alone may change. Anything that cannot be
/// proved keeps the path: a regular file, a socket bound and not listening yet, one that answers, one whose probe
/// failed for a reason of its own.
///
/// A socket bound in another network namespace, such as a container's with the directory mounted, is not seen by the
/// kernel's answer here; one of those that listens is still refused by the probe, one only bound is not. [afterProbe]
/// runs between the probe and the removal, for a test alone.
Future<bool> removeLeftover(
  String path, {
  ConnectToSocket connect = connectToSocket,
  @visibleForTesting void Function()? afterProbe,
  @visibleForTesting List<BoundSocket>? Function() diagnose = boundSockets,
}) async {
  final held = HeldSocket.at(path);
  if (held == null) return false;
  try {
    if (!_nobodyBinds(held, diagnose)) return false;
    if (await probeSocket(path, connect) != SocketProbe.nobody) return false;
    afterProbe?.call();
    if (!_nobodyBinds(held, diagnose)) return false;
    return removeSocketIfStill(path, held);
  } finally {
    held.release();
  }
}

// A socket file no socket is bound to: the kernel was asked, and named none bound to it.
bool _nobodyBinds(HeldSocket held, List<BoundSocket>? Function() diagnose) {
  final bound = diagnose();
  return bound != null && !bound.any((each) => boundTo(each, held.identity));
}

/// Whether [path] lies in a directory this account alone may change, the one place this program binds a socket it
/// will later remove. Where it does not, nothing there could be told from what somebody else put there.
bool inOwnDirectory(String path) {
  final cut = path.lastIndexOf('/');
  return cut > 0 && isOwnDirectory(path.substring(0, cut));
}
