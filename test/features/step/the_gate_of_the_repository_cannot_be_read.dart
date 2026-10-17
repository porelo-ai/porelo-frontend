import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the gate of the repository {'payments-api'} cannot be read
Future<void> theGateOfTheRepositoryCannotBeRead(WidgetTester tester, String repository) async {
  World.backend.refuseTheGateIn[repository] = VarlinkException('org.fuin.porelo.Tasks1.Failed', const <String, dynamic>{
    'message': 'the mirror is missing',
  });
}
