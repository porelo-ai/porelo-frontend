import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/choice_field.dart';

import '../support/new_person.dart';
import '../support/remote.dart';

/// Usage: the work starts on {'my-first'}, which is in default now
Future<void> theWorkStartsOnWhichIsInDefaultNow(WidgetTester tester, String name) async {
  if (!walkingAsANewPerson) return;
  final field = tester.widgetList<ChoiceField<Object?>>(find.byWidgetPredicate((each) => each is ChoiceField))
      .where((each) => each.id == 'start-repository')
      .single;
  expect(field.value, name);
  final listed = await onTheTestMachine(r'PATH="$HOME/.local/bin:$PATH"; porelo project default list 2>&1 || true');
  expect(listed, contains(name), reason: listed);
}
