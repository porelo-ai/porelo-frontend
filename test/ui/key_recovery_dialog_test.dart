import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/identity.dart';
import 'package:porelo_frontend/src/app/key_recovery.dart';
import 'package:porelo_frontend/src/app/organization_source.dart';
import 'package:porelo_frontend/src/app/pty.dart' show SessionChannel;
import 'package:porelo_frontend/src/app/run_here.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/ui/identity_view.dart' show writeCardFile;
import 'package:porelo_frontend/src/ui/key_recovery_dialog.dart';
import 'package:porelo_frontend/src/ui/organization_host_pages.dart';
import 'package:porelo_frontend/src/ui/organization_page.dart';

import '../features/support/world.dart';
import '../support/organization_fixtures.dart';

const _old = 'SHA256:OldOldOldOld';
const _new = 'SHA256:NewNewNewNew';
const _file = '/media/usb/backup';

Map<String, Object?> _shown({List<Map<String, Object?>> pending = const []}) => {
  'login': 'olive',
  'name': 'Olive',
  'email': null,
  'fingerprint': _old,
  'key': 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOldKey',
  'created': '2026-10-31',
  'expires': '2026-11-30',
  'predecessor': null,
  'card': 'login: "olive"\n',
  'agent': 'absent',
  'agent_holds_key': false,
  'revoked': false,
  'card_refused': null,
  'organization': [
    {
      'address': 'git@github.com:acme/organization.git',
      'filed': 'done',
      'revision': 'r1',
      'may_file': true,
      'who_may': <Object?>[],
    },
  ],
  'forge': null,
  'pending': pending,
};

const _agentKeys = {
  'keys': [
    {
      'fingerprint': _new,
      'key': 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINewKey',
      'comment': 'laptop',
      'usable': true,
      'reason': null,
      'key_listed': true,
    },
  ],
};

const _plan = {
  'plan': {
    'who_may': [
      {'login': 'olive', 'name': 'Olive Owner', 'email': null},
    ],
    'accepted_with': 'porelo org person replace LOGIN --card FILE',
    'order': 'A backup key works only while the old key is still on the forge.',
  },
  'hosts': <Object?>[],
  'sign_ins': <Object?>[],
};

/// A terminal that records what it was opened with, ended by the test with an exit code and a last line.
class _Terminal implements SessionChannel {
  final _output = StreamController<List<int>>.broadcast();
  final _ended = Completer<int>();

  void end(int code, String last) {
    _output.add(utf8.encode('$last\r\n'));
    _ended.complete(code);
  }

  @override
  Stream<List<int>> get output => _output.stream;

  @override
  void send(String input) {}

  @override
  void resize({required int columns, required int rows}) {}

  @override
  Future<int> get ended => _ended.future;

  @override
  Future<void> close() async {}
}

class _Rig {
  _Rig() : settings = Settings(MemorySettingsStore());

  final Settings settings;
  final opened = <List<String>>[];
  final called = <List<String>>[];
  final terminal = _Terminal();
  Map<String, Object?> shown = _shown();
  String? newCard = 'login: olive\n';
  final saved = <(String, String)>[];
  String? savingAt = _file;
  Exception? cannotWrite;

  Future<Ran> run(
    String program,
    List<String> arguments, {
    String? inDirectory,
    Map<String, String> environment = const {},
    String? input,
  }) async {
    called.add(arguments);
    final answer = switch (arguments[1]) {
      'show' => shown,
      'keys' => _agentKeys,
      'revoke' when arguments.contains('--dry-run') => _plan,
      'revoke' => {
        'revision': '9d0fcc5',
        'id': arguments[arguments.indexOf('--id') + 1],
        'again': false,
        if (newCard != null) 'card': newCard,
      },
      _ => throw StateError('nothing else is run: $arguments'),
    };
    return (code: 0, out: jsonEncode(answer), err: '');
  }

  KeyCommands get keys => KeyCommands(
    receipts: SettingsReceipts(settings),
    open: (executable, arguments, {columns = 80, rows = 24}) {
      opened.add([executable, ...arguments]);
      return terminal;
    },
    pickAFile: ({String? initialDirectory, String? title}) async => _file,
    chooseNewFile: ({String? title}) async => savingAt,
    writeCard: (String file, String card) async {
      if (cannotWrite case final error?) throw error;
      saved.add((file, card));
    },
    model: IdentityModel(Identity(run: run)),
    environment: const {'XDG_CONFIG_HOME': '/home/olive/.config'},
  );
}

