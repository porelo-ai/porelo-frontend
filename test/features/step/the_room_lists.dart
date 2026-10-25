import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the room lists {'anna,bea'}
Future<void> theRoomLists(WidgetTester tester, String people) async {
  final expected = people.split(',');
  final rows = find.byWidgetPredicate(
    (widget) => widget.key is ValueKey<String> && (widget.key! as ValueKey<String>).value.startsWith('member '),
  );
  expect(
    rows.evaluate().map((element) => (element.widget.key! as ValueKey<String>).value.substring(7)),
    unorderedEquals(expected),
    reason: 'only the authoritative member list may be displayed',
  );
  expect(
    World.backend.membersOf['checkout']!.map((member) => member.person),
    unorderedEquals(expected),
    reason: 'the account must actually leave the backend room',
  );
}
