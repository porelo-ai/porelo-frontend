import 'package:flutter_test/flutter_test.dart';

import '../support/idea_walk.dart';
import '../step/the_test_machine_has_porelos_stub_agent.dart';
import '../step/work_on_the_test_machine_was_started_with_a_key_its_provider_refuses.dart';

/// Usage: a task fails on a key its provider refuses
Future<void> aTaskFailsOnAKeyItsProviderRefuses(WidgetTester tester) =>
    walked(tester, '13 a task fails on a key its provider refuses', () async {
      // Porelo's stub, unattended, with a fake key its provider refuses: its own project, its key in the run's vault,
      // both removed again when the scenario ends.
      await theTestMachineHasPorelosStubAgent(tester);
      await workOnTheTestMachineWasStartedWithAKeyItsProviderRefuses(tester, 'anthropic');
    });
