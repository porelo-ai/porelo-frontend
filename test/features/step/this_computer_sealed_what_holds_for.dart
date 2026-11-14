import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: this computer sealed what {'an-agent'} holds for {'other-provider'}
Future<void> thisComputerSealedWhatHoldsFor(WidgetTester tester, String agent, String provider) async {
  // By agent and provider alone: a vault name beside them is refused, and alone it would carry an entry instead.
  expect(
    World.here.sealsAsked.map((seal) => (name: seal.name, agent: seal.agent, provider: seal.provider)),
    <({String? name, String? agent, String? provider})>[(name: null, agent: agent, provider: provider)],
  );
}
