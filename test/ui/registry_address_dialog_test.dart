import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/registry_address_dialog.dart';

void main() {
  Future<List<String?>> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final answers = <String?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => answers.add(await chooseRegistryAddress(context)),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    return answers;
  }

  // Guards a pasted token reaching the settings file or the screen.
  testWidgets('an address carrying a token is refused without repeating it', (tester) async {
    final answers = await open(tester);
    const token = 'ghp_0123456789abcdefghijklmnopqrstuvwxyz';

    await tester.enterText(find.byKey(const Key('registry-address')), 'https://$token@github.com/team/registry.git');
    await tester.tap(find.byKey(const Key('registry-address-take')));
    await tester.pump();

    expect(answers, isEmpty, reason: 'nothing is handed on to be kept');
    expect(
      find.textContaining(token).evaluate().where((element) => element.widget is Text),
      isEmpty,
      reason: 'the refusal does not repeat the token',
    );
    expect(find.textContaining('without a user name, password or token'), findsOneWidget);
  });

  // Guards the checked address being lost or changed on its way to the settings.
  testWidgets('a credential-free address is answered as typed', (tester) async {
    final answers = await open(tester);

    await tester.enterText(find.byKey(const Key('registry-address')), ' git@github.com:team/registry.git ');
    await tester.tap(find.byKey(const Key('registry-address-take')));
    await tester.pump();

    expect(answers, ['git@github.com:team/registry.git']);
  });
}
