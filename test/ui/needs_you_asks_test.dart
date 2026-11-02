import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../features/support/world.dart';
import '../support/expand_list_rows.dart';

void main() {
  final message = HeldMessage.from({
    'task': 'alpha',
    'message': 'held.json',
    'standing': 'held',
    'direction': 'out',
    'peer': 'reviewer',
    'role': 'ROLE_USER',
    'reason': 'the peer is held',
  });

  // Harm: a message waits for a person while the page they open says nothing needs them.
  testWidgets('opening Needs you asks the machine, with no word from its stream', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester);
    World.backend.heldForAPerson.add(message);
    await World.settle(tester);
    await tester.tap(find.byKey(const ValueKey('rail attention')));
    await World.settle(tester);
    await expandListRows(tester);
    await World.settle(tester);
    expect(find.byKey(const ValueKey('read-message alpha/held.json')), findsOneWidget);
  });
}
