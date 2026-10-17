import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: nothing answers on that machine
///
/// What a forward to a socket nobody serves does: it comes up, and the first write is reset.
Future<void> nothingAnswersOnThatMachine(WidgetTester tester) async {
  World.backend.absent = const VarlinkDisconnected('Connection reset by peer');
}
