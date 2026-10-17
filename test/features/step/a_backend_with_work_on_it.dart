import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: a backend with work on it
Future<void> aBackendWithWorkOnIt(WidgetTester tester) => World.startBackend(World.work);
