import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/makers.dart';

/// The trailer check on the gate's review: a push an agent made in the wrong way, or one whose
/// trailer the machine does not report, must never be shown as checked and passed.
/// The check of [trailers] in a message that holds them as its trailer block, as git writes one.
TrailerCheck _checkOf(List<String> trailers) =>
    TrailerCheck.of(trailers, message: 'Round to the nearest penny\n\n${trailers.join('\n')}\n');

void main() {
  // The harm: a push is forwarded on a check that was never made.
  test('a trailer the machine does not report cannot be checked, and never passes', () {
    final check = TrailerCheck.of(null, message: null);

    expect(check.passed, isFalse);
    expect(check.state, TrailerState.unknown);
  });

  // The harm: a commit that names a co-author passes as one only assisted.
  test('a Co-Authored-By beside the one Assisted-by is wrong', () {
    final check = _checkOf(const <String>[
      'Assisted-by: Claude Code, claude-opus-5-5',
      'Co-Authored-By: Claude <noreply@anthropic.com>',
    ]);

    expect(check.passed, isFalse);
    expect(check.state, TrailerState.wrong);
  });

  // The harm: git reads a trailer's key without regard to case, so a lower-case one slips past.
  test('a co-author line in another case is still a co-author line', () {
    final check = _checkOf(const <String>[
      'Assisted-by: Claude Code, claude-opus-5-5',
      'co-authored-by: Claude <noreply@anthropic.com>',
    ]);

    expect(check.state, TrailerState.wrong);
  });

  // The harm: two agents named, or none, passes as the one asked for.
  test('two Assisted-by lines, or none, are wrong', () {
    expect(
      _checkOf(const <String>['Assisted-by: Claude Code, claude-opus-5-5', 'Assisted-by: Codex']).state,
      TrailerState.wrong,
    );
    expect(_checkOf(const <String>[]).state, TrailerState.wrong);
    expect(_checkOf(const <String>['Signed-off-by: A Person <a@example.org>']).state, TrailerState.wrong);
  });

  // The harm: every push is flagged, and a flag that is always up stops being read.
  test('exactly one Assisted-by and no Co-Authored-By passes', () {
    final check = _checkOf(const <String>[
      'Assisted-by: Claude Code, claude-opus-5-5',
      'Signed-off-by: A Person <a@example.org>',
    ]);

    expect(check.passed, isTrue);
  });

  // The harm: a co-author named in the body, outside git's trailer block, is in no trailer line, so
  // a check of the trailer lines alone passes a commit that names one.
  test('a Co-Authored-By in the message outside the trailer block is wrong', () {
    final check = TrailerCheck.of(
      const <String>['Assisted-by: Claude Code, claude-opus-5-5'],
      message:
          'Round to the nearest penny\n\nCo-Authored-By: Claude <noreply@anthropic.com>\nand a line after it\n\n'
          'Assisted-by: Claude Code, claude-opus-5-5\n',
    );

    expect(check.passed, isFalse);
    expect(check.state, TrailerState.wrong);
  });

  test('a message with the one Assisted-by and no co-author passes', () {
    final check = TrailerCheck.of(const <String>[
      'Assisted-by: Claude Code, claude-opus-5-5',
    ], message: 'Round to the nearest penny\n\nAssisted-by: Claude Code, claude-opus-5-5\n');

    expect(check.state, TrailerState.passed);
  });

  // The harm: where the machine gives the trailer lines but not the whole message, a co-author
  // outside the trailer block cannot be ruled out, so the check is not made rather than passed.
  test('trailer lines without the whole message cannot be checked, and never pass', () {
    final check = TrailerCheck.of(const <String>['Assisted-by: Claude Code, claude-opus-5-5'], message: null);

    expect(check.passed, isFalse);
    expect(check.state, TrailerState.unknown);
  });
}
