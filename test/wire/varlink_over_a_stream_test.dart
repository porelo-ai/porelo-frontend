import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/wire/varlink_connection.dart';
import 'package:porelo_frontend/src/wire/varlink_exception.dart';

/// Varlink spoken over any byte stream, not only over a socket file: the way a Porelo in WSL is
/// reached from Windows, through a relay's standard input and output.
void main() {
  late StreamController<List<int>> fromDaemon;
  late StreamController<List<int>> toDaemon;
  late List<int> sent;
  var destroyed = false;

  VarlinkConnection connection() =>
      VarlinkConnection.over(incoming: fromDaemon.stream, outgoing: toDaemon.sink, destroy: () => destroyed = true);

  void answer(Map<String, dynamic> reply) => fromDaemon.add(<int>[...utf8.encode(jsonEncode(reply)), 0]);

  setUp(() {
    fromDaemon = StreamController<List<int>>();
    toDaemon = StreamController<List<int>>();
    sent = <int>[];
    destroyed = false;
    toDaemon.stream.listen(sent.addAll);
  });

  test('a call goes out NUL-ended and its reply comes back, with no socket file anywhere', () async {
    final reply = connection().call('org.varlink.service.GetInfo');
    await pumpEventQueue();
    expect(utf8.decode(sent.sublist(0, sent.length - 1)), '{"method":"org.varlink.service.GetInfo","parameters":{}}');
    expect(sent.last, 0);

    answer(<String, dynamic>{
      'parameters': <String, dynamic>{'product': 'Porelo'},
    });

    expect(await reply, <String, dynamic>{'product': 'Porelo'});
  });

  test('a stream of replies arrives as it comes, and ends with the last one', () async {
    final replies = connection().callMore('org.fuin.porelo.Tasks1.Watch').toList();
    await pumpEventQueue();
    answer(<String, dynamic>{
      'parameters': <String, dynamic>{'n': 1},
      'continues': true,
    });
    answer(<String, dynamic>{
      'parameters': <String, dynamic>{'n': 2},
    });

    expect(await replies, <Map<String, dynamic>>[
      <String, dynamic>{'n': 1},
      <String, dynamic>{'n': 2},
    ]);
  });

  test('a stream that ends before the reply is a lost connection, never an empty answer', () async {
    final reply = connection().call('org.varlink.service.GetInfo');
    await pumpEventQueue();
    await fromDaemon.close();

    await expectLater(reply, throwsA(isA<VarlinkDisconnected>()));
  });

  test('bytes that are not a reply break the connection off, and the stream is ended', () async {
    final reply = connection().call('org.varlink.service.GetInfo');
    await pumpEventQueue();
    fromDaemon.add(<int>[...utf8.encode('not json'), 0]);

    await expectLater(reply, throwsA(isA<VarlinkDisconnected>()));
    expect(destroyed, isTrue);
  });

  test('closing it ends the stream rather than waiting for the far end', () async {
    await connection().close();
    expect(destroyed, isTrue);
  });
}