Future<void> _pump(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(1400, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: page)));
  await World.settle(tester);
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await World.settle(tester);
  await tester.tap(target);
  await World.settle(tester);
}

Finder _action(String id) => find.byKey(ValueKey('organization.$id'));

Future<(FixtureOrganization, Organization)> _organization(WidgetTester tester, String me) async {
  final fixture = FixtureOrganization(organizationFor(me));
  final organization = Organization(fixture);
  addTearDown(organization.dispose);
  return (fixture, organization);
}

void main() {
  group('a backup key under Owners', () {
    // Harm: a passphrase typed into a form, or a scope Core has dropped sent to it.
    testWidgets('runs the organization’s command in a terminal against the revision the page read', (tester) async {
      final rig = _Rig();
      final (_, organization) = await _organization(tester, 'olive');
      await _pump(tester, OrganizationPage(organization: organization, keys: rig.keys));

      await _tap(tester, _action('makeBackupKey'));
      expect(find.byKey(const Key('unlock-terminal')), findsOneWidget, reason: 'the passphrase goes to the terminal');
      final command = rig.opened.single;
      expect(command.take(4).toList(), ['porelo', 'identity', 'backup-key', '--organization']);
      expect(command, containsAllInOrder(['--out', _file, '--base', 'r1', '--id']));
      expect(command.last, '--json');
      expect(command, isNot(contains('--registry')));
      expect(command, isNot(contains('--project')));

      final id = command[command.indexOf('--id') + 1];
      rig.terminal.end(0, jsonEncode({'revision': '9d0fcc5', 'id': id, 'again': false}));
      await World.settle(tester);
      await _tap(tester, find.byKey(const Key('unlock-done')));
      expect(find.byKey(const Key('backup-key-said')), findsOneWidget);
      expect(SettingsReceipts(rig.settings).read('backup-make/organization'), isNull, reason: 'it is done');
    });

    // Harm: a refusal read as done, and the store's own reason lost.
    testWidgets('shows the store’s refusal in its words', (tester) async {
      final rig = _Rig();
      final (_, organization) = await _organization(tester, 'olive');
      await _pump(tester, OrganizationPage(organization: organization, keys: rig.keys));
      await _tap(tester, _action('makeBackupKey'));
      rig.terminal.end(65, jsonEncode({'reason': 'not-allowed', 'words': 'only an organization owner may do this'}));
      await World.settle(tester);
      await _tap(tester, find.byKey(const Key('unlock-done')));
      expect(find.text('only an organization owner may do this'), findsOneWidget);
    });

    // Harm: a key made but its answer lost, and made again under a new id.
    testWidgets('keeps its id for a retry when the answer was lost', (tester) async {
      final rig = _Rig();
      final (_, organization) = await _organization(tester, 'olive');
      await _pump(tester, OrganizationPage(organization: organization, keys: rig.keys));
      await _tap(tester, _action('makeBackupKey'));
      final id = rig.opened.single[rig.opened.single.indexOf('--id') + 1];
      rig.terminal.end(69, '');
      await World.settle(tester);
      await _tap(tester, find.byKey(const Key('unlock-done')));
      expect(SettingsReceipts(rig.settings).read('backup-make/organization')?['id'], id);
    });

    // Harm: a person sees an action for a place they do not hold.
    testWidgets('is offered to an owner alone, in their own row', (tester) async {
      final rig = _Rig();
      final (_, organization) = await _organization(tester, 'mia');
      await _pump(tester, OrganizationPage(organization: organization, keys: rig.keys));
      expect(_action('makeBackupKey'), findsNothing);
    });
  });

  group('a backup key on the host’s page', () {
    testWidgets('names the host and never an old scope', (tester) async {
      final rig = _Rig();
      final (_, organization) = await _organization(tester, 'hana');
      await _pump(
        tester,
        OrganizationHostPage(organization: organization, host: 'build', onBack: () {}, keys: rig.keys),
      );
      await _tap(tester, _action('makeBackupKey'));
      final command = rig.opened.single;
      expect(command.take(5).toList(), ['porelo', 'identity', 'backup-key', '--host', 'build']);
      expect(command, containsAllInOrder(['--out', _file, '--base', 'r1', '--id']));
      expect(command, isNot(contains('--registry')));
      expect(command, isNot(contains('--project')));
    });

    testWidgets('is offered to that host’s admin alone', (tester) async {
      final rig = _Rig();
      final (_, organization) = await _organization(tester, 'mia');
      await _pump(
        tester,
        OrganizationHostPage(organization: organization, host: 'build', onBack: () {}, keys: rig.keys),
      );
      expect(_action('makeBackupKey'), findsNothing);
    });
  });

  group('a lost key\'s new card', () {
    Future<_Rig> made(WidgetTester tester, {String? card = 'login: olive\n'}) async {
      final rig = _Rig()..newCard = card;
      final (_, organization) = await _organization(tester, 'olive');
      await _pump(tester, OrganizationPage(organization: organization, keys: rig.keys));
      await _tap(tester, _action('replaceLostKey'));
      await _tap(tester, find.byKey(const Key('identity-key $_new')));
      await _tap(tester, find.byKey(const Key('identity-lost-confirm')));
      return rig;
    }

    // Harm: a person believes the replacement is accepted, or is offered to accept it themselves.
    testWidgets('is shown with the plan and nothing accepts it', (tester) async {
      await made(tester);
      expect(find.text('login: olive\n'), findsOneWidget);
      expect(find.textContaining('Olive Owner (olive)'), findsOneWidget);
      expect(find.byKey(const Key('identity-lost-confirm')), findsNothing);
      expect(find.widgetWithText(TextButton, 'Accept'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Accept'), findsNothing);
    });

    testWidgets('is copied as it came', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await made(tester);
      await _tap(tester, find.byKey(const Key('identity-lost-copy')));
      expect(copied, 'login: olive\n');
    });

    testWidgets('is saved where the file picker says, and only there', (tester) async {
      final rig = await made(tester);
      await _tap(tester, find.byKey(const Key('identity-lost-save')));
      expect(rig.saved, [(_file, 'login: olive\n')]);
    });

    testWidgets('a save put away writes nothing', (tester) async {
      final rig = await made(tester);
      rig.savingAt = null;
      await _tap(tester, find.byKey(const Key('identity-lost-save')));
      expect(rig.saved, isEmpty);
      expect(find.byKey(const Key('identity-lost-said')), findsNothing);
    });

    testWidgets('a file that cannot be written is said', (tester) async {
      final rig = await made(tester);
      rig.cannotWrite = const FileSystemException('no room');
      await _tap(tester, find.byKey(const Key('identity-lost-save')));
      expect(find.textContaining('no room'), findsOneWidget);
    });

    // Harm: nothing to hand over reads as a card made.
    testWidgets('its absence is said, with nothing to copy or save', (tester) async {
      await made(tester, card: null);
      expect(find.byKey(const Key('identity-lost-no-card')), findsOneWidget);
      expect(find.byKey(const Key('identity-lost-copy')), findsNothing);
      expect(find.byKey(const Key('identity-lost-save')), findsNothing);
    });

    test('reaches the file as it came', () async {
      final folder = await Directory.systemTemp.createTemp('new-card');
      addTearDown(() => folder.delete(recursive: true));
      final file = '${folder.path}/card';
      await writeCardFile(file, 'login: olive\n');
      expect(await File(file).readAsString(), 'login: olive\n');
    });
  });

  group('a pending replacement of a lost key', () {
    const row = {'id': 'lost-1', 'action': 'revoke-lost', 'fingerprint': _new};

    // Harm: after a restart the new card is out of reach, or a second key is made to get it.
    testWidgets('Try again answers its card again under the same ID and key', (tester) async {
      final rig = _Rig()..shown = _shown(pending: const [row]);
      final (_, organization) = await _organization(tester, 'olive');
      await _pump(tester, OrganizationPage(organization: organization, keys: rig.keys));
      await _tap(tester, _action('replaceLostKey'));
      await _tap(tester, find.byKey(const Key('identity.tryAgain lost-1')));
      final call = rig.called.singleWhere((call) => call[1] == 'revoke');
      expect(call, containsAllInOrder(['--key', _new, '--id', 'lost-1']));
      expect(find.text('login: olive\n'), findsOneWidget);
    });

    testWidgets('Use another key plans first and sends a new ID', (tester) async {
      const other = 'SHA256:OtherOtherOtherOtherOtherOtherOtherOtherOth';
      final rig = _Rig()
        ..shown = _shown(
          pending: const [
            {'id': 'lost-1', 'action': 'revoke-lost', 'fingerprint': other},
          ],
        );
      final (_, organization) = await _organization(tester, 'olive');
      await _pump(tester, OrganizationPage(organization: organization, keys: rig.keys));
      await _tap(tester, _action('replaceLostKey'));
      await _tap(tester, find.byKey(const Key('identity.useAnotherKey lost-1')));
      await _tap(tester, find.byKey(const Key('identity-key $_new')));
      await _tap(tester, find.byKey(const Key('identity-lost-confirm')));
      final call = rig.called.singleWhere((call) => call[1] == 'revoke' && !call.contains('--dry-run'));
      expect(call[call.indexOf('--key') + 1], _new);
      expect(call[call.indexOf('--id') + 1], isNot('lost-1'));
    });

    // Harm: a person who lost their key chooses a rotation's new key here, where it would become a lost key's.
    // Harm: a person who lost the key of a pending rotation cannot replace it.
    testWidgets('a pending rotation offers no other key on its row, and the lost key is still replaced', (
      tester,
    ) async {
      final rig = _Rig()
        ..shown = _shown(
          pending: const [
            {'id': 'rot-1', 'action': 'rotate', 'fingerprint': _new},
          ],
        );
      final (_, organization) = await _organization(tester, 'olive');
      await _pump(tester, OrganizationPage(organization: organization, keys: rig.keys));
      await _tap(tester, _action('replaceLostKey'));
      expect(tester.widget<TextButton>(find.byKey(const Key('identity.useAnotherKey rot-1'))).onPressed, isNull);
      expect(tester.widget<ListTile>(find.byKey(const Key('identity-key $_new'))).enabled, isTrue);
    });
  });

  group('a lost key in my row', () {
    // Harm: a vault reset with no review, or a person replacing another's key.
    testWidgets('is planned with a dry run, and replaced once only after the review', (tester) async {
      final rig = _Rig();
      final (_, organization) = await _organization(tester, 'olive');
      await _pump(tester, OrganizationPage(organization: organization, keys: rig.keys));
      await _tap(tester, _action('replaceLostKey'));
      await _tap(tester, find.byKey(const Key('identity-key $_new')));
      final revokes = [
        for (final call in rig.called)
          if (call[1] == 'revoke') call,
      ];
      expect(revokes, [
        ['identity', 'revoke', '--lost', '--key', _new, '--dry-run', '--json'],
      ]);
      expect(find.byKey(const Key('identity-lost-plan')), findsOneWidget);
      await _tap(tester, find.byKey(const Key('identity-lost-confirm')));
      final done = rig.called.where((call) => call[1] == 'revoke' && !call.contains('--dry-run')).toList();
      expect(done, hasLength(1));
      expect(done.single, containsAllInOrder(['--key', _new, '--id']));
      expect(done.single, isNot(contains('--base')), reason: 'identity revoke has no such option, and files nothing.');
      expect(find.byKey(const Key('identity-operation')), findsOneWidget);
    });

    testWidgets('stands in my row alone', (tester) async {
      final rig = _Rig();
      final (_, organization) = await _organization(tester, 'olive');
      await _pump(tester, OrganizationPage(organization: organization, keys: rig.keys));
      expect(_action('replaceLostKey'), findsOneWidget);
    });

    // Harm: a person whose key is revoked has no way back, as this is the only thing still open to them.
    testWidgets('stays open to a person whose card is revoked', (tester) async {
      final rig = _Rig();
      final fixture = FixtureOrganization(
        organizationFor(
          'olive',
          persons: const [OrganizationPerson(login: 'olive', standing: CardStanding.revoked, key: _old)],
        ),
      );
      final organization = Organization(fixture);
      addTearDown(organization.dispose);
      await _pump(tester, OrganizationPage(organization: organization, keys: rig.keys));
      expect(_action('replaceLostKey'), findsOneWidget);
      expect(_action('changeCard'), findsNothing);
    });

    // Harm: the backup key signs a card nobody made here, or an old scope reaches Core.
    testWidgets('uses a backup key only once a new card is made, naming that card', (tester) async {
      final rig = _Rig();
      final (_, organization) = await _organization(tester, 'olive');
      await _pump(tester, OrganizationPage(organization: organization, keys: rig.keys));
      await _tap(tester, _action('replaceLostKey'));
      final use = find.byKey(const Key('identity.useBackup organization'));
      expect(tester.widget<TextButton>(use).onPressed, isNull);
      expect(rig.opened, isEmpty);

      await _tap(tester, find.byKey(const Key('identity-key $_new')));
      await _tap(tester, find.byKey(const Key('identity-lost-confirm')));
      await _tap(tester, use);
      final command = rig.opened.single;
      expect(command.take(4).toList(), ['porelo', 'identity', 'backup-key', '--organization']);
      expect(
        command,
        containsAllInOrder(['--use', _file, '--card', '/home/olive/.config/porelo/identity/card', '--base', 'r1']),
      );
      expect(command, isNot(contains('--registry')));
      expect(command, isNot(contains('--project')));
    });
  });
}
