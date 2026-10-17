import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the store cannot be read
Future<void> theStoreCannotBeRead(WidgetTester tester) async {
  final was = World.backend.theProvidersItHas;
  World.backend.theProvidersItHas = Providers(providers: was.providers, readable: false);
}
