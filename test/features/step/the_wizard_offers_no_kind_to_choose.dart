import '../support/world.dart';

import 'package:flutter_test/flutter_test.dart';

/// Usage: the wizard offers no kind to choose
Future<void> theWizardOffersNoKindToChoose(WidgetTester tester) async {
  expect(find.text('Add a user to a machine'), findsOneWidget);
  expect(World.fieldOffering(tester, id: 'machine-new'), isNull);
  expect(World.fieldOffering(tester, id: 'machine-raise-it'), isNull);
}
