import 'package:flutter_test/flutter_test.dart';

import '../support/project_file.dart';
import '../support/remote.dart';

/// Usage: the test machine has a project repository {'e2e-follow'}
Future<void> theTestMachineHasAProjectRepository(WidgetTester tester, String name) async {
  // Made fresh each run, with an identity given on the command line: a rented machine has none.
  theRepository = await onTheTestMachine('''
set -eu
repo="\$HOME/$name"
rm -rf "\$repo"
mkdir -p "\$repo"
cd "\$repo"
git init -q -b main
cat > project.yml <<'YAML'
${projectFile(name)}
YAML
git add project.yml
git -c user.name=e2e -c user.email=e2e@example.invalid commit -q -m "The project $name"
echo "\$repo"
''');
  removeAfterwards(
    remove: 'rm -rf "\$HOME/$name"',
    leftOver: '[ -e "\$HOME/$name" ] && echo "LEFT:$name"; true',
    names: <String>['LEFT:$name'],
  );
}
