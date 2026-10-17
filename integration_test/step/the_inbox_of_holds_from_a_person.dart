import 'package:flutter_test/flutter_test.dart';

import 'the_inbox_of_holds.dart';

/// Usage: the inbox of {'porelo-e2e-talk-e2e-talk'} holds {'stop, the schema changed'} from a person
Future<void> theInboxOfHoldsFromAPerson(WidgetTester tester, String task, String words) async {
  final found = await inboxOf(task, words);
  expect(found, contains(words), reason: 'nothing in the inbox of $task says it');
  expect(found, contains('person'), reason: 'what is there is not marked as a person\'s: $found');
}
