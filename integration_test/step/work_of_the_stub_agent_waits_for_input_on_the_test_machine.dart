import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/idea_walk.dart';
import '../support/project_file.dart';
import '../support/remote.dart';
import '../support/story_play.dart';

/// Usage: work of the stub agent waits for input on the test machine
///
/// The stub, attached rather than given a prompt, says each line it reads back and keeps the first in its session's
/// file. It needs a key for its provider to start, which it never uses attached: a fake one where the account has
/// none, removed again with the work.
Future<void> workOfTheStubAgentWaitsForInputOnTheTestMachine(WidgetTester tester) =>
    played(tester, '4 work of the stub agent waits for input on the test machine', () async {
      // The terminal on the machine and the work's container are reached in place, as a person at that machine does.
      if (E2e.host != 'localhost') fail('the story plays on the test machine itself; PORELO_E2E_HOST is ${E2e.host}');
      const project = Played.project, entry = 'anthropic';
      final container = containerOf(project, Played.task);
      final keyed = await onTheTestMachine(
        'PATH="\$HOME/.local/bin:\$PATH"; porelo vault list | grep -c "^$entry " || true',
      );
      final ownKey = keyed.trim() != '0';
      removeAfterwards(
        remove:
            '${removingTheWork(container, project)}'
            '${ownKey ? '' : 'porelo vault remove --without-revoking $entry >/dev/null 2>&1 || true'}',
        leftOver: '$listingTheWork${ownKey ? '' : '; porelo vault list 2>/dev/null | sed "s/^/ENTRY:/"'}',
        names: <String>[project, if (!ownKey) 'ENTRY:$entry '],
      );
      await onTheTestMachine('''
set -eu
PATH="\$HOME/.local/bin:\$PATH"
${ownKey ? '' : '''printf 'sk-ant-api03-%s' "\$(printf 'not-a-real-key-%.0s' 1 2 3 4 5 6)" | porelo vault put --type=api-key $entry >/dev/null || {
  porelo vault remove --without-revoking $entry >/dev/null 2>&1; exit 1; }'''}
name=$project; repo="\$HOME/\$name"
porelo project remove \$name >/dev/null 2>&1 || true
${removingTheProjectFiles(project)}
git init -q --bare -b main "\$repo-backend.git"
${writingTheProjectFile(project, projectFile(project, backend: '\$repo-backend.git'))}
porelo task start -p \$name -r backend --agent stub --no-input --detach ${Played.task} >/dev/null
''');
      final work = await theWork() ?? fail('porelo lists no work of $project after starting it');
      Played.container = theContainerOf(work);
    });
