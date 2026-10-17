import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/terminal_links.dart';

/// Usage: no link is offered any more
Future<void> noLinkIsOfferedAnyMore(WidgetTester tester) async {
  expect(find.byType(TerminalLinks), findsNothing);
}
