// Linux only: it stands a daemon on a unix socket, which dart:io cannot open on Windows.
@Tags(<String>['linux'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `tool/contract.dart`, run as a person runs it, against a daemon that is slow or half there.
///
/// Over an ssh forward a reply can take seconds, and a tool that gave up after a fixed time printed
/// nothing and exited 0 — which reads as a daemon serving an empty contract.
void main() {
  late Directory scratch;
  late String socketPath;
  late ServerSocket server;

  setUp(() async {
    scratch = Directory.systemTemp.createTempSync('porelo-contract-test');
    addTearDown(() => scratch.deleteSync(recursive: true));
    socketPath = '${scratch.path}/d.sock';
    server = await ServerSocket.bind(InternetAddress(socketPath, type: InternetAddressType.unix), 0);
    addTearDown(server.close);
  });

  /// Answers each call after [after], or only the first [answering] of them.
  void serve({required Duration after, int answering = 2}) {
    server.listen((client) {
      var calls = 0;
      client.listen(
        (chunk) async {
          final ends = chunk.where((byte) => byte == 0).length;
          for (var i = 0; i < ends; i++) {
            final call = ++calls;
            if (call > answering) continue;
            await Future<void>.delayed(after);
            final parameters = call == 1
                ? <String, dynamic>{
                    'vendor': 'fuin.org',
                    'product': 'porelod',
                    'version': '9.9',
                    'interfaces': <String>['org.fuin.porelo.Tasks1'],
                  }
                : <String, dynamic>{'description': 'interface org.fuin.porelo.Tasks1'};
            client.add(<int>[
              ...utf8.encode(jsonEncode({'parameters': parameters})),
              0,
            ]);
          }
        },
        onDone: client.destroy,
        onError: (Object _) {},
      );
    });
  }

  Future<ProcessResult> contract([List<String> more = const []]) =>
      Process.run('dart', <String>['tool/contract.dart', socketPath, ...more]);

  test('answers that take longer than a moment are still printed', () async {
    serve(after: const Duration(milliseconds: 700));

    final ran = await contract();

    expect(ran.exitCode, 0, reason: '${ran.stderr}');
    expect(ran.stdout, contains('porelod 9.9 (fuin.org)'));
    expect(ran.stdout, contains('interface org.fuin.porelo.Tasks1'));
  });

  test('a daemon that answers only one call fails the run and says so', () async {
    serve(after: Duration.zero, answering: 1);

    final ran = await contract(<String>['1']);

    expect(ran.exitCode, 1);
    expect(ran.stderr, contains('answered 1 of 2 calls within 1 seconds'));
  });
}
