import 'package:flutter_test/flutter_test.dart';

import 'support/idl.dart';

/// The reading of a served contract that the live tests hold this client to.
///
/// The harm: a type cut at the second `)` ran on into the next declaration, and a field was found
/// inside another name, so a field the daemon dropped still passed as declared.
void main() {
  const contract = '''
type HeldMessage (
    what: string,
    task: string
)

type Next (
    direction: string,
    at: string
)

method ReadHeld(
    id: string
) -> (
    outcome: string,
    text: string
)
''';

  test('a type ends where it closes, not at the next one', () {
    final held = declarationIn(contract, 'type HeldMessage (')!;
    expect(declares(held, 'task'), isTrue);
    expect(declares(held, 'direction'), isFalse, reason: 'direction is the next type\'s');
  });

  test('a field is found as a name of its own, never inside another', () {
    expect(declares(declarationIn(contract, 'type HeldMessage (')!, 'at'), isFalse, reason: '"at" is inside "what"');
  });

  test("a method's declaration holds its parameters and its reply, and stops there", () {
    final read = declarationIn(contract, 'method ReadHeld(')!;
    expect(declares(read, 'id'), isTrue);
    expect(declares(read, 'text'), isTrue);
  });

  test('what is not there is null', () {
    expect(declarationIn(contract, 'type Missing ('), isNull);
  });
}
