import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/machines.dart';

import '../support/e2e.dart';
import '../support/remote.dart';

/// The project the refused work was for.
const refusedProject = 'e2e-auth';

/// Usage: work on the test machine was started without a grant of {'e2e-needed'}
Future<void> workOnTheTestMachineWasStartedWithoutAGrantOf(WidgetTester tester, String entry) async {
  // A destination for the entry, then a shell given it: it starts with a warning, since nobody has
  // granted it, and the machine raises the question. A shell needs no agent credential, and runs where
  // no agent is installed at all.
  final client = await PoreloClient.connect(Backend(socketPath: Machine.endpointFor(E2e.name), label: E2e.name));
  await client.writeDestination(name: 'e2e-api', upstream: 'https://api.example.com/v1', authPrefix: 'Bearer ');
  await onTheTestMachine('''
PATH="\$HOME/.local/bin:\$PATH"
name=$refusedProject; repo="\$HOME/\$name"
porelo project unfollow --force \$name >/dev/null 2>&1 || true
rm -rf "\$repo"; mkdir -p "\$repo"; cd "\$repo"; git init -q -b main
cat > project.yml <<'YAML'
project:
  name: "$refusedProject"
  security_class: "guarded"
image:
  base_image: "ubuntu:24.04"
YAML
git add project.yml; git -c user.name=e2e -c user.email=e2e@example.invalid commit -q -m p
porelo project follow --unverified \$name "\$repo" >/dev/null
agent=\$(porelo agents | awk '\$1 == "NAME" {table = 1; next} table && NF {print \$1; exit}')
porelo task start -p \$name -r \$name \${agent:+--agent "\$agent"} --attach shell \\
  --credential $entry=e2e-api --no-gate --detach auth >/dev/null
''');
}
