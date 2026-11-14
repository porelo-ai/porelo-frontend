import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the carry says {'The host already holds an-agent and kept it'}
Future<void> theCarrySays(WidgetTester tester, String words) async {
  final said = find.byKey(const Key('carry-says'));
  expect(said, findsOneWidget);
  expect(tester.widget<Text>(said).data ?? '', contains(words));
}
