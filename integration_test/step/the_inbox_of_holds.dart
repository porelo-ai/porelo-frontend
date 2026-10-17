import 'package:flutter_test/flutter_test.dart';

import '../support/remote.dart';

/// Usage: the inbox of {'porelo-e2e-talk-e2e-talk'} holds {'not before the tests pass'}
Future<void> theInboxOfHolds(WidgetTester tester, String task, String words) async {
  expect(await inboxOf(task, words), contains(words), reason: 'nothing in the inbox of $task says it');
}

/// What in [task]'s inbox on the test machine says [words], as the machine wrote it. Measured on
/// Porelo 238: a refusal's note waits in the filter's feedback until the next pass moves it into the
/// inbox, so the task's messages are moved along once first, as the scenario's setup does.
Future<String> inboxOf(String task, String words) => onTheTestMachine('''
set -u
PATH="\$HOME/.local/bin:\$PATH"
porelo talk pass "$task" >/dev/null 2>&1 || true
inbox="\${XDG_STATE_HOME:-\$HOME/.local/state}/porelo/mail/$task/box/inbox"
for _ in \$(seq 30); do
  found=\$(grep -rlF -- '$words' "\$inbox" 2>/dev/null | head -1)
  if [ -n "\$found" ]; then cat "\$found"; exit 0; fi
  sleep 1
done
''');
