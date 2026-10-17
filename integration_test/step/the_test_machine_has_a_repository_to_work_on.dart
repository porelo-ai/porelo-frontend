import 'package:flutter_test/flutter_test.dart';

import '../support/remote.dart';

/// Where the scenario's repository is on the test machine, as git reaches it there.
String? theRepositoryThere;

/// Usage: the test machine has a repository {'e2e-default'} to work on
///
/// A bare repository with one commit on the test machine itself: the VM reaches no forge, and an
/// address on the machine is one Porelo takes.
Future<void> theTestMachineHasARepositoryToWorkOn(WidgetTester tester, String name) async {
  theRepositoryThere = (await onTheTestMachine('''
set -eu
PATH="\$HOME/.local/bin:\$PATH"
porelo project default remove "$name" >/dev/null 2>&1 || true
rm -rf "\$HOME/$name" "\$HOME/$name.git"
git init -q --bare -b main "\$HOME/$name.git"
git clone -q "\$HOME/$name.git" "\$HOME/$name" 2>/dev/null
cd "\$HOME/$name"
git -c user.name=e2e -c user.email=e2e@example.invalid commit -q --allow-empty -m first
git push -q origin HEAD:main
echo "\$HOME/$name.git"
''')).trim();
  expect(theRepositoryThere, endsWith('$name.git'));
  removeAfterwards(
    remove: 'porelo project default remove "$name" >/dev/null 2>&1 || true; rm -rf "\$HOME/$name" "\$HOME/$name.git"',
    leftOver: '[ -e "\$HOME/$name" ] && echo "LEFT:$name"; [ -e "\$HOME/$name.git" ] && echo "LEFT:$name.git"; true',
    names: <String>['LEFT:$name', 'LEFT:$name.git'],
  );
}
