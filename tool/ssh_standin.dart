// Build for a walk with: dart compile exe tool/ssh_standin.dart -o <walk>/bin/ssh
import 'dart:async';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  final parsed = _parse(arguments);
  if (parsed == null) {
    stderr.writeln('The ssh stand-in does not support this form: ${arguments.join(' ')}');
    exitCode = 255;
    return;
  }
  if (parsed.config) {
    stdout.writeln('identityfile ${parsed.identity ?? '~/.ssh/id_ed25519'}');
    return;
  }
  final target = Platform.environment['PORELO_WALK_HOST_SOCKET'];
  if (target == null || target.isEmpty) {
    stderr.writeln('Set PORELO_WALK_HOST_SOCKET to the host mock daemon socket.');
    exitCode = 255;
    return;
  }
  final local = parsed.local!;
  if (FileSystemEntity.typeSync(local, followLinks: false) != FileSystemEntityType.notFound) {
    stderr.writeln('The ssh stand-in will not replace an existing endpoint: $local');
    exitCode = 255;
    return;
  }
  ServerSocket? server;
  FileStat? made;
  final sockets = <Socket>{};
  final stopped = Completer<void>();
  final signals = <StreamSubscription<ProcessSignal>>[];
  void stop() {
    if (!stopped.isCompleted) stopped.complete();
  }

  try {
    for (final signal in [ProcessSignal.sigterm, ProcessSignal.sigint]) {
      signals.add(signal.watch().listen((_) => stop()));
    }
    server = await ServerSocket.bind(InternetAddress(local, type: InternetAddressType.unix), 0);
    made = FileStat.statSync(local);
    server.listen(
      (incoming) async {
        sockets.add(incoming);
        try {
          final outgoing = await Socket.connect(InternetAddress(target, type: InternetAddressType.unix), 0);
          sockets.add(outgoing);
          if (stopped.isCompleted) {
            outgoing.destroy();
            incoming.destroy();
            return;
          }
          try {
            await Future.wait([incoming.cast<List<int>>().pipe(outgoing), outgoing.cast<List<int>>().pipe(incoming)]);
          } finally {
            outgoing.destroy();
            sockets.remove(outgoing);
          }
        } on IOException {
          if (!stopped.isCompleted) {
            stderr.writeln('The ssh stand-in could not carry the connection to the host mock daemon.');
            exitCode = 255;
            stop();
          }
        } finally {
          incoming.destroy();
          sockets.remove(incoming);
        }
      },
      onError: (Object error) {
        stderr.writeln('The ssh stand-in could not accept a connection.');
        exitCode = 255;
        stop();
      },
    );
    stderr.writeln('Forwarding the walk socket at $local.');
    await stopped.future;
  } on IOException {
    stderr.writeln('The ssh stand-in could not bind the walk socket at $local.');
    exitCode = 255;
  } finally {
    await server?.close();
    for (final socket in sockets.toList()) {
      socket.destroy();
    }
    for (final signal in signals) {
      await signal.cancel();
    }
    // A failed bind or a replaced endpoint must never remove somebody else's file.
    if (made != null &&
        FileSystemEntity.typeSync(local, followLinks: false) == FileSystemEntityType.unixDomainSock &&
        FileStat.statSync(local).modified == made.modified) {
      File(local).deleteSync();
    }
  }
}

({bool config, String? local, String? identity})? _parse(List<String> arguments) {
  var config = false;
  var forward = false;
  String? mapping;
  String? identity;
  String? host;
  for (var i = 0; i < arguments.length; i++) {
    final argument = arguments[i];
    switch (argument) {
      case '-G':
        config = true;
      case '-N':
        forward = true;
      case '-L' || '-o' || '-i':
        if (++i == arguments.length) return null;
        final value = arguments[i];
        if (value.isEmpty || value.startsWith('-')) return null;
        if (argument == '-L') {
          if (mapping != null) return null;
          mapping = value;
        }
        if (argument == '-i') identity = value;
      default:
        if (argument.startsWith('-') || host != null || argument.isEmpty) return null;
        host = argument;
    }
  }
  if (host == null) return null;
  if (config && !forward && mapping == null) return (config: true, local: null, identity: identity);
  if (!config && forward && mapping != null) {
    final paths = mapping.split(':');
    if (paths.length == 2 && paths.every((path) => path.startsWith('/') && path.length > 1)) {
      return (config: false, local: paths.first, identity: identity);
    }
  }
  return null;
}
