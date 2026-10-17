import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/forge.dart';

import '../support/world.dart';

/// Usage: the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
Future<void> theForgeReachesAsAnAdminAndWithoutAdminRights(WidgetTester tester, String admin, String not) async {
  ForgeRepository repository(String name, {required bool admin}) => ForgeRepository(
    fullName: name,
    sshUrl: 'git@github.com:$name.git',
    httpsUrl: 'https://github.com/$name.git',
    defaultBranch: 'main',
    admin: admin,
    push: true,
    private: true,
  );
  World.forge.repositoriesHere = <ForgeRepository>[repository(admin, admin: true), repository(not, admin: false)];
}
