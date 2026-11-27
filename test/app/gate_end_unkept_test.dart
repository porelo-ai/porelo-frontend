import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/gate.dart';

import '../features/support/world.dart';

/// A forward or a drop whose push end the machine could not keep says the machine's sentence beside its result.
void main() {
  final project = Project.from(const <String, dynamic>{'name': 'checkout', 'file': '/srv/checkout/project.yml'});

  /// A gate looking at the one push `fix`, its review read, and the backend that answers for it.
  Future<(FakeBackend, Gate)> lookingAtAPush({String? endUnkept}) async {
    final backend = FakeBackend(<Task>[])
      ..endUnkept = endUnkept
      ..theGate = GateState.from(const <String, dynamic>{
        'mirror': '/srv/checkout/.porelo/mirror',
        'mode': 'gatekeeping',
        'seededFrom': '',
        'pending': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'fix',
            'commit': '9a3c1f2e4b5d6a7c8e9f0a1b2c3d4e5f6a7b8c9d',
            'subject': 'Round to the nearest penny',
            'waiting': '4 minutes',
            'at': '2026-01-02T03:00:00Z',
          },
        ],
      });
    final gate = Gate();
    await gate.lookAt(backend, project);
    await gate.look(backend, gate.waiting.single);
    return (backend, gate);
  }

  // Harm: the person who forwarded never learns that the task's record of where its push ended is missing.
  test('a forward says the sentence after its result, and is still said as forwarded', () async {
    final (backend, gate) = await lookingAtAPush(endUnkept: 'The record of task fix could not be written.');

    final answer = await gate.approve(backend, 'fix-rounding');

    expect(answer.forwarded, isTrue);
    expect(
      answer.said,
      "Round to the nearest penny was forwarded to fix-rounding. The push's end could not be kept: The record of "
      'task fix could not be written.',
    );
    expect(backend.approvals.single.name, 'fix', reason: 'nothing is asked again or undone');
  });

  // Harm: the person who dropped never learns that the task's record of where its push ended is missing.
  test('a drop says the sentence after its result, and is still said as dropped', () async {
    final (backend, gate) = await lookingAtAPush(endUnkept: 'The record of task fix could not be written.');

    final said = await gate.reject(backend);

    expect(said, startsWith('Round to the nearest penny was dropped. The work is still in the mirror.'));
    expect(said, endsWith(" The push's end could not be kept: The record of task fix could not be written."));
    expect(backend.rejections, <String>['fix']);
  });

  // Harm: a warning shown where the end was kept, which teaches a person to read past it.
  test('a forward and a drop without the sentence, or with a blank one, say their result alone', () async {
    for (final none in <String?>[null, '', '   ']) {
      var (backend, gate) = await lookingAtAPush(endUnkept: none);
      expect(
        (await gate.approve(backend, 'fix-rounding')).said,
        'Round to the nearest penny was forwarded to fix-rounding.',
      );
      (backend, gate) = await lookingAtAPush(endUnkept: none);
      expect(
        await gate.reject(backend),
        'Round to the nearest penny was dropped. The work is still in the mirror. Its task was told.',
      );
    }
  });

  // Harm: a sentence the machine sent forges a second line or turns the result around in the message line.
  test('a line break and a direction mark in the sentence are written out, on one line', () async {
    final rlo = String.fromCharCode(0x202E);
    final (backend, gate) = await lookingAtAPush(endUnkept: 'first\nsecond ${rlo}txt.exe');

    final said = await gate.reject(backend);

    expect(said, isNot(contains('\n')));
    expect(said, isNot(contains(rlo)));
    expect(said, endsWith(r'could not be kept: first\nsecond \u{202e}txt.exe'));
  });

  // Harm: a long sentence fills the message line and pushes the result out of sight.
  test('a sentence past 300 characters is cut', () async {
    final (backend, gate) = await lookingAtAPush(endUnkept: 'x' * 400);

    final said = await gate.reject(backend);

    expect(said, endsWith('could not be kept: ${'x' * 300} … cut'));
  });

  // Harm: a sentence of characters that are written out grows past the bound as it is written, and fills the line.
  test('a sentence is bounded as it is shown, its written-out characters counted, never cut inside one', () async {
    final bell = String.fromCharCode(7);
    final shownBell =
        '\\'
        'u{0007}';
    final (backend, gate) = await lookingAtAPush(endUnkept: bell * 300);

    final said = await gate.reject(backend);
    final sentence = said.substring(said.indexOf('could not be kept: ') + 'could not be kept: '.length);

    expect(sentence, '${shownBell * 37} … cut', reason: '37 whole escapes are 296 characters; the 38th does not fit');
    expect(sentence.length, lessThanOrEqualTo(300 + ' … cut'.length));
  });
}
