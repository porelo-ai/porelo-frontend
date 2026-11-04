import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/task_certifying.dart';

/// A certificate lasts a week; work whose certificate ended has its commits refused, so a person
/// is told before, and can renew it from the window.
void main() {
  final now = DateTime.utc(2026, 11, 4, 20);
  Task task({bool certified = true, DateTime? until}) => Task.from(<String, dynamic>{
    'name': 'p-work',
    'task': 'work',
    'project': 'p',
    'certified': certified,
    'certifiedUntil': ?until?.toIso8601String(),
  });

  // Harm: an end nobody hears of stops the work's pushes with no warning.
  test('it says within a day of the end, and after it', () {
    expect(certificateEnding(task(until: now.add(const Duration(days: 2))), now: now), isNull);
    expect(certificateEnding(task(until: now.add(const Duration(hours: 5))), now: now), contains('ends in 5 hours'));
    expect(
      certificateEnding(task(until: now.add(const Duration(minutes: 9))), now: now),
      contains('ends in 9 minutes'),
    );
    expect(certificateEnding(task(until: now.subtract(const Duration(hours: 1))), now: now), contains('has ended'));
  });

  // Harm: a warning about a certificate nobody has, or a guess where the machine does not say.
  test('it says nothing for work not certified, or where the machine does not say', () {
    expect(certificateEnding(task(certified: false, until: now), now: now), isNull);
    expect(certificateEnding(task(), now: now), isNull);
  });

  test('a task reads its certificate, and an older daemon reads as saying nothing', () {
    final read = Task.from(<String, dynamic>{'certified': true, 'certifiedUntil': '2026-11-05T20:00:00Z'});
    expect(read.certified, isTrue);
    expect(read.certifiedUntil, DateTime.utc(2026, 11, 5, 20));
    final older = Task.from(<String, dynamic>{});
    expect(older.certified, isFalse);
    expect(older.certifiedUntil, isNull);
  });

  // Harm: the wrong task on the wrong host, or `--host` without the project it requires.
  test('renewal names the task by itself, here or on its host', () {
    expect(certifyAgainArguments(task()), <String>['task', 'certify', 'work']);
    expect(certifyAgainArguments(task(), host: 'alice@host', project: 'p'), <String>[
      'task',
      'certify',
      'work',
      '--host',
      'alice@host',
      '--project',
      'p',
    ]);
  });
}
