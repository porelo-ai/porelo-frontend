import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: nothing has been backed up here
Future<void> nothingHasBeenBackedUpHere(WidgetTester tester) async {
  World.backend.theBackupsItHas = const <Backup>[];
}
