import 'package:flutter_test/flutter_test.dart';

import '../support/remote.dart';

/// The project the refused work is in, and the work's name.
const refusedByItsProvider = 'e2e-ended';

/// The task the machine makes of it.
const refusedTask = 'porelo-$refusedByItsProvider-ended';

/// Usage: work on the test machine was started with a key {'anthropic'} its provider refuses
///
/// Porelo's case for an agent that ended: the stub, unattended, with a fake key in
/// its provider's entry. Its last act is one call to the provider, which refuses the key, and the
/// stub reads that answer as its end.
Future<void> workOnTheTestMachineWasStartedWithAKeyItsProviderRefuses(WidgetTester tester, String entry) async {
  removeAfterwards(
    remove:
        '${removingTheWork(refusedTask, refusedByItsProvider)}'
        'porelo vault remove --without-revoking $entry >/dev/null 2>&1 || true',
    leftOver: '$listingTheWork; porelo vault list 2>/dev/null | sed "s/^/ENTRY:/"',
    names: <String>[refusedTask, 'ENTRY:$entry '],
  );
  await onTheTestMachine('''
set -eu
PATH="\$HOME/.local/bin:\$PATH"
# Never over a key this account holds already: only the fake one this scenario puts there is removed.
if porelo vault list | grep -q '^$entry '; then echo "the account holds an entry $entry already" >&2; exit 1; fi
printf 'sk-ant-api03-%s' "\$(printf 'not-a-real-key-%.0s' 1 2 3 4 5 6)" | porelo vault put --type=api-key $entry >/dev/null || {
  # A put that complains may still have stored it: what this scenario put there goes again.
  porelo vault remove --without-revoking $entry >/dev/null 2>&1; exit 1; }
name=$refusedByItsProvider; repo="\$HOME/\$name"
porelo project unfollow --force \$name >/dev/null 2>&1 || true
rm -rf "\$repo"; mkdir -p "\$repo"; cd "\$repo"; git init -q -b main
cat > project.yml <<'YAML'
project:
  name: "$refusedByItsProvider"
  security_class: "guarded"
image:
  base_image: "ubuntu:24.04"
YAML
git add project.yml; git -c user.name=e2e -c user.email=e2e@example.invalid commit -q -m p
porelo project follow --unverified \$name "\$repo" >/dev/null
porelo task start -p \$name -r \$name --agent stub -P 'say hello' --clearance deny --detach ended >/dev/null
''');
}
