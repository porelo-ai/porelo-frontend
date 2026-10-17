import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/choice_field.dart';

/// Usage: the way of taking part chosen is {'A shell, driven by hand'}
Future<void> theWayOfTakingPartChosenIs(WidgetTester tester, String label) async {
  final field = tester.widgetList<ChoiceField<Object?>>(find.byWidgetPredicate((each) => each is ChoiceField))
      .where((each) => each.id == 'start-mode')
      .single;
  expect(field.choices.where((each) => each.value == field.value).single.label, label);
}
