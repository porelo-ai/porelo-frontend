import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/desk.dart';
import 'package:porelo_frontend/src/app/operations.dart';
import 'package:porelo_frontend/src/app/settings.dart';

/// Where the interface keeps its files, how it keeps them to their owner, and how it opens a file
/// or an address, on Linux and on Windows, without either system under the test.
void main() {
  const windows = <String, String>{
    'USERPROFILE': r'C:\Users\somebody',
    'APPDATA': r'C:\Users\somebody\AppData\Roaming',
    'LOCALAPPDATA': r'C:\Users\somebody\AppData\Local',
    'USERNAME': 'somebody',
  };

  // Harm: altering an ordinary path sends file operations to the wrong location.
  test('home expansion leaves absolute and relative paths unchanged', () {
    final here = Desk.of('linux', {'HOME': '/home/somebody'});
    expect(here.expandHome('/keys/key'), '/keys/key');
    expect(here.expandHome('keys/key'), 'keys/key');
    expect(here.expandHome('keys/~backup'), 'keys/~backup');
  });

  // Harm: a literal tilde makes file preparation use a nonexistent home directory.
  test('home expansion expands a tilde alone and a home-relative path on each desktop', () {
    final linux = Desk.of('linux', {'HOME': '/home/somebody'});
    final win = Desk.of('windows', windows);
    expect(linux.expandHome('~'), '/home/somebody');
    expect(linux.expandHome('~/.ssh/key'), '/home/somebody/.ssh/key');
    expect(win.expandHome('~'), windows['USERPROFILE']);
    expect(win.expandHome('~/.ssh/key'), r'C:\Users\somebody\.ssh\key');
  });

  // Harm: a named-user home path silently targets a nonexistent or unintended file.
  test('home expansion refuses named users with an explanation', () {
    final here = Desk.of('linux', {'HOME': '/home/somebody'});
    for (final value in ['~user', '~user/key']) {
      expect(
        () => here.expandHome(value),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'explanation',
            allOf(contains('~user'), contains('only ~/ is understood')),
          ),
        ),
      );
    }
  });

  group('on Windows', () {
    test('the machine list is under the roaming application data, where the plugin reads it', () {
      expect(
        FileSettingsStore.defaultFile(windows, 'windows').path,
        r'C:\Users\somebody\AppData\Roaming\porelo\frontend.json',
      );
    });

    test('what the interface records itself is under the local application data', () {
      expect(
        FileOperationsStore.defaultFile(windows, 'windows').path,
        r'C:\Users\somebody\AppData\Local\porelo\operations.json',
      );
      expect(Desk.of('windows', windows).data, r'C:\Users\somebody\AppData\Local\porelo-frontend');
    });

    test('without the application data variables, the folders under the profile are taken', () {
      const bare = <String, String>{'USERPROFILE': r'C:\Users\somebody\'};

      expect(
        FileSettingsStore.defaultFile(bare, 'windows').path,
        r'C:\Users\somebody\AppData\Roaming\porelo\frontend.json',
      );
    });

    test('a file is kept to its owner by cutting inheritance and granting the user alone', () async {
      final ran = <List<String>>[];
      final here = Desk.of(
        'windows',
        windows,
        run: (executable, arguments) async {
          ran.add(<String>[executable, ...arguments]);
          return ProcessResult(0, 0, '', '');
        },
      );

      await here.keepPrivate(r'C:\x\frontend.json.writing');
      await here.keepPrivate(r'C:\x\keys', directory: true);

      expect(ran, <List<String>>[
        <String>['icacls', r'C:\x\frontend.json.writing', '/inheritance:r', '/grant:r', 'somebody:F'],
        <String>['icacls', r'C:\x\keys', '/inheritance:r', '/grant:r', 'somebody:(OI)(CI)F'],
      ]);
    });

    test('a file or an address is opened as a double click opens it, with no shell reading it', () async {
      final started = <List<String>>[];
      final here = Desk.of(
        'windows',
        windows,
        startDetached: (executable, arguments) async {
          started.add(<String>[executable, ...arguments]);
        },
      );

      await here.open(r'C:\x\a & b.json');

      expect(started, <List<String>>[
        <String>['rundll32', 'url.dll,FileProtocolHandler', r'C:\x\a & b.json'],
      ]);
    });
  });

  group('on Linux', () {
    const linux = <String, String>{'HOME': '/home/somebody'};

    test('the folders are the XDG ones', () {
      final here = Desk.of('linux', linux);

      expect(here.configuration, '/home/somebody/.config/porelo');
      expect(here.state, '/home/somebody/.local/state/porelo');
      expect(here.data, '/home/somebody/.local/share/porelo-frontend');
    });

    test('a file is kept to its owner with chmod, and opened with xdg-open', () async {
      final ran = <List<String>>[];
      final started = <List<String>>[];
      final here = Desk.of(
        'linux',
        linux,
        run: (executable, arguments) async {
          ran.add(<String>[executable, ...arguments]);
          return ProcessResult(0, 0, '', '');
        },
        startDetached: (executable, arguments) async {
          started.add(<String>[executable, ...arguments]);
        },
      );

      await here.keepPrivate('/x/frontend.json.writing');
      await here.keepPrivate('/x/keys', directory: true);
      await here.open('https://example.org/');

      expect(ran, <List<String>>[
        <String>['chmod', '600', '/x/frontend.json.writing'],
        <String>['chmod', '700', '/x/keys'],
      ]);
      expect(started, <List<String>>[
        <String>['xdg-open', 'https://example.org/'],
      ]);
    });

    test('nothing to open with is quiet: the target is on screen to be opened by hand', () async {
      final here = Desk.of(
        'linux',
        linux,
        startDetached: (executable, arguments) async {
          throw ProcessException(executable, arguments);
        },
      );

      await here.open('/x/operations.json');
    });
  });
}
