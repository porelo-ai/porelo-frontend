import 'package:flutter_test/flutter_test.dart';

import '../support/matrix.dart';
import '../support/remote.dart';

/// Why this machine cannot hold a conversation at all, or null where it can. Set here, read by the
/// scenario's other steps, which then do nothing: a skip says so in the report, a pass would lie.
String? noConversationHere;

/// Usage: the test machine has a project {'e2e-mx'} with a conversation
Future<void> theTestMachineHasAProjectWithAConversation(WidgetTester tester, String name) async {
  final found = await matrixInTheAccount() ? 'yes' : 'no';
  noConversationHere = found == 'yes' ? null : 'the Matrix transport could not be installed here';
  if (noConversationHere != null) {
    markTestSkipped(noConversationHere!);
    return;
  }
  removeAfterwards(
    remove: removingTheWork('porelo-$name-write', name),
    leftOver: listingTheWork,
    names: <String>['porelo-$name-write'],
  );
  await onTheTestMachine('''
set -eu
PATH="\$HOME/.local/bin:\$PATH"
porelo task stop porelo-$name-write >/dev/null 2>&1 || true
porelo task remove porelo-$name-write >/dev/null 2>&1 || true
porelo project unfollow --force $name >/dev/null 2>&1 || true
repo="\$HOME/$name"; rm -rf "\$repo"; mkdir -p "\$repo"; cd "\$repo"; git init -q -b main
cat > project.yml <<'YAML'
project:
  name: "$name"
  security_class: "guarded"
image:
  base_image: "ubuntu:24.04"
mail:
  transports:
    matrix: {}
  peers:
    person: { address: "matrix:", trust: external }
YAML
git add project.yml
git -c user.name=e2e -c user.email=e2e@example.invalid commit -q -m "The project $name"
porelo project follow --unverified $name "\$repo" >/dev/null
agent=\$(porelo agents | awk '\$1 == "NAME" {table = 1; next} table && NF {print \$1; exit}')
porelo task start -p $name -r $name \${agent:+--agent "\$agent"} --attach shell --no-gate --detach write >/dev/null
''');
}
