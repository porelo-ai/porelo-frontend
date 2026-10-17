import 'package:flutter_test/flutter_test.dart';

/// Usage: its name is still shown as {'porelo-checkout-shell'}
Future<void> itsNameIsStillShownAs(WidgetTester tester, String name) async {
  // It is what every other call takes and what somebody types on the machine. A caption that hid
  // it would make the interface and the command line disagree about what a thing is called.
  expect(find.textContaining(name), findsWidgets);
}
