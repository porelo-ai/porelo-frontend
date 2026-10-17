import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

/// What a project says about itself, held to the contract rather than to a screen.
///
/// `behind` is **meaningless unless `behindReason` is `MEASURED`** — the IDL says so — and a
/// daemon reporting a failure may well leave the previous number in the field. Everything here is
/// about the difference between a number and a measurement.
void main() {
  Project projectWith(Map<String, dynamic> fields) => Project.from(<String, dynamic>{
        'name': 'checkout',
        'securityClass': 'guarded',
        'file': '/srv/checkout/project.yml',
        'mirror': '',
        'pending': 0,
        'tasks': 0,
        'running': 0,
        ...fields,
      });

  test('a count is only a measurement when the reason says it was measured', () {
    // The one that would be invisible: a stale 7 beside a failure, drawn as though somebody had
    // counted it this morning.
    expect(
      projectWith(<String, dynamic>{'behind': 7, 'behindReason': 'FAILED'}).hasFallenBehind,
      isFalse,
    );
    expect(
      projectWith(<String, dynamic>{'behind': 7, 'behindReason': 'NEVER_CHECKED'})
          .hasFallenBehind,
      isFalse,
    );
    expect(
      projectWith(<String, dynamic>{'behind': 7, 'behindReason': 'OFFLINE'}).hasFallenBehind,
      isFalse,
    );
    expect(
      projectWith(<String, dynamic>{'behind': 7, 'behindReason': 'MEASURED'}).hasFallenBehind,
      isTrue,
    );
  });

  test('measured and zero is up to date, and nothing else is', () {
    expect(
      projectWith(<String, dynamic>{'behind': 0, 'behindReason': 'MEASURED'}).behindWords,
      startsWith('Up to date'),
    );
    for (final reason in <String>['NEVER_CHECKED', 'NO_UPSTREAM', 'OFFLINE', 'FAILED']) {
      expect(
        projectWith(<String, dynamic>{'behind': 0, 'behindReason': reason}).behindWords,
        isNot(startsWith('Up to date')),
        reason: '$reason reports zero and means something else entirely',
      );
    }
  });

  test('a measurement carries its age, because a number without one reads as current', () {
    final measured = projectWith(<String, dynamic>{
      'behind': 3,
      'behindReason': 'MEASURED',
      'behindMeasured':
          DateTime.now().toUtc().subtract(const Duration(minutes: 20)).toIso8601String(),
    });

    expect(measured.behindWords, '3 behind, as of 20 minutes ago');
  });

  test('a measurement with no age says the number and claims nothing about when', () {
    final measured =
        projectWith(<String, dynamic>{'behind': 3, 'behindReason': 'MEASURED'});

    expect(measured.behindWords, '3 behind');
  });

  test('a reason added after this build shipped renders rather than throwing', () {
    final later = projectWith(<String, dynamic>{'behindReason': 'RATE_LIMITED'});

    expect(later.behindWords, 'rate limited');
    expect(later.hasFallenBehind, isFalse);
  });

  test('nothing said about it is its own sentence, not a blank', () {
    expect(projectWith(const <String, dynamic>{}).behindWords,
        'Nothing said how far behind it is');
  });

  test('a failure says what failed when the daemon said what it was', () {
    expect(
      projectWith(<String, dynamic>{
        'behindReason': 'FAILED',
        'behindDetail': 'the upstream refused the connection',
      }).behindWords,
      'The last check did not work: the upstream refused the connection',
    );
  });

  // Measured on Porelo 221: a project with a `matrix:` peer answers its conversation this way.
  test("a project's conversation is read whole, and a project without one has none", () {
    final talking = projectWith(<String, dynamic>{
      'messages': <String, dynamic>{
        'transport': 'matrix',
        'conversation': '!abc:localhost',
        'reaches': <String>['127.0.0.1:8008'],
        'ready': true,
        'detail': '',
        'loopbackOnly': true,
      },
    }).messages!;

    expect(talking.transport, 'matrix');
    expect(talking.conversation, '!abc:localhost');
    expect(talking.reaches, <String>['127.0.0.1:8008']);
    expect(talking.ready, isTrue);
    expect(talking.loopbackOnly, isTrue);
    expect(projectWith(const <String, dynamic>{}).messages, isNull);
  });
}
