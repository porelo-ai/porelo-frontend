import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:porelo_frontend/src/app/desk.dart';
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
  OneInstance._(this._listening, this.socketPath);

  final ServerSocket? _listening;

  /// Where the running interface listens.
  final String socketPath;

  /// Whether this process is the one in charge.
  bool get inCharge => _listening != null;

  /// Takes charge, or asks whoever already has it to come forward.
  ///
  /// [comeForward] runs when another launch asks for the window. [at] is injectable so this can be
  /// tested without fighting over the real one.
  static Future<OneInstance> take({required void Function() comeForward, String? at, bool? overLoopback}) async {
    if (overLoopback ?? desk.isWindows) {
      return _takeOverLoopback(comeForward, at ?? desk.join(<String>[desk.state, 'frontend.port']));
    }
    final path = at ?? _besideTheRuntime();
    try {
      final listening = await ServerSocket.bind(InternetAddress(path, type: InternetAddressType.unix), 0);
      listening.listen((from) {
        comeForward();
        from.destroy();
      });
      return OneInstance._(listening, path);
    } on SocketException {
      // Either somebody is there, or a previous run died without tidying up. Asking settles it:
      // a socket nobody answers is a leftover, and deleting it is the only way back.
      if (await _somebodyAnswered(path)) return OneInstance._(null, path);
      try {
        File(path).deleteSync();
      } on FileSystemException {
        return OneInstance._(null, path);
      }
      return take(comeForward: comeForward, at: path);
    }
  }

  /// Stops listening and tidies up, so the next launch is not met by a leftover.
  Future<void> release() async {
    if (_listening == null) return;
    await _listening.close();
    try {
      File(socketPath).deleteSync();
    } on FileSystemException {
      // Something else removed it. Nothing to do and nothing worth saying.
    }
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

  static Future<bool> _somebodyAnswered(String path) async {
    try {
      final socket = await Socket.connect(
        InternetAddress(path, type: InternetAddressType.unix),
        0,
        timeout: const Duration(seconds: 1),
      );
      socket.destroy();
      return true;
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
