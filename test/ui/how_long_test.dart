import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/ui/how_long.dart';

Task at(String since) => Task.from(<String, dynamic>{'name': 'a-task', 'since': since});

void main() {
  final now = DateTime.parse('2026-09-07T15:00:00Z');

  test('answers the question "idle for how long"', () {
    expect(howLong(at('2026-09-07T14:20:00Z'), now: now), '40 minutes');
    expect(howLong(at('2026-09-07T14:59:30Z'), now: now), 'less than a minute');
    expect(howLong(at('2026-09-07T14:00:00Z'), now: now), '1 hour');
    expect(howLong(at('2026-09-07T13:00:00Z'), now: now), '2 hours');
    expect(howLong(at('2026-09-05T15:00:00Z'), now: now), '2 days');
  });

  test('a runtime that cannot say gets no answer invented for it', () {
    // A container created and never started answers a zero time, which renders as a date
    // centuries out. The year 1 in an interface is worse than a blank.
    expect(howLong(at(''), now: now), isNull);
    expect(howLong(at('not a date'), now: now), isNull);
  });

  test('a clock that disagrees does not produce a negative age', () {
    // Two machines, two clocks: a forwarded socket makes that ordinary rather than exotic.
    expect(howLong(at('2026-09-07T15:30:00Z'), now: now), isNull);
  });
}
