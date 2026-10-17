import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: porelo doctor passes now
Future<void> poreloDoctorPassesNow(WidgetTester tester) async {
  World.setup.doctorRefuses = null;
}
