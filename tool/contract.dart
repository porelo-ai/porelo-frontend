// Prints what a running Porelo daemon says it is, and the contract it serves.
// ignore_for_file: avoid_print - this is a command-line tool; printing is its output.
//
// Usage: dart tool/contract.dart [socket] [seconds to wait for the answers, 30 by default]
//
// Defaults to the local daemon. Pass a forwarded socket to ask a remote one:
//   ssh -L /tmp/porelod-remote.sock:/run/user/1001/porelo/porelod.sock user@host -N
//   dart tool/contract.dart /tmp/porelod-remote.sock
//
// Deliberately dependency-free and unabstracted: it is also the smallest complete example of
// how to speak to the backend.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

const String interfaceName = 'org.fuin.porelo.Tasks1';

/// GetInfo and GetInterfaceDescription, one reply each.
const int _calls = 2;

Future<void> main(List<String> args) async {
  final path = args.isNotEmpty
      ? args[0]
      : '${Platform.environment['XDG_RUNTIME_DIR'] ?? '/run/user/${_uid()}'}'
            '/porelo/porelod.sock';
  final within = Duration(seconds: args.length > 1 ? int.parse(args[1]) : 30);

  if (!await FileSystemEntity.isLink(path) && !File(path).existsSync()) {
    stderr.writeln('No socket at $path - is porelod running?');
    exitCode = 1;
    return;
  }

  final socket = await Socket.connect(InternetAddress(path, type: InternetAddressType.unix), 0);
  final replies = <Map<String, dynamic>>[];
  final buffer = BytesBuilder();
  final answered = Completer<void>();
  socket.listen(
    (chunk) {
      for (final byte in chunk) {
        if (byte == 0) {
          replies.add(jsonDecode(utf8.decode(buffer.takeBytes())) as Map<String, dynamic>);
          if (replies.length == _calls && !answered.isCompleted) answered.complete();
        } else {
          buffer.addByte(byte);
        }
      }
    },
    onDone: () {
      if (!answered.isCompleted) answered.complete();
    },
    onError: (Object _) {
      if (!answered.isCompleted) answered.complete();
    },
  );

  void call(String method, [Map<String, dynamic> parameters = const {}]) {
    socket.add(utf8.encode(jsonEncode({'method': method, 'parameters': parameters})));
    socket.add([0]);
  }

  call('org.varlink.service.GetInfo');
  call('org.varlink.service.GetInterfaceDescription', {'interface': interfaceName});
  await socket.flush();
  // Until both answers are in, never a fixed time: over an ssh forward they can take seconds.
  await answered.future.timeout(within, onTimeout: () {});
  socket.destroy();
  if (replies.length < _calls) {
    stderr.writeln(
      '$path answered ${replies.length} of $_calls calls within '
      '${within.inSeconds} seconds',
    );
    exitCode = 1;
  }

  for (final reply in replies) {
    if (reply['error'] != null) {
      stderr.writeln('${reply['error']}  ${jsonEncode(reply['parameters'])}');
      exitCode = 1;
      continue;
    }
    final parameters = reply['parameters'] as Map<String, dynamic>? ?? const {};
    if (parameters['product'] != null) {
      print(
        '${parameters['product']} ${parameters['version']} '
        '(${parameters['vendor']})',
      );
      print('interfaces: ${(parameters['interfaces'] as List<dynamic>).join(', ')}');
      print('');
    }
    if (parameters['description'] != null) {
      print(parameters['description']);
    }
  }
}

int _uid() => int.tryParse(Process.runSync('id', ['-u']).stdout.toString().trim()) ?? 1000;
