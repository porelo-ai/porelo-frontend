import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: story work says the models of {'An Agent'} could not be listed
Future<void> storyWorkSaysTheModelsOfCouldNotBeListed(WidgetTester tester, String agent) async {
  // Under the model field, with the machine's reason and that the model is typed.
  final words = find.textContaining(RegExp('The models of $agent could not be listed on .+: .+\\. Type the model\\.'));
  expect(words, findsOneWidget);
  expect(tester.widget<Text>(words).data ?? '', contains('refuses to list models'));
}
