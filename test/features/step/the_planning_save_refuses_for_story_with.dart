import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the planning save refuses {name} for story {id} with {detail}
Future<void> thePlanningSaveRefusesForStoryWith(WidgetTester tester, String name, String id, String detail) async {
  World.backend.planningRefusedStory = null;
  World.backend.planningMoveFailure = VarlinkException('org.fuin.porelo.Tasks1.$name', {'story': id, 'detail': detail});
}
