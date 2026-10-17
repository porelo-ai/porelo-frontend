import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

/// What a log says about itself, held to the contract rather than to a screen.
///
/// **A name is data, never a category, and a description is the daemon's to give.** Only that end
/// knows which files a task has and what each one is for; a table here would say nothing about a
/// file added tomorrow while looking exactly as authoritative about it.
void main() {
  Log logWith(Map<String, dynamic> fields) => Log.from(<String, dynamic>{
        'name': 'events.jsonl',
        'bytes': 9212,
        'at': '2026-09-07T14:12:00Z',
        ...fields,
      });

  test('a name that speaks for itself carries no description, and none is not blank', () {
    expect(logWith(<String, dynamic>{'name': 'agent.log'}).what, isNull);
  });

  test('a description the daemon gave is kept as written', () {
    expect(
      logWith(<String, dynamic>{'what': 'What the firewall blocked.'}).what,
      'What the firewall blocked.',
    );
  });

  test('an empty description is nothing said, never something said blankly', () {
    // **A blank that looks like an answer is worse than no answer.** An empty line under a name
    // reads as a description that failed rather than as one that was never given, and a daemon
    // that has nothing to say about a file may say it either way.
    expect(logWith(<String, dynamic>{'what': ''}).what, isNull);
    expect(logWith(<String, dynamic>{'what': '   '}).what, isNull);
  });

  test('a description of the wrong type is absent rather than rendered', () {
    // Unknown shapes render as nothing and never throw: a reply may grow a field this end has to
    // survive without recognizing.
    expect(logWith(<String, dynamic>{'what': 42}).what, isNull);
  });

  test('a size of zero is a log, not a missing one', () {
    // `reader.err` is empty in the normal case, and empty is the answer that means the record of
    // blocked connections is complete.
    expect(logWith(<String, dynamic>{'name': 'reader.err', 'bytes': 0}).bytes, 0);
  });
}
