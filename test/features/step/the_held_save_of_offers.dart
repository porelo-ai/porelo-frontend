import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/held_saves.dart';

/// Usage: the held save of {'ST293'} offers {'Resend and Drop'}
///
/// `Resend and Drop`, or `Drop only`, each enabled.
Future<void> theHeldSaveOfOffers(WidgetTester tester, String story, String offered) async {
  final resend = find.byKey(Key('held-save-resend ${heldSaveId(story)}'));
  final drop = find.byKey(Key('held-save-drop ${heldSaveId(story)}'));
  expect(drop, findsOneWidget);
  expect(tester.widget<TextButton>(drop).onPressed, isNotNull);
  switch (offered) {
    case 'Resend and Drop':
      expect(resend, findsOneWidget);
      expect(tester.widget<TextButton>(resend).onPressed, isNotNull);
    case 'Drop only':
      expect(resend, findsNothing);
    default:
      fail('no such offer: $offered');
  }
}
