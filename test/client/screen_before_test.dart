// Linux only: it stands the mock daemon on a unix socket, and on GitHub's Windows runner a test
// through it hung where no timeout could end it.
@Tags(<String>['linux'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/mock/mock_daemon.dart';

import '../support/session_recording.dart';

/// A terminal session's earlier output, as the client asks the daemon for it over a real socket.
void main() {
  late MockDaemon daemon;

  setUp(() async {
    daemon = MockDaemon();
    await daemon.start();
  });

  tearDown(() => daemon.stop());

  Future<PoreloClient> connect() => PoreloClient.connect(Backend(socketPath: daemon.socketPath, label: 'mock'));

  /// Serves a recording the way the daemon does: positions it handed out are the only ones it takes.
  SessionRecording serve(List<String> lines, {List<Map<String, dynamic>>? asked}) {
    final recording = SessionRecording(lines);
    daemon.method('Screen', (parameters) {
      asked?.add(parameters);
      final (shown, end) = recording.screen(parameters['last'] as int);
      return <String, dynamic>{'lines': shown, 'live': true, 'end': end, 'of': recording.of};
    });
    daemon.method('ScreenBefore', (parameters) {
      asked?.add(parameters);
      if (parameters['of'] is! String) {
        throw const MockRefusal('org.fuin.porelo.Tasks1.InvalidParameter', {'parameter': 'of'});
      }
      if (parameters['of'] != recording.of) throw const MockRefusal('org.fuin.porelo.Tasks1.NoSuchLog');
      try {
        final page = recording.before(parameters['before'] as int, parameters['lines'] as int);
        return <String, dynamic>{'lines': page.lines, 'offset': page.offset, 'atStart': page.atStart};
      } on BadPosition {
        throw MockRefusal('org.fuin.porelo.Tasks1.InvalidParameter', <String, dynamic>{'parameter': 'before'});
      }
    });
    return recording;
  }

  // Harm: a session the daemon keeps no recording of reads as one whose end is position 0, and its earlier output is
  // asked for and shown as if it were empty rather than not kept.
  test('a Screen without an end has none, and a Screen with one keeps it', () async {
    daemon.method(
      'Screen',
      (_) => <String, dynamic>{
        'lines': <String>['a'],
        'live': true,
        'of': '',
      },
    );
    expect((await (await connect()).screen('t', last: 20)).end, isNull);

    daemon.method(
      'Screen',
      (_) => <String, dynamic>{
        'lines': <String>['a'],
        'live': true,
        'of': 'recording',
        'end': 4096,
      },
    );
    expect((await (await connect()).screen('t', last: 20)).end, 4096);
  });

  // Harm: a missing recording name makes every later scroll-back unusable.
  test('Screen requires its recording name even when no recording is kept', () async {
    for (final invalid in <Object?>[null, 12]) {
      for (final end in <int?>[null, 20]) {
        daemon.method(
          'Screen',
          (_) => <String, dynamic>{'lines': <String>[], 'live': true, 'end': ?end, 'of': ?invalid},
        );
        await expectLater((await connect()).screen('t', last: 5), throwsA(isA<FormatException>()));
      }
    }
  });

  // Harm: pages asked with a position nobody gave (InvalidParameter), or the walk stopped before the session's start,
  // so older lines are never reached or lines are shown twice.
  test('pages are asked with the position the last reply gave, oldest page last, until atStart', () async {
    final lines = <String>[for (var i = 0; i < 25; i++) 'line $i'];
    final asked = <Map<String, dynamic>>[];
    serve(lines, asked: asked);
    final client = await connect();

    final screen = await client.screen('t', last: 5);
    expect(screen.lines, lines.sublist(20));
    final pages = <List<String>>[];
    var before = screen.end!;
    ScreenPage page;
    do {
      page = await client.screenBefore('t', of: screen.of, before: before, lines: 10);
      pages.insert(0, page.lines);
      before = page.offset;
    } while (!page.atStart);

    expect(pages.expand((page) => page).toList(), lines, reason: 'the whole session, each line once, in order');
    expect(page.atStart, isTrue);
    expect(asked.where((call) => call.containsKey('before')).map((call) => call['of']), everyElement(screen.of));
    expect(asked.where((call) => call.containsKey('before')).map((call) => call['lines']).toSet(), <int>{10});
  });

  // Harm: a position the daemon never gave is sent, and its refusal is shown as the session's start or as an empty page.
  test('a refused position is the daemon’s own refusal, never an empty page', () async {
    final recording = serve(<String>['a', 'b', 'c']);
    final client = await connect();
    await expectLater(
      client.screenBefore('t', of: recording.of, before: 3, lines: 10),
      throwsA(isA<VarlinkException>().having((error) => error.simpleName, 'refusal', 'InvalidParameter')),
    );
  });

  // Harm: a call the daemon declares and does not serve is turned into a quiet "feature missing", and shown as the start
  // of the session or as nothing said.
  test('a call answered with MethodNotImplemented is the daemon’s own refusal', () async {
    daemon.fails('ScreenBefore', 'org.varlink.service.MethodNotImplemented');
    await expectLater(
      (await connect()).screenBefore('t', of: 'recording', before: 3, lines: 10),
      throwsA(isA<VarlinkException>().having((error) => error.simpleName, 'refusal', 'MethodNotImplemented')),
    );
  });

  // Harm: a reply that lacks atStart or the offset is taken as the end of the session (a missing flag read as true)
  // or as a position 0 asked again for ever.
  test('a page missing its position, its end or its lines is refused, never read as the start', () async {
    const whole = <String, dynamic>{
      'lines': <String>['a'],
      'offset': 7,
      'atStart': false,
    };
    daemon.method('ScreenBefore', (_) => <String, dynamic>{...whole, 'offset': 7.5});
    await expectLater(
      (await connect()).screenBefore('t', of: 'recording', before: 3, lines: 10),
      throwsA(isA<FormatException>()),
      reason: 'an offset that is no whole number',
    );
    for (final missing in whole.keys) {
      daemon.method('ScreenBefore', (_) => <String, dynamic>{...whole}..remove(missing));
      await expectLater(
        (await connect()).screenBefore('t', of: 'recording', before: 3, lines: 10),
        throwsA(isA<FormatException>()),
        reason: 'a reply without $missing',
      );
    }
  });

  // Harm: an end that is no whole number reads as a recording that is not kept, or hides that the terminal ended.
  test('an end that is no whole number is kept apart from an absent one and does not hide live', () async {
    daemon.method(
      'Screen',
      (_) => <String, dynamic>{'lines': <String>[], 'live': false, 'of': 'recording', 'end': 'soon'},
    );
    final screen = await (await connect()).screen('t', last: 20);
    expect(screen.endMalformed, isTrue);
    expect(screen.end, isNull);
    expect(screen.live, isFalse);

    daemon.method('Screen', (_) => <String, dynamic>{'lines': <String>[], 'live': true, 'of': ''});
    expect((await (await connect()).screen('t', last: 20)).endMalformed, isFalse);
  });

  // Harm: a connection left open after each call, so a terminal scrolled for an hour holds hundreds of sockets.
  test('a call leaves no connection open', () async {
    serve(<String>['a', 'b']);
    final client = await connect();
    final held = daemon.openConnections;
    final screen = await client.screen('t', last: 5);
    await client.screenBefore('t', of: screen.of, before: screen.end!, lines: 10);
    await client.screenBefore('t', of: 'recording', before: 99, lines: 10).then((_) {}, onError: (Object _) {});
    expect(daemon.openConnections, held);
  });
}
