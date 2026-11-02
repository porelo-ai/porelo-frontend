import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/machines.dart';

import '../support/e2e.dart';
import '../support/project_file.dart';
import '../support/remote.dart';

/// The project the refused work was for.
const refusedProject = 'e2e-auth';

/// Usage: work on the test machine was started without a grant of {'e2e-needed'}
Future<void> workOnTheTestMachineWasStartedWithoutAGrantOf(WidgetTester tester, String entry) async {
  const destination = '\${XDG_DATA_HOME:-\$HOME/.local/share}/porelo/destinations/e2e-api.yaml';
  removeAfterwards(
    remove: '${removingTheWork('porelo-$refusedProject-auth', refusedProject)}rm -f "$destination"',
    leftOver: '$listingTheWork; [ -e "$destination" ] && echo LEFT:e2e-api; true',
    names: <String>['porelo-$refusedProject-auth', 'LEFT:e2e-api'],
  );
  // A destination for the entry, then a shell given it: it starts with a warning, since nobody has
  // granted it, and the machine raises the question. A shell needs no agent credential, and runs where
  // no agent is installed at all.
  final client = await PoreloClient.connect(Backend(socketPath: Machine.endpointFor(E2e.name), label: E2e.name));
  await client.writeDestination(name: 'e2e-api', upstream: 'https://api.example.com/v1', authPrefix: 'Bearer ');
  await onTheTestMachine('''
PATH="\$HOME/.local/bin:\$PATH"
name=$refusedProject; repo="\$HOME/\$name"
porelo project remove \$name >/dev/null 2>&1 || true
${removingTheProjectFiles(refusedProject)}
git init -q --bare -b main "\$repo-backend.git"
${writingTheProjectFile(refusedProject, projectFile(refusedProject, backend: '\$repo-backend.git'))}
agent=\$(porelo agents | awk '\$1 == "NAME" {table = 1; next} table && NF {print \$1; exit}')
porelo task start -p \$name -r backend \${agent:+--agent "\$agent"} --attach shell \\
  --credential $entry=e2e-api --no-gate --detach auth >/dev/null
''');
}
