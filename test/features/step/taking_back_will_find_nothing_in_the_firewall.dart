import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: taking back will find nothing in the firewall
///
/// The name was granted and the container never reached it, so nothing was in the set. A real
/// state, and not a failure.
Future<void> takingBackWillFindNothingInTheFirewall(WidgetTester tester) async {
  World.backend.nextNarrowing = const Narrowed(
    outcome: WidenOutcome.previewed,
    closes: <String>['files.example.test'],
    addresses: 0,
    persisted: false,
    detail: '',
  );
}
