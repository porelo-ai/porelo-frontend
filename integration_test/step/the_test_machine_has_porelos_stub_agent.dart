import 'package:flutter_test/flutter_test.dart';

import '../support/remote.dart';

/// Usage: the test machine has Porelo's stub agent
///
/// Porelo's own test agent, the only one that ends by its provider's refusal without a real key. Where
/// the account lacks it, the newest stub snapshot is put into the account with nothing that needs root,
/// read anonymously from its folder of its own on Artifactory and checked against that version's own
/// digest. Where it cannot be had, the scenario fails here, saying so.
Future<void> theTestMachineHasPorelosStubAgent(WidgetTester tester) => onTheTestMachine(installingTheNewestStub);

/// The script that puts the stub agent into the account where it lacks one: the newest snapshot its folder holds, by
/// version order, so snapshot.1000 comes after snapshot.999. A snapshot uses snapshots throughout, and the folder
/// keeps the newest 20 versions only, so no version is named here. It is refused, each time in its own words, where
/// the listing names no version or no snapshot, where the version's porelo-agent-stub.sha256 holds no SHA-256, and
/// where the binary does not match it; one line on standard error names the version and digest taken.
const installingTheNewestStub = r'''
set -eu
PATH="$HOME/.local/bin:$PATH"
has() { porelo agents | awk 'NR > 1 {print $1}' | grep -qx stub; }
if ! has; then
  refuse() { echo "stub agent: $*" >&2; exit 1; }
  fetch() { curl -fsSL --proto '=https' --proto-redir '=https' --connect-timeout 30 --max-time 300 "$@"; }
  listing=https://fuinorg.jfrog.io/artifactory/api/storage/porelo-dist-test/porelo-agent-stub
  folder=https://fuinorg.jfrog.io/artifactory/porelo-dist-test/porelo-agent-stub
  d=$(mktemp -d)
  trap 'rm -rf "$d"' EXIT
  fetch -o "$d/listing.json" "$listing" || refuse "its folder's listing could not be read from $listing"
  versions=$(grep -o '"uri" *: *"/[^"]*"' "$d/listing.json" | sed 's/.*"\/\([^"]*\)"$/\1/')
  [ -n "$versions" ] || refuse "its folder's listing at $listing names no version"
  version=$(printf '%s\n' "$versions" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+~snapshot\.[0-9]+$' | sort -V | tail -n 1)
  [ -n "$version" ] || refuse "its folder's listing at $listing names no snapshot version, only:" $versions
  fetch -o "$d/stub.sha256" "$folder/$version/porelo-agent-stub.sha256" ||
    refuse "$version: its porelo-agent-stub.sha256 could not be fetched"
  sha256=$(awk 'NR == 1 { print $1 }' "$d/stub.sha256")
  [[ $sha256 =~ ^[0-9a-f]{64}$ ]] ||
    refuse "$version: its porelo-agent-stub.sha256 holds no SHA-256 of 64 lower-case hexadecimal digits"
  fetch -o "$d/stub" "$folder/$version/porelo-agent-stub" || refuse "$version: its porelo-agent-stub could not be fetched"
  echo "$sha256  $d/stub" | sha256sum -c --status - ||
    refuse "$version: its porelo-agent-stub does not match the SHA-256 $sha256 its porelo-agent-stub.sha256 names"
  echo "stub agent: taking $version, SHA-256 $sha256" >&2
  install -D -m 755 "$d/stub" "$HOME/.local/lib/porelo-agent-stub/stub"
  mkdir -p "$HOME/.local/share/porelo/agents.d"
  printf 'executable: %s\n' "$HOME/.local/lib/porelo-agent-stub/stub" >"$HOME/.local/share/porelo/agents.d/stub.yaml"
fi
has || { echo "no agent called stub after installing it" >&2; exit 1; }
''';
