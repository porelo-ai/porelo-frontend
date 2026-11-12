import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: it shows that it is reading {'which backups of checkout are recorded'}
///
/// One widget says it everywhere: the bar and, under it, the sentence of what is read.
Future<void> itShowsThatItIsReading(WidgetTester tester, String words) async {
  expect(find.byKey(const Key('reading')), findsOneWidget);
  expect(find.descendant(of: find.byKey(const Key('reading')), matching: find.textContaining(words)), findsOneWidget);
}
