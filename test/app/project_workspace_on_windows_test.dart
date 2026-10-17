import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/desk.dart';
import 'package:porelo_frontend/src/app/forge.dart';
import 'package:porelo_frontend/src/app/project_workspace.dart';

/// Where a forge workspace looks for the keys this interface made, on each system.
///
/// The harm: on Windows it looked under `$HOME`, which is not set there, so the keys made for
/// machines were offered as the person's own to sign with.
void main() {
  late Desk before;

  setUp(() => before = desk);
  tearDown(() => desk = before);

  test("on Windows the keys made for machines are looked for in the person's profile", () {
    desk = Desk.of('windows', const <String, String>{'USERPROFILE': r'C:\Users\alice'});
    const repository = ForgeRepository(
      fullName: 'team/app',
      sshUrl: 'git@github.com:team/app.git',
      httpsUrl: 'https://github.com/team/app.git',
      defaultBranch: 'main',
      admin: true,
      push: true,
      private: true,
    );

    final workspace = ProjectWorkspace(repository, 't', root: r'C:\Users\alice\porelo');

    expect(workspace.sshDirectory, r'C:\Users\alice\.ssh');
  });
}
