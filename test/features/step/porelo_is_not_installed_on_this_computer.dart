import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: Porelo is not installed on this computer
Future<void> poreloIsNotInstalledOnThisComputer(WidgetTester tester) async {
  World.poreloIsInstalledHere = false;
}
