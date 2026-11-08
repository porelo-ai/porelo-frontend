import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/facts_page.dart';
import 'package:porelo_frontend/src/ui/host_readiness_view.dart';

/// Harm: a successful automatic check takes over the machine a person came to read.
Future<void> theMachineFactsStayOpenWithoutAReadinessPage(WidgetTester tester) async {
  expect(find.byType(HostReadinessView), findsNothing);
  expect(find.byType(FactsPage), findsOneWidget);
  expect(find.descendant(of: find.byType(FactsPage), matching: find.text('the build machine')), findsWidgets);
}
