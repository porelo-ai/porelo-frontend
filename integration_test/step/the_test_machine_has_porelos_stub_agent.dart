import 'package:flutter_test/flutter_test.dart';

import '../support/remote.dart';

/// Usage: the test machine has Porelo's stub agent
///
/// Porelo's own test agent, the only one that ends by its provider's refusal without a real key. Where
/// the account lacks it, the newest published stub is put into the account with nothing that needs
/// root, as [unpackPorelo] fetches it: the `.deb` or the `.rpm`, by what the machine has. Where it
/// cannot be had, the scenario fails here, saying so.
Future<void> theTestMachineHasPorelosStubAgent(WidgetTester tester) => onTheTestMachine(
  unpackPorelo +
      r'''
set -eu
PATH="$HOME/.local/bin:$PATH"
has() { porelo agents | awk 'NR > 1 {print $1}' | grep -qx stub; }
if ! has; then
  d=$(mktemp -d)
  trap 'rm -rf "$d"' EXIT
  unpack_porelo porelo-agent-stub "$d/x"
  # Since 0.5.1 the package names its program in an agent description; before, it was the program alone.
  if test -f "$d/x/usr/lib/porelo-agent-stub/stub"; then
    install -D -m 755 "$d/x/usr/lib/porelo-agent-stub/stub" "$HOME/.local/lib/porelo-agent-stub/stub"
    mkdir -p "$HOME/.local/share/porelo/agents.d"
    printf 'executable: %s\n' "$HOME/.local/lib/porelo-agent-stub/stub" >"$HOME/.local/share/porelo/agents.d/stub.yaml"
  else
    install -D -m 755 "$d/x/usr/libexec/porelo/agents/porelo-agent-stub" "$HOME/.local/share/porelo/agents/porelo-agent-stub"
  fi
fi
has || { echo "no agent called stub after installing it" >&2; exit 1; }
''',
);
