import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/makers.dart';

/// The trailer check on the gate's review: a push an agent made in the wrong way, or one whose
/// trailer the machine does not report, must never be shown as checked and passed.
void main() {
  // The harm: a push is forwarded on a check that was never made.
  test('a trailer the machine does not report cannot be checked, and never passes', () {
    final check = TrailerCheck.of(null);

    expect(check.passed, isFalse);
    expect(check.state, TrailerState.unknown);
  });

  // The harm: a commit that names a co-author passes as one only assisted.
  test('a Co-Authored-By beside the one Assisted-by is wrong', () {
    final check = TrailerCheck.of(const <String>[
      'Assisted-by: Claude Code, claude-opus-5-5',
      'Co-Authored-By: Claude <noreply@anthropic.com>',
    ]);

    expect(check.passed, isFalse);
    expect(check.state, TrailerState.wrong);
  });

  // The harm: git reads a trailer's key without regard to case, so a lower-case one slips past.
  test('a co-author line in another case is still a co-author line', () {
    final check = TrailerCheck.of(const <String>[
      'Assisted-by: Claude Code, claude-opus-5-5',
      'co-authored-by: Claude <noreply@anthropic.com>',
    ]);

    expect(check.state, TrailerState.wrong);
  });

  // The harm: two agents named, or none, passes as the one asked for.
  test('two Assisted-by lines, or none, are wrong', () {
    expect(
      TrailerCheck.of(const <String>['Assisted-by: Claude Code, claude-opus-5-5', 'Assisted-by: Codex']).state,
      TrailerState.wrong,
    );
    expect(TrailerCheck.of(const <String>[]).state, TrailerState.wrong);
    expect(TrailerCheck.of(const <String>['Signed-off-by: A Person <a@example.org>']).state, TrailerState.wrong);
  });

  // The harm: every push is flagged, and a flag that is always up stops being read.
  test('exactly one Assisted-by and no Co-Authored-By passes', () {
    final check = TrailerCheck.of(const <String>[
      'Assisted-by: Claude Code, claude-opus-5-5',
      'Signed-off-by: A Person <a@example.org>',
    ]);

    expect(check.passed, isTrue);
  });
}
