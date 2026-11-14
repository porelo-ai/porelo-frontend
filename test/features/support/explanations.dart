import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/page_explanation.dart';

import 'world.dart';

/// Closes every page explanation standing open, as a person does once it is read: a page's words stand open the first
/// time it is shown, above what a scenario then reads or presses.
Future<void> closeTheExplanations(WidgetTester tester) async {
  for (final element in find.byType(PageExplanation).evaluate().toList()) {
    final explanation = element.widget as PageExplanation;
    if (!explanation.settings.explanationOpen(explanation.id)) continue;
    final fold = find.byKey(ValueKey<String>('explanation-fold ${explanation.id}'));
    if (fold.evaluate().isEmpty) continue;
    await tester.ensureVisible(fold.first);
    await tester.tap(fold.first);
    await World.settle(tester);
  }
}
