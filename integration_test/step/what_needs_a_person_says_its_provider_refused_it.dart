import 'package:flutter_test/flutter_test.dart';

import '../../test/support/expand_list_rows.dart';
import '../support/e2e.dart';
import 'work_on_the_test_machine_was_started_with_a_key_its_provider_refuses.dart';

/// Usage: what needs a person says its provider refused it
///
/// The stub sees the provider's answer and not its status, so the words are checked, not a code.
Future<void> whatNeedsAPersonSaysItsProviderRefusedIt(WidgetTester tester) async {
  await toThePlace(tester, 'attention');
  final said = find.textContaining('The provider refused it');
  await pumpUntil(
    tester,
    () async {
      await expandListRows(tester);
      return said.evaluate().isNotEmpty;
    },
    timeout: const Duration(minutes: 4),
    what: 'the ended agent of $refusedTask under what needs a person',
  );
  expect(find.textContaining(refusedTask), findsWidgets);
}
