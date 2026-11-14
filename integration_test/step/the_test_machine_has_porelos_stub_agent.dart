import 'package:flutter_test/flutter_test.dart';

import '../support/remote.dart';

/// The stub agent the scenarios use, pinned as the collection is: its version and the digest beside it there.
const stubAgent = (
  // Its folder keeps the newest 20 versions: tool/stub_pin.sh, run by tool/e2e.sh, says when this one is to move.
  version: '0.5.1~snapshot.536',
  // The digest in that version's own porelo-agent-stub.sha256.
  sha256: '0eaae49d1f8aca57cd85cbd2112ccc8b0e5fb380d7de3320168609e64a89cf8e',
);

/// Usage: the test machine has Porelo's stub agent
///
/// Porelo's own test agent, the only one that ends by its provider's refusal without a real key. Where
/// the account lacks it, the pinned stub is put into the account with nothing that needs root, read
/// anonymously from its folder of its own on Artifactory and checked against its digest. Where it cannot
/// be had, the scenario fails here, saying so.
Future<void> theTestMachineHasPorelosStubAgent(WidgetTester tester) => onTheTestMachine('''
set -eu
PATH="\$HOME/.local/bin:\$PATH"
has() { porelo agents | awk 'NR > 1 {print \$1}' | grep -qx stub; }
if ! has; then
  d=\$(mktemp -d)
  trap 'rm -rf "\$d"' EXIT
  curl -fsSL -o "\$d/stub" 'https://fuinorg.jfrog.io/artifactory/porelo-dist-test/porelo-agent-stub/${stubAgent.version}/porelo-agent-stub' ||
    { echo "stub ${stubAgent.version} could not be fetched: its folder keeps the newest versions only, so the pin may have to move" >&2; exit 1; }
  echo "${stubAgent.sha256}  \$d/stub" | sha256sum -c --quiet -
  install -D -m 755 "\$d/stub" "\$HOME/.local/lib/porelo-agent-stub/stub"
  mkdir -p "\$HOME/.local/share/porelo/agents.d"
  printf 'executable: %s\\n' "\$HOME/.local/lib/porelo-agent-stub/stub" >"\$HOME/.local/share/porelo/agents.d/stub.yaml"
fi
has || { echo "no agent called stub after installing it" >&2; exit 1; }
''');
