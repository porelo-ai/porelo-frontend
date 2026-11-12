import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/src/app/desk.dart';
import 'package:porelo_frontend/src/app/forward_records.dart';
import 'package:porelo_frontend/src/app/own_sockets.dart';
import 'package:porelo_frontend/src/app/tunnel.dart' show ConnectToSocket, SocketProbe, connectToSocket, probeSocket;
import 'package:porelo_frontend/src/client/environment.dart';

/// Keeps one interface in charge of a machine.
///
/// Two of these running is not merely untidy: each watches every configured machine, so every
/// clearance question is raised twice and answered by whichever window somebody happened to see.
/// A second launch therefore **joins** — it asks the one already running to come forward and then
/// leaves — rather than failing or competing.
///
/// A unix socket rather than a lock file, because a lock file cannot be talked to: the second
/// launch has something to say, and "come forward" is the whole of it.
///
/// **On Windows, a port on the loopback address**, named in a file beside the operations record:
/// `dart:io` has no unix socket there. The running interface greets whoever connects, so a port
/// that some other program took over after a crash is told from this interface's own.
class OneInstance {
  OneInstance._(this._listening, this.socketPath, {this.unsure}) : _held = null;

  OneInstance._held(this._listening, this.socketPath, HeldSocket this._held) : unsure = null;

  final ServerSocket? _listening;

  // The socket file this run listens through at [socketPath], held while it is in charge: only that file is removed.
  final HeldSocket? _held;

  /// Where the running interface listens.
  final String socketPath;

  /// Why it could not be told whether another interface is in charge, where it could not; null otherwise.
  final String? unsure;

  /// Whether this process is the one in charge.
  bool get inCharge => _listening != null;

  /// Takes charge, or asks whoever already has it to come forward.
  ///
  /// [comeForward] runs when another launch asks for the window. [at] is injectable so this can be
  /// tested without fighting over the real one.
  static Future<OneInstance> take({
    required void Function() comeForward,
    String? at,
    bool? overLoopback,
    @visibleForTesting ConnectToSocket connect = connectToSocket,
  }) async {
    if (overLoopback ?? desk.isWindows) {
      return _takeOverLoopback(comeForward, at ?? desk.join(<String>[desk.state, 'frontend.port']));
    }
    final path = at ?? _besideTheRuntime();
    // A socket at the shared name is only ever told apart from somebody else's where nobody else can put one.
    if (!inOwnDirectory(path)) {
      return OneInstance._(null, path, unsure: 'the folder of $path is not yours alone');
    }
    // Bound at a name of its own, then linked to the shared name: `link` takes a name only while it is free, so two
    // launches never both take charge, and closing the listener later removes only that private name, never whatever
    // is at the shared one by then.
    final private = '${path.substring(0, path.lastIndexOf('/'))}/.porelo-frontend-$pid-${_token()}.sock';
    final ServerSocket listening;
    try {
      listening = await ServerSocket.bind(InternetAddress(private, type: InternetAddressType.unix), 0);
    } on SocketException catch (failure) {
      return OneInstance._(null, path, unsure: 'a socket could not be made beside $path: ${failure.message}');
    }
    final held = HeldSocket.at(private);
    if (held == null) {
      await listening.close();
      return OneInstance._(null, path, unsure: 'the socket made beside $path could not be held');
    }
    var leftovers = 0;
    while (true) {
      final linked = linkSocketName(private, path);
      if (linked == 0) {
        removeSocketIfStill(private, held);
        listening.listen((from) {
          comeForward();
          from.destroy();
        });
        return OneInstance._held(listening, path, held);
      }
      // Not linked, so the private name is the only one: closing removes it.
      Future<OneInstance> giveUp({String? unsure}) async {
        held.release();
        await listening.close();
        return OneInstance._(null, path, unsure: unsure);
      }

      if (linked != 17) return giveUp(unsure: 'the name $path could not be taken (errno $linked)'); // EEXIST
      // Somebody is there, or a run that died left its socket. Asking settles it: one that answers is in charge.
      switch (await probeSocket(path, connect)) {
        case SocketProbe.answers:
          return giveUp();
        case SocketProbe.unknown:
          return giveUp(unsure: 'whether another window listens at $path could not be told');
        case SocketProbe.nobody:
          // A leftover nobody holds is removed, and only that; anything else at the name stays and is said.
          if (++leftovers > 3 || !await removeLeftover(path, connect: connect)) {
            if (FileSystemEntity.typeSync(path, followLinks: false) == FileSystemEntityType.notFound) continue;
            return giveUp(unsure: 'something that is no leftover of this window is at $path, and it was left alone');
          }
      }
    }
  }

  static String _token() {
    final random = Random.secure();
    return List<String>.generate(8, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  /// Stops listening and removes its socket, so the next launch is not met by a leftover: only while the shared name
  /// is still the socket this run listens through, never one put there since.
  Future<void> release() async {
    final listening = _listening;
    if (listening == null) return;
    final held = _held;
    if (held == null) {
      // Over the loopback address: the file that names the port.
      await listening.close();
      try {
        File(socketPath).deleteSync();
      } on FileSystemException {
        // Something else removed it. Nothing to do and nothing worth saying.
      }
      return;
    }
    removeSocketIfStill(socketPath, held);
    held.release();
    await listening.close();
  }

  /// What the running interface says to whoever connects on the loopback port.
  static const String _greeting = 'porelo-frontend\n';

  static Future<OneInstance> _takeOverLoopback(void Function() comeForward, String portFile) async {
    if (await _answeredOnLoopback(portFile)) return OneInstance._(null, portFile);
    final listening = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    listening.listen((from) {
      from.write(_greeting);
      unawaited(from.flush().whenComplete(from.destroy).catchError((Object _) {}));
      comeForward();
    });
    final file = File(portFile);
    await file.parent.create(recursive: true);
    await file.writeAsString('${listening.port}', flush: true);
    return OneInstance._(listening, portFile);
  }

  /// Whether this interface answers on the port [portFile] names. A missing file, a port nobody
  /// listens on, or one where something else answers, is a leftover.
  static Future<bool> _answeredOnLoopback(String portFile) async {
    final int? port;
    try {
      port = int.tryParse(File(portFile).readAsStringSync().trim());
    } on FileSystemException {
      return false;
    }
    if (port == null) return false;
    try {
      final socket = await Socket.connect(InternetAddress.loopbackIPv4, port, timeout: const Duration(seconds: 1));
      final said = await socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 1), onTimeout: () => '');
      socket.destroy();
      return said == _greeting;
    } on SocketException {
      return false;
    }
  }

  static String _besideTheRuntime() {
    final runtime =
        setIn('XDG_RUNTIME_DIR') ?? '/run/user/${Process.runSync('id', const <String>['-u']).stdout.toString().trim()}';
    return '$runtime/porelo-frontend.sock';
  }
}
