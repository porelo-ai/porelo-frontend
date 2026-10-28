import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/homeserver_publishing.dart';

void main() {
  late Directory scratch;
  late File conf;
  late File hosts;
  late List<List<String>> ran;
  late ProcessResult Function(List<String> arguments) answer;

  setUp(() {
    scratch = Directory.systemTemp.createTempSync('homeserver-publishing-');
    conf = File('${scratch.path}/porelo/matrix/homeserver.conf');
    hosts = File('${scratch.path}/hosts')..writeAsStringSync('127.0.0.1 localhost\n');
    ran = [];
    answer = (arguments) => ProcessResult(
      0,
      0,
      '{"published": "10.73.0.2:8008", "name": "matrix.porelo.internal", "ca_file": "/home/me/ca.crt"}\n',
      '',
    );
  });
  tearDown(() => scratch.deleteSync(recursive: true));

  HomeserverPublishing publishing() => HomeserverPublishing(
    configuration: '${scratch.path}/porelo',
    hostsFile: hosts.path,
    run: (executable, arguments) async {
      expect(executable, HomeserverPublishing.transport, reason: 'the transport by its path, as packaged');
      ran.add(arguments);
      return answer(arguments);
    },
  );

  // Harm: a host's tasks that never reach the room on the laptop, or the homeserver published on an address of
  // another host, or left published once the host is gone.
  test('published on the peer address with the homeserver\'s own port and the name, only where it is set up', () async {
    expect(await publishing().publish('10.73.0.2/32'), isNull, reason: 'no homeserver set up here: nothing runs');
    expect(ran, isEmpty);

    conf
      ..createSync(recursive: true)
      ..writeAsStringSync('PORELO_MATRIX_SERVER_NAME=localhost\nPORELO_MATRIX_PORT=8008\n');
    final outcome = (await publishing().publish('10.73.0.2/32'))!;
    expect(ran.single, ['publish', '--address', '10.73.0.2:8008', '--name', 'matrix.porelo.internal']);
    expect(outcome.published, isTrue);
    expect(outcome.words, contains('https://matrix.porelo.internal:8008'));
  });

  test('a refusal is said in the transport\'s words, and an unreadable port or address runs nothing', () async {
    conf
      ..createSync(recursive: true)
      ..writeAsStringSync('PORELO_MATRIX_PORT=8008\n');
    answer = (_) => ProcessResult(0, 78, '', 'publish: no project has set up this homeserver yet\n');
    final refused = (await publishing().publish('10.73.0.2/32'))!;
    expect(refused.published, isFalse);
    expect(refused.words, contains('no project has set up this homeserver yet'));

    ran.clear();
    for (final (port, address) in [
      ('80', '10.73.0.2/32'),
      ('70000', '10.73.0.2/32'),
      ('eight', '10.73.0.2/32'),
      ('8008', 'not-an-address'),
      ('8008', '0.0.0.0/0'),
      ('8008', '127.0.0.1/32'),
      ('8008', '255.255.255.255/32'),
      ('8008', '10.73.0.1/32'),
      ('8008', '010.073.000.002/32'),
      ('8008', '192.168.1.2/32'),
      ('8008', '999.999.999.999'),
      ('8008', '...'),
    ]) {
      conf.writeAsStringSync('PORELO_MATRIX_PORT=$port\n');
      final outcome = (await publishing().publish(address))!;
      expect(outcome.published, isFalse, reason: '$port $address');
    }
    expect(ran, isEmpty, reason: 'nothing a shell or the transport could take wrongly is passed on');

    conf.writeAsStringSync('PORELO_MATRIX_PORT="8008"\n');
    answer = (_) => throw const ProcessException('porelo-message-transport-matrix', [], 'No such file or directory');
    final missing = (await publishing().publish('10.73.0.2/32'))!;
    expect(ran.single, [
      'publish',
      '--address',
      '10.73.0.2:8008',
      '--name',
      'matrix.porelo.internal',
    ], reason: 'a quoted value, as an environment file may hold it, is the same value');
    expect(missing.published, isFalse);
    expect(missing.words, contains('No such file or directory'), reason: 'a transport not installed is said');
  });

  test('closed at the give-back only where it is published for that host', () async {
    conf
      ..createSync(recursive: true)
      ..writeAsStringSync('PORELO_MATRIX_PORT=8008\nPORELO_MATRIX_PUBLISH=10.73.0.5:8008\n');
    answer = (_) => ProcessResult(0, 0, '{"published": null}\n', '');
    expect(await publishing().unpublish('10.73.0.2/32'), isNull, reason: 'another host\'s address is left alone');
    expect(ran, isEmpty);

    conf.writeAsStringSync('PORELO_MATRIX_PORT=8008\nPORELO_MATRIX_PUBLISH=10.73.0.20:8008\n');
    expect(
      await publishing().unpublish('10.73.0.2/32'),
      isNull,
      reason: 'a longer address of another host is not this one',
    );
    expect(ran, isEmpty);

    conf.writeAsStringSync("PORELO_MATRIX_PORT=8008\nPORELO_MATRIX_PUBLISH='10.73.0.2:8008'\n");
    final closed = (await publishing().unpublish('10.73.0.2/32'))!;
    expect(ran.single, ['publish', '--off']);
    expect(closed.published, isFalse);
    expect(closed.words, isNot(contains('could not')));
  });

  test('the laptop\'s own line is asked for only where no line gives the name to loopback', () {
    expect(publishing().laptopLineMissing, isTrue);
    hosts.writeAsStringSync('127.0.0.1 localhost\n10.0.0.1 matrix.porelo.internal\n');
    expect(publishing().laptopLineMissing, isTrue, reason: 'another address is not this laptop');
    hosts.writeAsStringSync('127.0.0.1 localhost\n127.0.0.1\tmatrix.porelo.internal # by hand\n');
    expect(publishing().laptopLineMissing, isFalse);
    hosts.writeAsStringSync('# 127.0.0.1 matrix.porelo.internal\n');
    expect(publishing().laptopLineMissing, isTrue, reason: 'a comment names nothing');
    expect(HomeserverPublishing.laptopLine, '127.0.0.1 matrix.porelo.internal # porelo-matrix');
  });
}
