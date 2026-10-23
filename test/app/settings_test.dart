import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/settings.dart';

void main() {
  // Harm: choosing another project's folder overwrites files in the wrong tresor.
  // Red: keep one global folder, omit it from _known, or cast malformed stored fields.
  test('tresor folders are kept separately and invalid stored fields are ignored', () async {
    final store = MemorySettingsStore(<String, Object?>{
      'tresorFolders': <Object?, Object?>{'demo': '/first', 'bad': 7, 9: '/wrong', 'empty': '', 'nul': '/a\x00b'},
    });
    final settings = Settings(store);
    await settings.load();
    expect(settings.tresorFolder('demo'), '/first');
    for (final name in ['bad', '9', 'empty', 'nul']) {
      expect(settings.tresorFolder(name), isNull);
    }
    await settings.rememberTresorFolder('other', '/second');
    await settings.rememberTresorFolder('demo', '/changed');
    final again = Settings(store);
    await again.load();
    expect(again.tresorFolder('demo'), '/changed');
    expect(again.tresorFolder('other'), '/second');
    await again.rememberTresorFolder('demo', null);
    final last = Settings(store);
    await last.load();
    expect(last.tresorFolder('demo'), isNull);
    expect(last.tresorFolder('other'), '/second');
  });

  test('new machines run work as agent until somebody says otherwise, and it is kept', () async {
    final store = MemorySettingsStore();
    final settings = Settings(store);
    expect(settings.workUser, 'agent');

    await settings.setWorkUser('builder');

    final again = Settings(store);
    await again.load();
    expect(again.workUser, 'builder');
  });

  test('a name no Linux machine would accept is never kept', () async {
    final settings = Settings(MemorySettingsStore());

    for (final wrong in <String>['Root', 'with space', '9lives', '', "a'b", 'x' * 33]) {
      await settings.setWorkUser(wrong);
      expect(settings.workUser, 'agent', reason: '"$wrong" was kept');
    }
  });

  test('a wrong name stored by hand reads as the default', () async {
    final settings = Settings(MemorySettingsStore(<String, Object?>{'workUser': "x'; rm -rf /"}));

    await settings.load();

    expect(settings.workUser, 'agent');
  });

  // The harm: a second entry of one name, written by hand, was watched beside the first, so calls
  // meant for one machine went through the other's tunnel.
  test('a second machine of a name already read is dropped, the first kept', () async {
    final settings = Settings(
      MemorySettingsStore(<String, Object?>{
        'machines': <Map<String, Object?>>[
          <String, Object?>{'name': 'vm', 'socket': '/tmp/first.sock'},
          <String, Object?>{'name': 'vm', 'socket': '/tmp/second.sock'},
          <String, Object?>{'name': 'other', 'socket': '/tmp/other.sock'},
        ],
      }),
    );

    final machines = await settings.machines();

    expect(
      [for (final each in machines) '${each.name} ${each.socketPath}'],
      <String>['vm /tmp/first.sock', 'other /tmp/other.sock'],
    );
  });

  // The harm: what a later version or another reader of the file wrote at its top level was lost
  // at the next save.
  test('a key this version does not know is kept when the settings are written', () async {
    final store = MemorySettingsStore(<String, Object?>{
      'fromLater': <String, Object?>{'kept': true},
      'workUser': 'agent',
    });
    final settings = Settings(store);
    await settings.load();

    await settings.setRefreshSeconds(30);

    final written = await store.read();
    expect(written['fromLater'], <String, Object?>{'kept': true});
    expect(written['refreshSeconds'], 30);
  });
}
