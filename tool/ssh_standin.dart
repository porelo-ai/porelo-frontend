// Build for a walk with: dart compile exe tool/ssh_standin.dart -o <walk>/bin/ssh
import 'dart:async';
import 'dart:io';

import 'package:porelo_host/porelo_host.dart' show inTheLoginShell, hostStopCommand;

Future<void> main(List<String> arguments) async {
  final parsed = _parse(arguments);
  if (parsed == null) {
    stderr.writeln('The ssh stand-in does not support this form.');
    exitCode = 255;
    return;
  }
  if (parsed.config) {
    stdout.writeln('identityfile ${parsed.identity ?? '~/.ssh/id_ed25519'}');
    return;
  }
  if (parsed.terminal != null) {
    exitCode = await _terminal(parsed.terminal!);
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

({bool config, String? local, String? identity, List<String>? terminal})? _parse(List<String> arguments) {
  var config = false;
  var forward = false;
  var terminal = false;
  String? command;
  String? mapping;
  String? identity;
  String? host;
  for (var i = 0; i < arguments.length; i++) {
    final argument = arguments[i];
    if (command != null) return null;
    switch (argument) {
      case '-G':
        config = true;
      case '-N':
        forward = true;
      case '-t':
        if (terminal) return null;
        terminal = true;
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
        if (argument.startsWith('-') || argument.isEmpty) return null;
        if (host == null) {
          host = argument;
        } else if (terminal && command == null) {
          command = argument;
        } else {
          return null;
        }
    }
  }
  if (host == null) return null;
  if (terminal) {
    if (config ||
        forward ||
        mapping != null ||
        command == null ||
        !RegExp(r'^[A-Za-z_][A-Za-z0-9_-]*@[A-Za-z0-9][A-Za-z0-9.:-]*$').hasMatch(host)) {
      return null;
    }
    final needs = _terminalNeeds(command);
    return needs == null ? null : (config: false, local: null, identity: identity, terminal: needs);
  }
  if (config && !forward && mapping == null) return (config: true, local: null, identity: identity, terminal: null);
  if (!config && forward && mapping != null) {
    final paths = mapping.split(':');
    if (paths.length == 2 && paths.every((path) => path.startsWith('/') && path.length > 1)) {
      return (config: false, local: paths.first, identity: identity, terminal: null);
    }
  }
  return null;
}

List<String>? _terminalNeeds(String command) {
  final address =
      RegExp(r'[A-Za-z0-9][A-Za-z0-9._+-]*@[A-Za-z0-9]+(?:[.-][A-Za-z0-9]+)*\.[A-Za-z]{2,}')
          .firstMatch(command)
          ?.group(0) ??
      '';
  for (final needs in const <List<String>>[
    ['drive'],
    ['vault-new'],
    ['vault'],
    ['drive', 'vault-new'],
    ['drive', 'vault'],
  ]) {
    if (needs.contains('drive') && address.isEmpty) continue;
    if (command == inTheLoginShell(hostStopCommand(needs, email: address))) return needs;
  }
  return null;
}

Future<int> _terminal(List<String> needs) async {
  Future<bool> prompt(String words, {bool secret = true}) async {
    final echo = stdin.hasTerminal ? stdin.echoMode : null;
    try {
      if (echo != null) stdin.echoMode = !secret;
      stdout.write(words);
      await stdout.flush();
      // The answer is dropped without being written, including on a piped walk test.
      return stdin.readLineSync() != null;
    } finally {
      if (echo != null) stdin.echoMode = echo;
      stdout.writeln();
    }
  }

  if (needs.contains('drive')) {
    stdout.writeln('The one-time code will show as you type it.');
    if (!await prompt('Password: ') || !await prompt('Enter your one-time password: ', secret: false)) return 1;
    stdout.writeln(
      needs.length > 1
          ? 'Logged in to Tresorit; the vault comes next.'
          : 'Logged in to Tresorit; close this terminal to continue host setup.',
    );
  }
  if (needs.contains('vault-new')) {
    if (!await prompt('New vault passphrase: ') || !await prompt('New vault passphrase again: ')) return 1;
    stdout.writeln('Vault initialized; close this terminal to continue host setup.');
  } else if (needs.contains('vault')) {
    if (!await prompt('Vault passphrase: ')) return 1;
    stdout.writeln('Vault unlocked; close this terminal to continue host setup.');
  }
  return 0;
}
