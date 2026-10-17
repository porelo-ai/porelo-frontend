import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/remote.dart';

/// The loopback port the stand-in listens on, in the test machine's account.
const standInPort = 18091;

/// Usage: the test machine has an entry {'e2e-grant'} a stand-in service grants
Future<void> theTestMachineHasAnEntryAStandinServiceGrants(WidgetTester tester, String entry) =>
    anEntryAStandInGrants(entry);

/// An `oauth-device` entry [entry] whose service is the stand-in on loopback. [lasting] makes it
/// grant as GitHub's OAuth apps do: a token with no refresh token and no expiry, which the service
/// offers no way to revoke.
Future<void> anEntryAStandInGrants(String entry, {bool lasting = false}) async {
  // A device flow with nothing real behind it, on loopback in this account only: what Porelo allows
  // over plain http. It says "pending" until it is told yes, as a person deciding would.
  final service = File('integration_test/support/stand_in_authorization.py').readAsStringSync();
  removeAfterwards(
    remove:
        'porelo vault remove --without-revoking $entry >/dev/null 2>&1 || true\n'
        'pkill -f "stand_in_authorization.py $standInPort" 2>/dev/null || true\n'
        'rm -f "\$HOME/stand_in_authorization.py"',
    leftOver:
        'porelo vault list 2>/dev/null | sed "s/^/ENTRY:/"\n'
        'pgrep -f "stand_in_authorization.py $standInPort" >/dev/null && echo STANDIN; true',
    names: <String>['ENTRY:$entry ', 'STANDIN'],
  );
  await onTheTestMachine('''
set -eu
PATH="\$HOME/.local/bin:\$PATH"
pkill -f "stand_in_authorization.py $standInPort" 2>/dev/null || true
cat > "\$HOME/stand_in_authorization.py" <<'PY'
$service
PY
nohup python3 "\$HOME/stand_in_authorization.py" $standInPort ${lasting ? 'lasting' : ''} >/dev/null 2>&1 &
for i in \$(seq 1 50); do curl -fs http://127.0.0.1:$standInPort/log >/dev/null && break; sleep 0.1; done
porelo vault remove --without-revoking $entry >/dev/null 2>&1 || true
u=http://127.0.0.1:$standInPort
printf -- '-' | porelo vault put --type=oauth-device --setting=client_id=porelo-e2e \\
  --setting=device_authorization_url=\$u/device --setting=token_url=\$u/token --setting=scopes=read \\
  ${lasting ? '' : '--setting=revocation_url=\$u/revoke'} $entry >/dev/null 2>&1
porelo vault list | grep -q '^$entry '
''');
}
