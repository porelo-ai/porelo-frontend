// Linux only: it stands the mock daemon on a unix socket.
@Tags(<String>['linux'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/mock/mock_daemon.dart';

/// The call for what lies before a log's first line, held to the contract over a real socket.
///
/// The stand-in keeps one log of lines `line 1` to `line 25`, counts a position in bytes (each line takes its UTF-8
/// length and one for its end), and answers what it is asked from that, refusing a position it never handed out.
void main() {
  late MockDaemon daemon;
  late List<Map<String, dynamic>> asked;

  final log = <String>[for (var at = 1; at <= 25; at++) 'line $at'];
  // Where each line starts, in bytes: a client that counts lines gets it wrong.
  final starts = <int>[];
  var size = 0;
  for (final line in log) {
    starts.add(size);
    size += line.length + 1;
  }
  final handed = <int>{};

  setUp(() async {
    daemon = MockDaemon();
    await daemon.start();
    addTearDown(daemon.stop);
    asked = <Map<String, dynamic>>[];
    handed.clear();
    daemon.pushes('Tail', (parameters) async* {
      final last = parameters['last'] as int?;
      final first = last == null || last >= log.length ? 0 : log.length - last;
      handed.add(starts[first]);
      yield <String, dynamic>{'lines': log.sublist(first), 'offset': starts[first]};
    });
    daemon.method('LogBefore', (parameters) {
      asked.add(parameters);
      final before = parameters['before'];
      final lines = parameters['lines'];
      // As the daemon does: only a position it handed out, and a page of 1 to 1000 lines.
      if (before is! int || !handed.contains(before) || lines is! int || lines < 1 || lines > 1000) {
        throw MockRefusal('org.fuin.porelo.Tasks1.InvalidParameter', <String, dynamic>{'parameter': 'before'});
      }
      final end = starts.indexOf(before);
      final first = end > lines ? end - lines : 0;
      handed.add(starts[first]);
      return <String, dynamic>{'lines': log.sublist(first, end), 'offset': starts[first], 'atStart': first == 0};
    });
  });

  Future<PoreloClient> connect() => PoreloClient.connect(Backend(socketPath: daemon.socketPath, label: 'mock'));

  // Harm: Tail's offset is dropped on the way in, so no client can ever ask for what lies before what it was sent.
  test('a followed log carries the position of its first line', () async {
    final client = await connect();

    final first = await client.tailLog('t', 'task.log', last: 10).first;

    expect(first.lines.first, 'line 16');
    expect(first.offset, starts[15], reason: 'a byte position, not a line number');
  });

  // Harm: a Tail reply without the position of its first line is read as a log with nothing before it, hiding
  // the lines that lie earlier.
  test('a tail reply without a position is malformed, never a log without earlier lines', () async {
    daemon.pushes('Tail', (_) async* {
      yield <String, dynamic>{
        'lines': <String>['a'],
      };
    });
    final client = await connect();

    await expectLater(client.tailLog('t', 'task.log').first, throwsA(isA<FormatException>()));
  });

  // Harm: pages overlap or leave a gap, or the log's start is never reported and the view asks for ever.
  test('pages walk back from the position Tail gave, each from the last offset, to the start', () async {
    final client = await connect();
    final tail = await client.tailLog('t', 'task.log', last: 10).first;

    final second = await client.logBefore('t', 'task.log', before: tail.offset, lines: 10);
    expect(second.lines, log.sublist(5, 15));
    expect(second.offset, starts[5]);
    expect(second.atStart, isFalse);

    final third = await client.logBefore('t', 'task.log', before: second.offset, lines: 10);
    expect(third.lines, log.sublist(0, 5));
    expect(third.offset, 0);
    expect(third.atStart, isTrue);

    expect(asked.map((each) => each['before']), <int>[starts[15], starts[5]]);
    expect(asked.first.keys.toSet(), <String>{'task', 'log', 'before', 'lines'}, reason: 'formatted only when asked');
  });

  // Harm: a formatted log's earlier lines come raw, so scrolling up changes what the lines look like.
  test('formatted is asked for only where the log is read formatted', () async {
    final client = await connect();
    final tail = await client.tailLog('t', 'task.log', last: 10).first;

    await client.logBefore('t', 'task.log', before: tail.offset, lines: 5, formatted: true);

    expect(asked.single['formatted'], isTrue);
  });

  // Harm: a call the daemon does not serve is mapped to a feature switch, and the window shows nothing of it.
  test('MethodNotImplemented is a refusal like any other, raised as it came', () async {
    daemon.fails('LogBefore', 'org.varlink.service.MethodNotImplemented');
    final client = await connect();

    await expectLater(
      client.logBefore('t', 'task.log', before: 10, lines: 5),
      throwsA(isA<VarlinkException>().having((refusal) => refusal.simpleName, 'simpleName', 'MethodNotImplemented')),
    );
  });

  // Harm: a log replaced by a new run is flattened into a generic failure, so the view cannot start again from Tail.
  test('NoSuchLog keeps its name, so the caller can read from Tail again', () async {
    daemon.fails('LogBefore', 'org.fuin.porelo.Tasks1.NoSuchLog', <String, dynamic>{'task': 't', 'log': 'task.log'});
    final client = await connect();

    await expectLater(
      client.logBefore('t', 'task.log', before: 10, lines: 5),
      throwsA(isA<VarlinkException>().having((refusal) => refusal.simpleName, 'simpleName', 'NoSuchLog')),
    );
  });

  // Harm: a refused position is shown as the log's start, or swallowed.
  test('a position the daemon never gave is its refusal, raised as it came', () async {
    final client = await connect();

    await expectLater(
      // A line number, as a client that counts lines would send, is no position the daemon handed out.
      client.logBefore('t', 'task.log', before: 15, lines: 5),
      throwsA(isA<VarlinkException>().having((refusal) => refusal.simpleName, 'simpleName', 'InvalidParameter')),
    );
  });

  // Harm: a reply without atStart is read as "not the start" or "the start", and the view stops or loops on a guess.
  test('a reply missing a part is an error, never the log\'s start', () async {
    daemon.method(
      'LogBefore',
      (_) => <String, dynamic>{
        'lines': <String>['x'],
        'offset': 3,
      },
    );
    final client = await connect();

    await expectLater(client.logBefore('t', 'task.log', before: 10, lines: 5), throwsA(isA<FormatException>()));
  });

  // Harm: a page size the daemon refuses is sent anyway and comes back as a refusal the person cannot act on.
  test('a page of no lines or more than a thousand is not asked for', () async {
    final client = await connect();

    expect(() => client.logBefore('t', 'task.log', before: 10, lines: 0), throwsRangeError);
    expect(() => client.logBefore('t', 'task.log', before: 10, lines: 1001), throwsRangeError);
    expect(asked, isEmpty);
  });
}
