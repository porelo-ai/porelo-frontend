import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/commands.dart';
import 'package:porelo_frontend/src/app/host_give_up.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/ui/host_give_up_view.dart';

const _central = 'https://forge.example/acme/organization.git';

Future<void> _show(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // Harm: a slow forge holds the result back for a minute, with nothing said and a second give-up offered meanwhile.
  group('the central forge for the links', () {
    GiveUpOutcome outcome({String? link}) => giveUpOutcome(
      host: 'orchard',
      started: true,
      code: 65,
      answer: jsonEncode({
        'removed': <Object>[],
        'kept': [
          {'project': 'garden', 'repository': 'garden', 'title': 'orchard', 'why': 'refused', 'link': link},
        ],
      }),
      lastLine: '',
    );

    test('is not read where no kept key has a link', () async {
      var reads = 0;
      final central = await centralForLinks(outcome(), () async {
        reads++;
        return _central;
      });
      expect(central, isNull);
      expect(reads, 0);
    });

    test('is read where a kept key has a link', () async {
      expect(await centralForLinks(outcome(link: 'https://forge.example/x'), () async => _central), _central);
    });

    test('that does not answer within its limit leaves each link as text', () {
      fakeAsync((async) {
        String? central = 'unset';
        var done = false;
        unawaited(
          centralForLinks(outcome(link: 'https://forge.example/x'), () => Completer<String?>().future).then((read) {
            central = read;
            done = true;
          }),
        );
        async.elapse(const Duration(seconds: 9));
        expect(done, isFalse);
        async.elapse(const Duration(seconds: 2));
        expect(done, isTrue);
        expect(central, isNull);
      });
    });
  });

  // Harm: a button takes the person to a look-alike site, or a key left at the forge is not said with where to remove it.
  testWidgets("the result names each key, and offers a button only to the organization's own forge", (tester) async {
    final opened = <Uri>[];
    final outcome = giveUpOutcome(
      host: 'orchard',
      started: true,
      code: 65,
      lastLine: '',
      answer: jsonEncode({
        'removed': [
          {'project': null, 'repository': 'organization', 'title': 't'},
        ],
        'kept': [
          {
            'project': 'garden',
            'repository': 'garden',
            'title': 't',
            'why': 'the forge refused',
            'link': 'https://forge.example/acme/garden/settings/keys',
          },
          {
            'project': 'lemon',
            'repository': 'lemon',
            'title': 't',
            'why': 'the forge refused',
            'link': 'https://forge.example@evil.com/acme/lemon/settings/keys',
          },
          {'project': 'pear', 'repository': 'pear', 'title': 't', 'why': 'not at the central forge', 'link': null},
        ],
      }),
    );
    await _show(tester, GiveUpResult(outcome: outcome, centralForge: _central, openLink: opened.add));
    expect(find.textContaining('Removed: the organization, organization'), findsOneWidget);
    expect(find.textContaining('Kept: project garden, garden: the forge refused'), findsOneWidget);
    expect(find.textContaining('Give-up may be run again'), findsOneWidget);
    final buttons = find.byType(TextButton);
    expect(buttons, findsOneWidget, reason: 'only the link on the central forge is a button');
    expect(find.text('https://forge.example@evil.com/acme/lemon/settings/keys'), findsOneWidget, reason: 'as text');
    expect(find.textContaining('Kept: project pear, pear: not at the central forge'), findsOneWidget);
    await tester.tap(buttons);
    expect(opened, [Uri.parse('https://forge.example/acme/garden/settings/keys')]);
  });

  // Harm: a host is given up by one click, its keys gone from the forge and its identity from the vault for good.
  testWidgets('giving up asks first, with the focus on Cancel', (tester) async {
    bool? answer;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => answer = await confirmGiveUp(context, 'orchard'),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('orchard'), findsWidgets);
    expect(Focus.of(tester.element(find.text('Cancel'))).hasFocus, isTrue);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(answer, isFalse);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Give it up for good'));
    await tester.pumpAndSettle();
    expect(answer, isTrue);
  });

  // Harm: a host already given back cannot be given up, its keys left at the forge for good.
  testWidgets("the Vault page lists each host whose identity it keeps, each with give-up or why not", (tester) async {
    final asked = <String>[];
    await _show(
      tester,
      KeptHostIdentities(
        hosts: const ['lemon', 'orchard'],
        whyNot: (host) => host == 'lemon' ? 'its setup is running' : null,
        onGiveUp: asked.add,
      ),
    );
    expect(find.text('Hosts whose identity your Porelo-Vault keeps'), findsOneWidget);
    expect(find.text('lemon'), findsOneWidget);
    expect(find.text('its setup is running'), findsOneWidget);
    final buttons = find.text('Give this host up for good…');
    expect(buttons, findsNWidgets(2));
    await tester.tap(buttons.first);
    await tester.tap(buttons.last);
    expect(asked, ['orchard']);
  });

  // Harm: a screen reader reads each give-up button twice over, its label and its own text run together.
  testWidgets('each give-up button is read by its label alone', (tester) async {
    final semantics = tester.ensureSemantics();
    await _show(tester, KeptHostIdentities(hosts: const ['orchard'], whyNot: (_) => null, onGiveUp: (_) {}));
    final label = find.bySemanticsLabel('Give orchard up for good');
    expect(label, findsOneWidget);
    expect(tester.getSemantics(label).getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(find.bySemanticsLabel(RegExp('Give this host up for good')), findsNothing, reason: 'not read twice');
    semantics.dispose();
  });

  testWidgets('the Vault page says why it cannot list them', (tester) async {
    await _show(
      tester,
      KeptHostIdentities(hosts: null, problem: 'your Porelo-Vault is shut', whyNot: (_) => null, onGiveUp: (_) {}),
    );
    expect(find.textContaining('your Porelo-Vault is shut'), findsOneWidget);
  });

  // Harm: give-up is not where a server's other lasting actions are, or is offered where it cannot run.
  test("the Server submenu offers giving the host up, in the danger colour, or says why not", () {
    final settings = Settings(MemorySettingsStore());
    addTearDown(settings.dispose);
    const machine = Machine(name: 'orchard', socketPath: '', kind: 'host', host: '203.0.113.7');
    final commands = hostMachineCommands(
      machine: machine,
      settings: settings,
      takeDown: () {},
      giveUp: (_) {},
      whyNotGiveUp: (host) => 'your Porelo-Vault keeps no identity of $host',
    );
    final giveUp = commands.singleWhere((command) => command.id == 'host.giveUp');
    expect(giveUp.label, 'Give this host up for good…');
    expect(giveUp.danger, isTrue);
    expect(giveUp.unavailable, 'your Porelo-Vault keeps no identity of orchard');
  });
}
