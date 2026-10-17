import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/templates.dart';

import '../support/world.dart';

/// Usage: the job {'nightly-tests'} is already named
Future<void> theJobIsAlreadyNamed(WidgetTester tester, String name) async {
  // Put in place rather than named through the dialog: what this scenario is about is starting
  // from one, and naming it again in every scenario would test the naming five times.
  await World.templates.keep(Template(
    name: name,
    project: 'checkout',
    agent: 'an-agent',
    mode: Mode.unattended,
    prompt: 'Run the nightly tests',
  ));
  await World.settle(tester);
}
