import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the provider {'a-provider'} says {'Stored as an-agent'}
Future<void> theProviderSays(WidgetTester tester, String provider, String words) async {
  // Said at the button that was pressed, in view, not somewhere below the providers.
  final said = find.byKey(Key('import-says $provider'));
  expect(said, findsOneWidget);
  expect((tester.widget<Text>(said).data ?? ''), contains(words));
  expect(said.hitTestable(), findsOneWidget, reason: 'the answer stands where the button was pressed');
}
