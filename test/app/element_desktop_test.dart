import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:porelo_frontend/src/app/element_desktop.dart';

void main() {
  InstalledElement element(
    String system,
    Map<String, String> environment,
    Set<String> files, {
    List<List<String>>? started,
    Map<String, String>? written,
  }) => InstalledElement(
    operatingSystem: system,
    environment: environment,
    configFolder: system == 'windows' ? r'C:\porelo\element' : '/data/porelo/element',
    exists: files.contains,
    write: (path, text) async => written?[path] = text,
    startDetached: (program, arguments) async => started?.add([program, ...arguments]),
  );

  // Harm: offering to open an Element that is not here leaves the person with a button that does nothing.
  test('Element is found where it is installed, and missed where it is not', () async {
    const path = {'PATH': '/usr/local/bin:/usr/bin', 'HOME': '/home/anna'};
    expect(await element('linux', path, {}).installed(), isFalse);
    expect(await element('linux', path, {'/usr/bin/element-desktop'}).installed(), isTrue);
    expect(await element('linux', path, {'/var/lib/flatpak/exports/bin/im.riot.Riot'}).installed(), isTrue);
    expect(
      await element('linux', path, {'/home/anna/.local/share/flatpak/exports/bin/im.riot.Riot'}).installed(),
      isTrue,
    );
    expect(await element('linux', path, {'/snap/bin/element-desktop'}).installed(), isTrue);
    expect(
      await element(
        'windows',
        {'LOCALAPPDATA': r'C:\Users\anna\AppData\Local'},
        {r'C:\Users\anna\AppData\Local\element-desktop\Element.exe'},
      ).installed(),
      isTrue,
    );
    expect(
      await element('macos', {'HOME': '/Users/anna'}, {'/Applications/Element.app/Contents/MacOS/Element'}).installed(),
      isTrue,
    );
  });

  // Harm: an Element started without the host's homeserver signs the person in to another server, or to none.
  test('Element starts with the host homeserver set, SSO first, and its own profile when asked', () async {
    final started = <List<String>>[];
    final written = <String, String>{};
    final here = element(
      'linux',
      const {'PATH': '/usr/bin'},
      {'/usr/bin/element-desktop'},
      started: started,
      written: written,
    );
    await here.open(homeserver: 'http://alpha.localhost:18082/', profile: 'alpha');
    expect(started.single.take(5), [
      '/usr/bin/element-desktop',
      '--profile',
      'alpha',
      '--config',
      '/data/porelo/element/alpha.json',
    ]);
    expect(started.single.last, startsWith('element://vector/webapp/?hs_url=http%3A%2F%2Falpha.localhost%3A18082%2F'));
    final config = jsonDecode(written['/data/porelo/element/alpha.json']!) as Map<String, Object?>;
    expect(config['default_server_config'], {
      'm.homeserver': {'base_url': 'http://alpha.localhost:18082/'},
    });
    expect(config['sso_redirect_options'], {'on_welcome_page': true});
    started.clear();
    await here.open(homeserver: 'http://alpha.localhost:18082/');
    expect(started.single, isNot(contains('--profile')), reason: 'without the box, the Element already set up');
  });

  // Harm: a config path written with the other system's separator is a file Element never finds.
  test('on Windows the config is named with its own separator', () async {
    final started = <List<String>>[];
    final written = <String, String>{};
    await element(
      'windows',
      const {'LOCALAPPDATA': r'C:\Users\anna\AppData\Local'},
      {r'C:\Users\anna\AppData\Local\element-desktop\Element.exe'},
      started: started,
      written: written,
    ).open(homeserver: 'http://alpha.localhost:18082/', profile: 'alpha');
    expect(written.keys, [r'C:\porelo\element\alpha.json']);
    expect(started.single.take(5), [
      r'C:\Users\anna\AppData\Local\element-desktop\Element.exe',
      '--profile',
      'alpha',
      '--config',
      r'C:\porelo\element\alpha.json',
    ]);
  });

  // Harm: a config cut off half written is read by Element as no config, or as a broken one.
  test('the config is written whole or not at all', () async {
    final folder = Directory.systemTemp.createTempSync('element-config');
    addTearDown(() => folder.deleteSync(recursive: true));
    // Joined by the platform's separator, as the folder's listing spells it on Windows too.
    final config = path.join(folder.path, 'alpha.json');
    File(config).writeAsStringSync('old');
    await writeWhole(config, 'new');
    expect(File(config).readAsStringSync(), 'new');
    expect(folder.listSync().map((each) => each.path), [config], reason: 'no temporary file is left beside it');
  });
}
