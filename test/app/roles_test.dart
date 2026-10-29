import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/roles.dart';

void main() {
  // Harm: a startup argument exposes administration to a person who did not request it.
  test('startup without roles holds only user', () {
    final roles = Roles.fromArguments(const []);
    expect(Role.values.where(roles.holds).toSet(), {Role.user});
  });

  test('the comma list accepts every known role and always includes user', () {
    final roles = Roles.fromArguments(const ['--roles', 'host-admin,project-admin,access-admin']);
    expect(Role.values.where(roles.holds).toSet(), Role.values.toSet());
  });

  test('access administration implies no host or project administration', () {
    final roles = Roles.fromArguments(const ['--roles', 'access-admin']);
    expect(Role.values.where(roles.holds).toSet(), {Role.user, Role.accessAdmin});
  });

  test('repeated roles and whitespace do not change which roles are held', () {
    final roles = Roles.fromArguments(const ['--roles', ' project-admin,user,project-admin ']);
    expect(Role.values.where(roles.holds).toSet(), {Role.user, Role.projectAdmin});
  });

  test('other startup arguments leave ordinary work available', () {
    final roles = Roles.fromArguments(const ['--diagnose-terminal']);
    expect(Role.values.where(roles.holds).toSet(), {Role.user});
  });

  test('the equals form and repeated options combine roles', () {
    final roles = Roles.fromArguments(const ['--roles=host-admin', '--roles', 'project-admin']);
    expect(Role.values.where(roles.holds).toSet(), {Role.user, Role.hostAdmin, Role.projectAdmin});
  });

  // Harm: a misspelled role silently starts an interface with unintended commands.
  for (final argument in ['root', 'host-admin,unknown', 'USER']) {
    test('an unknown role is refused and names every known role ($argument)', () {
      expect(
        () => Roles.fromArguments(['--roles', argument]),
        throwsA(
          isA<FormatException>()
              .having((error) => error.message, 'refused role', contains(argument.split(',').last))
              .having(
                (error) => error.message,
                'known roles',
                contains('user, host-admin, project-admin, access-admin'),
              ),
        ),
      );
    });
  }

  for (final arguments in <List<String>>[
    ['--roles'],
    ['--roles', '--diagnose-terminal'],
    ['--roles', ''],
    ['--roles='],
    ['--roles', 'user,'],
  ]) {
    test('an incomplete role list is refused ($arguments)', () {
      expect(() => Roles.fromArguments(arguments), throwsFormatException);
    });
  }
}
