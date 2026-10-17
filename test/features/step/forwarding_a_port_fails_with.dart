import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/login_forward.dart';

import '../support/world.dart';

/// Usage: forwarding a port fails with {'Port 8765 is already in use on this computer'}
Future<void> forwardingAPortFailsWith(WidgetTester tester, String words) async {
  raiseLoginForward = (machine, port) async {
    World.forwards.add(port);
    throw ForwardRefused(words);
  };
}
