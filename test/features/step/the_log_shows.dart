import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/log_view.dart';

/// Everything the log view is currently showing, as one string.
///
/// Read off the spans rather than off `Text.data`: a line carrying color is drawn as several
/// spans, and a finder that only looked at `data` would find nothing on exactly the lines this
/// requirement is about.
String logText(WidgetTester tester) => tester
    .widgetList<SelectableText>(
      find.descendant(
        of: find.byType(LogView),
        matching: find.byType(SelectableText),
      ),
    )
    .map((shown) => shown.data ?? shown.textSpan?.toPlainText() ?? '')
    .join('\n');

/// Usage: the log shows {'building the image'}
Future<void> theLogShows(WidgetTester tester, String words) async {
  expect(logText(tester), contains(words));
}
