import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';

/// Usage: I write {'stop, the schema changed'} to the agent of {'porelo-e2e-talk_e2e-talk'} from the interface
Future<void> iWriteToTheAgentOfFromTheInterface(WidgetTester tester, String words, String task) async {
  // The message dialog is closed first, and the task is acted on from its tile's menu, as a person
  // would: its machine, then its project.
  if (find.byKey(const Key('held-message-close')).evaluate().isNotEmpty) {
    await tester.tap(find.byKey(const Key('held-message-close')));
    await pumpFor(tester);
  }
  await chooseFromTheMenuOfTheTile(tester, task, 'Write to its agent');
  await tester.enterText(find.byKey(const Key('words')), words);
  await tester.pump();
  await tester.tap(find.byKey(const Key('words-confirm')));
  // Said with the name the task is shown by, which is the machine's own short name where it gives one (`e2e-talk`),
  // and the whole name only where it gives none; whether it reached the inbox is the next step's, on the machine.
  await pumpUntil(
    tester,
    () => find
        .textContaining(RegExp(r'Written into the inbox of \S+\. Its agent reads it there\.'))
        .evaluate()
        .isNotEmpty,
    timeout: const Duration(seconds: 30),
    what: 'the machine to write it',
  );
}
