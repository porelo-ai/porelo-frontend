import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/ui/held_message_view.dart';

/// A held message's heading says whose it is (walk 8: "A question going out from a person" did not).
void main() {
  HeldMessage held(String role) => HeldMessage.from(<String, dynamic>{
    'task': 'porelo-test-project-foo',
    'standing': 'held',
    'message': 'm.json',
    'role': role,
    'peer': 'alice',
    'kind': 'question',
    'direction': 'out',
  });

  // Harm: treating a person’s message as an agent’s hides whose words are being sent.
  test('one the person wrote is said as theirs', () {
    expect(
      HeldMessageRow.headline(held('ROLE_USER')),
      'A question you wrote, going out through porelo-test-project-foo to alice',
    );
  });

  // Harm: attributing an agent’s message to the person misrepresents who authored it.
  test("one the task's agent wrote is said as the task's", () {
    expect(HeldMessageRow.headline(held('ROLE_AGENT')), 'A question going out from porelo-test-project-foo to alice');
  });
}
