import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/conpty.dart';

/// The one string a Windows program is started with, quoted so that it splits back into exactly the
/// arguments the interface meant: a task's name, a distribution's or a host's is never cut in two
/// or joined with the next.
void main() {
  test('plain arguments are written as they are', () {
    expect(windowsCommandLine(<String>['wsl.exe', '-d', 'Ubuntu', '--', 'porelo', 'task', 'attach', 'fix-it']),
        'wsl.exe -d Ubuntu -- porelo task attach fix-it');
  });

  test('an argument with a space or a tab is quoted, and an empty one is kept', () {
    expect(windowsCommandLine(<String>['wsl.exe', '-d', 'Ubuntu 26.04', 'a\tb', '']),
        'wsl.exe -d "Ubuntu 26.04" "a\tb" ""');
  });

  test('a quote inside is escaped, with the backslashes before it doubled', () {
    expect(windowsCommandLine(<String>[r'say "hi"', r'a\"b']), r'"say \"hi\"" "a\\\"b"');
  });

  test('backslashes are left alone unless a quote follows, the closing one included', () {
    expect(windowsCommandLine(<String>[r'C:\Program Files\x', r'C:\dir with space\']),
        r'"C:\Program Files\x" "C:\dir with space\\"');
    expect(windowsCommandLine(<String>[r'C:\no\space']), r'C:\no\space');
  });
}
